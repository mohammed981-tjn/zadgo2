// lib/providers/firebase_service.dart
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/models.dart' as models;
import '../utils/helpers.dart' show haversineDistanceKm;
import 'notify_relay.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _restaurants => _db.collection('restaurants');
  CollectionReference<Map<String, dynamic>> get _orders => _db.collection('orders');
  CollectionReference<Map<String, dynamic>> get _drivers => _db.collection('drivers');
  CollectionReference<Map<String, dynamic>> get _complaints => _db.collection('complaints');
  CollectionReference<Map<String, dynamic>> get _messages => _db.collection('chat_messages');
  CollectionReference<Map<String, dynamic>> get _complaintMessages =>
      _db.collection('complaint_messages');
  CollectionReference<Map<String, dynamic>> get _reassignments => _db.collection('reassignments');
  CollectionReference<Map<String, dynamic>> get _broadcasts => _db.collection('broadcasts');
  CollectionReference<Map<String, dynamic>> get _registrationCodes =>
      _db.collection('registrationCodes');
  CollectionReference<Map<String, dynamic>> get _deliverySettings =>
      _db.collection('delivery_settings');
  CollectionReference<Map<String, dynamic>> get _driverTransactions =>
      _db.collection('driver_transactions');
  CollectionReference<Map<String, dynamic>> get _walletTransactions =>
      _db.collection('wallet_transactions');

  bool _isValidStatusTransition(models.OrderStatus from, models.OrderStatus to) {
    if (from == to) return true;
    if (to == models.OrderStatus.cancelled && from.isActive) return true;
    if (from == models.OrderStatus.delivered && to == models.OrderStatus.refunded) {
      return true;
    }

    switch (from) {
      case models.OrderStatus.created:
        return to == models.OrderStatus.restaurantPending;
      case models.OrderStatus.restaurantPending:
        return to == models.OrderStatus.restaurantAccepted ||
            to == models.OrderStatus.restaurantRejected;
      case models.OrderStatus.restaurantAccepted:
        return to == models.OrderStatus.preparing;
      case models.OrderStatus.preparing:
        return to == models.OrderStatus.readyForPickup;
      case models.OrderStatus.readyForPickup:
        return to == models.OrderStatus.searchingDriver ||
            to == models.OrderStatus.onTheWay;
      case models.OrderStatus.searchingDriver:
        return to == models.OrderStatus.driverAssigned ||
            to == models.OrderStatus.noDriverFound;
      case models.OrderStatus.driverAssigned:
        return to == models.OrderStatus.onTheWay;
      case models.OrderStatus.pickedUp:
        return to == models.OrderStatus.onTheWay;
      case models.OrderStatus.onTheWay:
        return to == models.OrderStatus.delivered;
      case models.OrderStatus.noDriverFound:
        // إسناد يدوي من المدير بعد فشل البحث التلقائي، أو إلغاء الطلب. كان
        // الإلغاء ممنوعاً من هذه الحالة (لأن noDriverFound ليست isActive فلا
        // تشملها قاعدة الإلغاء العامة)، فيبقى الطلب عالقاً بلا مخرج — ومعه
        // يبقى رصيد المحفظة المخصوم محجوزاً بلا إعادة.
        return to == models.OrderStatus.driverAssigned ||
            to == models.OrderStatus.cancelled;
      case models.OrderStatus.delivered:
      case models.OrderStatus.restaurantRejected:
      case models.OrderStatus.cancelled:
      case models.OrderStatus.refunded:
        return false;
    }
  }

  CollectionReference<Map<String, dynamic>> _categories(String rId) =>
      _restaurants.doc(rId).collection('categories');
  CollectionReference<Map<String, dynamic>> _items(String rId) =>
      _restaurants.doc(rId).collection('items');

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> register(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  Future<void> createUser(models.AppUser user) => _users.doc(user.uid).set(user.toMap());

  Future<models.AppUser?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return models.AppUser.fromMap(doc.data()!, doc.id);
  }

  Future<void> updateFcmToken(String uid, String token) =>
      _users.doc(uid).update({'fcmToken': token});

  /// يمسح توكن الجهاز عند تسجيل الخروج، فلا يبقى الجهاز عنوان إشعارات
  /// لحساب لم يعد صاحبه عليه.
  Future<void> clearFcmToken(String uid) =>
      _users.doc(uid).update({'fcmToken': FieldValue.delete()});

  Stream<List<models.AppUser>> streamUsers() => _users
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => models.AppUser.fromMap(d.data(), d.id)).toList());

  Future<void> updateUser(models.AppUser user) => _users.doc(user.uid).update(user.toMap());

  /// تعديل الملف الشخصي (الاسم والجوال) — حقلان محددان لا مستند كامل، فلا
  /// خطر على الحقول المحمية. [alsoDriver]: مستند السائق يحمل نسخة من
  /// الاسم والجوال (يقرؤها العميل في التتبّع) فتُحدَّث معه في نفس الدفعة.
  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String phone,
    bool alsoDriver = false,
  }) async {
    final batch = _db.batch();
    batch.update(_users.doc(uid), {
      'name': name.trim(),
      'phone': phone.trim(),
    });
    if (alsoDriver) {
      batch.update(_drivers.doc(uid), {
        'name': name.trim(),
        'phone': phone.trim(),
      });
    }
    await batch.commit();
  }

  Future<void> setUserActive(String uid, bool isActive) =>
      _users.doc(uid).update({'isActive': isActive});

  Future<void> deleteUserDoc(String uid) => _users.doc(uid).delete();

  /// يتابع مستند المستخدم لحظياً — تحتاجه شاشة «حسابي» ليظهر رصيد المحفظة
  /// محدَّثاً فور إضافة استرداد من الإدارة، بدل قيمة قديمة من وقت الدخول.
  Stream<models.AppUser?> streamUser(String uid) => _users.doc(uid).snapshots().map(
      (d) => d.exists && d.data() != null ? models.AppUser.fromMap(d.data()!, d.id) : null);

  /// يحفظ عناوين العميل. الحقل جزء من مستند المستخدم، فيحدّثه صاحبه بنفسه
  /// دون صلاحيات إضافية (قواعد الأمان تمنع تعديل الدور والرصيد فقط).
  Future<void> updateSavedAddresses(String uid, List<models.SavedAddress> addresses) =>
      _users.doc(uid).update({
        'savedAddresses': addresses.map((a) => a.toMap()).toList(),
      });

  /// إضافة رصيد لمحفظة العميل مع حركة توثّق السبب. كانت تزيد الرصيد بلا سجلّ،
  /// فيرى العميل رقماً يتبدّل دون تفسير ولا تستطيع الإدارة تدقيقه.
  Future<void> addWalletCredit(
    String userId,
    double amount, {
    models.WalletTransactionType type = models.WalletTransactionType.refund,
    String? orderId,
    String? orderNumber,
    String? note,
  }) =>
      _recordWalletEntry(
        userId: userId,
        amount: amount.abs(),
        type: type,
        orderId: orderId,
        orderNumber: orderNumber,
        note: note,
      );

  /// خصم من رصيد المحفظة عند استخدامه في دفع طلب. يتحقّق من كفاية الرصيد
  /// داخل معاملة (transaction) لا بقراءة ثم كتابة، فطلبان متزامنان لا
  /// يستطيعان إنفاق الرصيد نفسه مرّتين.
  Future<void> spendFromWallet({
    required String userId,
    required double amount,
    required String orderId,
    required String orderNumber,
  }) async {
    if (amount <= 0) return;
    final userRef = _users.doc(userId);
    final txRef = _walletTransactions.doc();

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(userRef);
      final data = snap.data();
      if (!snap.exists || data == null) {
        throw Exception('حساب العميل غير موجود');
      }
      final current = (data['walletBalance'] as num?)?.toDouble() ?? 0;
      if (current + 0.001 < amount) {
        throw Exception('رصيد المحفظة غير كافٍ');
      }
      transaction.update(userRef, {'walletBalance': current - amount});
      transaction.set(
        txRef,
        models.WalletTransaction(
          id: txRef.id,
          userId: userId,
          type: models.WalletTransactionType.orderPayment,
          amount: -amount,
          balanceAfter: current - amount,
          orderId: orderId,
          orderNumber: orderNumber,
          createdAt: DateTime.now(),
        ).toMap(),
      );
    });
  }

  /// يكتب حركة محفظة ويحدّث الرصيد في دفعة واحدة.
  Future<void> _recordWalletEntry({
    required String userId,
    required double amount,
    required models.WalletTransactionType type,
    String? orderId,
    String? orderNumber,
    String? note,
  }) async {
    if (amount == 0) return;
    final doc = await _users.doc(userId).get();
    final current = (doc.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
    final signed = type == models.WalletTransactionType.orderPayment ? -amount : amount;
    final txRef = _walletTransactions.doc();
    final batch = _db.batch();
    batch.update(_users.doc(userId), {
      'walletBalance': FieldValue.increment(signed),
    });
    batch.set(
      txRef,
      models.WalletTransaction(
        id: txRef.id,
        userId: userId,
        type: type,
        amount: signed,
        balanceAfter: current + signed,
        orderId: orderId,
        orderNumber: orderNumber,
        note: note,
        createdAt: DateTime.now(),
      ).toMap(),
    );
    await batch.commit();
  }

  /// سجلّ حركات محفظة عميل، الأحدث أولاً.
  ///
  /// الترتيب داخل التطبيق لا في الاستعلام عمداً: جمعُ where مع orderBy في
  /// Firestore يستلزم فهرساً مركّباً يُنشأ يدوياً من وحدة التحكم، ونسيانه
  /// يُسقط الشاشة بخطأ failed-precondition (حدث فعلاً). حركات المستخدم
  /// الواحد قليلة، فالترتيب المحلي بلا كلفة ويُسقط الاعتماد على خطوة
  /// نشر خارجية بالكامل.
  Stream<List<models.WalletTransaction>> streamWalletTransactions(String userId) =>
      _walletTransactions
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((s) => s.docs
              .map((d) => models.WalletTransaction.fromMap(d.data(), d.id))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  Future<void> createManagedUser({
    required String name,
    required String email,
    required String password,
    required String phone,
    required models.UserRole role,
    String? restaurantId,
    String? restaurantName,
  }) async {
    FirebaseApp secondaryApp;
    try {
      secondaryApp = Firebase.app('SecondaryZadGoApp');
    } catch (_) {
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryZadGoApp',
        options: Firebase.app().options,
      );
    }
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(), password: password.trim());
    final uid = cred.user!.uid;
    await secondaryAuth.signOut();
    final newUser = models.AppUser(
      uid: uid,
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      role: role,
      createdAt: DateTime.now(),
      restaurantId: restaurantId,
      restaurantName: restaurantName,
    );
    await createUser(newUser);
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  static const String _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _randomCode() {
    final rnd = Random.secure();
    return List.generate(6, (_) => _codeChars[rnd.nextInt(_codeChars.length)]).join();
  }

  Future<models.RegistrationCode> generateRegistrationCode({
    required models.UserRole role,
    String restaurantId = '',
    String restaurantName = '',
    Duration? validity,
  }) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _randomCode();
      final ref = _registrationCodes.doc(code);
      final existing = await ref.get();
      if (existing.exists) continue;
      final entry = models.RegistrationCode(
        code: code,
        role: role,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        createdAt: DateTime.now(),
        expiresAt: validity == null ? null : DateTime.now().add(validity),
      );
      await ref.set(entry.toMap());
      return entry;
    }
    throw Exception('تعذّر توليد كود تسجيل فريد، حاول مرة أخرى');
  }

  Stream<List<models.RegistrationCode>> streamRegistrationCodes(
          String restaurantId) =>
      _registrationCodes
          .where('restaurantId', isEqualTo: restaurantId)
          .snapshots()
          .map((s) => s.docs
              .map((d) => models.RegistrationCode.fromMap(d.data(), d.id))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  /// كل أكواد التسجيل لشاشة إدارتها — الأحدث أولاً.
  Stream<List<models.RegistrationCode>> streamAllRegistrationCodes() =>
      _registrationCodes.limit(200).snapshots().map((s) {
        final list = s.docs
            .map((d) => models.RegistrationCode.fromMap(d.data(), d.id))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  Future<void> revokeRegistrationCode(String code) =>
      _registrationCodes.doc(code.trim().toUpperCase()).delete();

  Future<models.AppUser> registerWithCode({
    required String code,
    required String name,
    required String email,
    required String password,
    required String phone,
    String? nationalId,
    models.UserRole? expectedRole,
  }) async {
    final ref = _registrationCodes.doc(code.trim().toUpperCase());

    final initialSnap = await ref.get();
    if (!initialSnap.exists || initialSnap.data() == null) {
      throw Exception('كود التسجيل غير صحيح');
    }
    final initial = models.RegistrationCode.fromMap(initialSnap.data()!, initialSnap.id);
    if (initial.isUsed) {
      throw Exception('تم استخدام هذا الرمز من قبل، يرجى طلب رمز جديد');
    }
    if (initial.isExpired) {
      throw Exception('انتهت صلاحية هذا الرمز، اطلب رمزاً جديداً من الإدارة');
    }
    if (expectedRole != null && initial.role != expectedRole) {
      throw Exception('هذا الكود غير مخصص لهذا التطبيق');
    }

    final cred = await register(email.trim(), password.trim());
    final uid = cred.user!.uid;

    try {
      final claimed = await _db.runTransaction<models.RegistrationCode>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists || snap.data() == null) {
          throw Exception('كود التسجيل غير صحيح');
        }
        final current = models.RegistrationCode.fromMap(snap.data()!, snap.id);
        if (current.isUsed) {
          throw Exception('تم استخدام هذا الرمز من قبل، يرجى طلب رمز جديد');
        }
        if (current.isExpired) {
          throw Exception('انتهت صلاحية هذا الرمز، اطلب رمزاً جديداً من الإدارة');
        }
        if (expectedRole != null && current.role != expectedRole) {
          throw Exception('هذا الكود غير مخصص لهذا التطبيق');
        }
        tx.update(ref, {'isUsed': true, 'usedAt': FieldValue.serverTimestamp()});
        return current;
      });

      final newUser = models.AppUser(
        uid: uid,
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
        role: claimed.role,
        createdAt: DateTime.now(),
        restaurantId: claimed.role == models.UserRole.restaurantManager ? claimed.restaurantId : null,
        restaurantName: claimed.role == models.UserRole.restaurantManager ? claimed.restaurantName : null,
        nationalId: nationalId?.trim().isEmpty ?? true ? null : nationalId!.trim(),
      );
      await createUser(newUser);
      if (claimed.role == models.UserRole.driver) {
        await addDriver(models.Driver(
            id: uid, name: name.trim(), phone: phone.trim(), vehicleType: 'دراجة نارية'));
      }
      await ref.update({'usedByUid': uid, 'usedByName': name.trim()});
      return newUser;
    } catch (e) {
      try {
        await cred.user?.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Stream<List<models.Restaurant>> streamRestaurants() =>
      _restaurants.orderBy('name').snapshots().map(
          (s) => s.docs.map((d) => models.Restaurant.fromMap(d.data(), d.id)).toList());

  Future<void> addRestaurant(models.Restaurant r) => _restaurants.doc(r.id).set(r.toMap());
  Future<void> updateRestaurant(models.Restaurant r) => _restaurants.doc(r.id).update(r.toMap());
  Future<void> toggleRestaurant(String id, bool isOpen) =>
      _restaurants.doc(id).update({'isOpen': isOpen});

  Future<models.Restaurant?> getRestaurantOnce(String id) async {
    final doc = await _restaurants.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return models.Restaurant.fromMap(doc.data()!, doc.id);
  }

  Stream<List<models.MenuCategory>> streamCategories(String rId) => _categories(rId)
      .snapshots()
      .map((s) {
        final list =
            s.docs.map((d) => models.MenuCategory.fromMap(d.data(), d.id)).toList();
        list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return list;
      });

  Future<void> addCategory(models.MenuCategory cat) =>
      _categories(cat.restaurantId).doc(cat.id).set(cat.toMap());

  /// جلب أصناف مطعم مرة واحدة — لإعادة الطلب: تُطابَق أصناف الطلب القديم مع
  /// القائمة الحالية (أسعارها وتوفرها اليوم، لا كما كانت وقت الطلب).
  Future<List<models.MenuItem>> getMenuItemsOnce(String rId) async {
    final snap = await _items(rId).get();
    return snap.docs
        .map((d) => models.MenuItem.fromMap(d.data(), d.id))
        .toList();
  }

  Stream<List<models.MenuItem>> streamMenuItems(String rId) => _items(rId)
      .snapshots()
      .map((s) => s.docs.map((d) => models.MenuItem.fromMap(d.data(), d.id)).toList());

  Future<void> addMenuItem(models.MenuItem item) =>
      _items(item.restaurantId).doc(item.id).set(item.toMap());

  /// استيراد منيو كامل دفعة واحدة (تصنيفات وأصنافها) — بديل عن إدخال عشرات
  /// الأصناف يدوياً نموذجاً نموذجاً.
  ///
  /// يُكتب كل شيء في دفعة واحدة (batch) لا كتابات متفرّقة: إمّا أن ينجح
  /// المنيو كاملاً أو لا يُكتب منه شيء، فلا يبقى المطعم بمنيو نصفه مفقود لو
  /// انقطعت الشبكة في المنتصف.
  ///
  /// حدّ Firestore للدفعة الواحدة 500 عملية، لذا تُقسَّم تلقائياً عند تجاوزه.
  Future<void> importMenu({
    required String restaurantId,
    required List<models.MenuCategory> categories,
    required List<models.MenuItem> items,
    bool replaceExisting = false,
  }) async {
    const maxOps = 450; // هامش أمان تحت حدّ 500
    final ops = <void Function(WriteBatch)>[];

    // وضع الاستبدال: يُحذف المنيو القائم (تصنيفاته وأصنافه) قبل كتابة
    // الجديد — لإعادة استيراد منيو استُورد سابقاً (من لوحة الويب مثلاً)
    // دون تكرار الأصناف. الحذف يتقدّم الكتابة في نفس تسلسل الدفعات.
    if (replaceExisting) {
      final oldCats = await _categories(restaurantId).get();
      final oldItems = await _items(restaurantId).get();
      for (final d in oldCats.docs) {
        ops.add((b) => b.delete(d.reference));
      }
      for (final d in oldItems.docs) {
        ops.add((b) => b.delete(d.reference));
      }
    }

    for (final c in categories) {
      ops.add((b) => b.set(_categories(restaurantId).doc(c.id), c.toMap()));
    }
    for (final i in items) {
      ops.add((b) => b.set(_items(restaurantId).doc(i.id), i.toMap()));
    }

    for (var start = 0; start < ops.length; start += maxOps) {
      final end = (start + maxOps).clamp(0, ops.length);
      final batch = _db.batch();
      for (var k = start; k < end; k++) {
        ops[k](batch);
      }
      await batch.commit();
    }
  }
  Future<void> updateMenuItem(models.MenuItem item) =>
      _items(item.restaurantId).doc(item.id).update(item.toMap());
  Future<void> toggleItemAvailability(String rId, String itemId, bool isAvailable) =>
      _items(rId).doc(itemId).update({'isAvailable': isAvailable});
  Future<void> deleteMenuItem(String rId, String itemId) =>
      _items(rId).doc(itemId).delete();

  Stream<List<models.Driver>> streamDrivers() => _drivers
      .snapshots()
      .map((s) => s.docs.map((d) => models.Driver.fromMap(d.data(), d.id)).toList());

  Stream<models.Driver?> streamDriver(String driverId) => _drivers.doc(driverId).snapshots().map(
      (doc) => doc.exists && doc.data() != null ? models.Driver.fromMap(doc.data()!, doc.id) : null);

  Future<void> addDriver(models.Driver d) => _drivers.doc(d.id).set(d.toMap());
  Future<void> updateDriver(models.Driver d) => _drivers.doc(d.id).update(d.toMap());
  Future<void> setDriverOnline(String id, bool isOnline) =>
      _drivers.doc(id).update({'isOnline': isOnline});

  Future<void> updateDriverLocation(String driverId, double lat, double lng) =>
      _drivers.doc(driverId).update({
        'lat': lat,
        'lng': lng,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });

  // أُزيلت markPayoutDone: كانت تصفّر pendingPayout وفق النموذج القديم الذي
  // يفترض أن التطبيق هو المدين دائماً، وهو افتراض مقلوب للطلبات النقدية.
  // بديلها [recordDriverPayout] الذي يقيّد الصرف في دفتر الحساب مع حركة
  // موثّقة. لم تكن مستدعاة من أي شاشة، فإزالتها لا تكسر شيئاً وتمنع استخدامها
  // بالخطأ فتفسد الرصيد الجديد.

  Future<void> updateDriverRating(String driverId, double newRating) async {
    final doc = await _drivers.doc(driverId).get();
    if (!doc.exists || doc.data() == null) return;
    final driver = models.Driver.fromMap(doc.data()!, doc.id);
    final newCount = driver.ratingCount + 1;
    final newAvg = ((driver.rating * driver.ratingCount) + newRating) / newCount;
    await _drivers.doc(driverId).update({
      'rating': double.parse(newAvg.toStringAsFixed(1)),
      'ratingCount': newCount,
    });
  }

  Future<String> placeOrder(models.Order order) async {
    await _orders.doc(order.id).set({
      ...order.toMap(),
      if (order.statusChangedAt == null) 'statusChangedAt': FieldValue.serverTimestamp(),
    });
    // تقييد استخدام الكوبون بعد ثبوت الطلب لا قبله — فلا يُستهلك كودٌ على
    // طلب لم يُنشأ. وفشل التقييد لا يُسقط الطلب: الخصم محفوظ داخله أصلاً.
    final code = order.couponCode;
    if (code != null && code.isNotEmpty && order.discountAmount > 0) {
      try {
        await _recordCouponUse(
            code: code, userId: order.customerId, orderId: order.id);
      } catch (e) {
        debugPrint('⚠️ تعذّر تقييد استخدام الكوبون $code: $e');
      }
    }
    // إشعار فوري لمديري المطعم بالطلب الجديد عبر الخادم المرافق — بدونه لا
    // يعلم المطعم بالطلب إلا حين يكون تطبيقه مفتوحاً على الشاشة.
    NotifyRelay.orderEvent(order.id, OrderEvent.created);
    return order.id;
  }

  // ---------------------------------------------------------------------
  // حدود التدفقات: كانت كل تدفقات الطلبات بلا limit، أي أن فتح أي شاشة
  // يُنزّل تاريخ الطلبات كاملاً منذ إنشاء المنصة ويعيد تنزيله مع كل تعديل —
  // كلفة قراءات تنمو خطياً مع العمر، وذاكرة قد تُسقط التطبيق. الحدود أدناه
  // تغطي كل استخدام واقعي للشاشات؛ التقارير التاريخية الكاملة مكانها تصدير
  // مخصص لاحقاً لا تدفقاً حياً.
  // ---------------------------------------------------------------------

  Stream<List<models.Order>> streamAllOrders() => _orders
      .orderBy('createdAt', descending: true)
      .limit(500)
      .snapshots()
      .map((s) => s.docs.map((d) => models.Order.fromMap(d.data(), d.id)).toList());

  Stream<List<models.Order>> streamActiveOrders() => _orders
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs
          .map((d) => models.Order.fromMap(d.data(), d.id))
          .where((o) => o.status.isActive || o.status == models.OrderStatus.noDriverFound)
          .toList());

  Stream<List<models.Order>> streamRestaurantOrders(String restaurantId) => _orders
      .where('restaurantId', isEqualTo: restaurantId)
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map((d) => models.Order.fromMap(d.data(), d.id)).toList());

  Stream<List<models.Order>> streamCustomerOrders(String customerId) => _orders
      .where('customerId', isEqualTo: customerId)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => models.Order.fromMap(d.data(), d.id)).toList());

  Stream<List<models.Order>> streamDriverOrders(String driverId) => _orders
      .where('driverId', isEqualTo: driverId)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => models.Order.fromMap(d.data(), d.id)).toList());

  Stream<models.Order?> streamOrder(String orderId) => _orders.doc(orderId).snapshots().map(
      (doc) => doc.exists && doc.data() != null ? models.Order.fromMap(doc.data()!, doc.id) : null);

  Future<void> updateOrderStatus(String orderId, models.OrderStatus status) async {
    final ref = _orders.doc(orderId);
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) {
      await ref.set({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusChangedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    final current = models.Order.fromMap(doc.data()!, doc.id);
    if (!_isValidStatusTransition(current.status, status)) {
      throw Exception('انتقال حالة غير صالح: من ${current.status.name} إلى ${status.name}');
    }

    await ref.update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'statusChangedAt': FieldValue.serverTimestamp(),
    });
    // إشعار العميل بتغيّر حالة طلبه. الخادم هو من يقرّر أي الحالات تستحق
    // إشعاراً فعلاً (فلا يُزعج العميل بكل انتقال داخلي).
    NotifyRelay.orderEvent(orderId, OrderEvent.status);
  }

  Future<void> rejectOrderByRestaurant(String orderId, String reason) async {
    final ref = _orders.doc(orderId);
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('الطلب غير موجود');
    }

    final current = models.Order.fromMap(doc.data()!, doc.id);
    if (current.status != models.OrderStatus.restaurantPending) {
      throw Exception('لا يمكن رفض الطلب بعد قبوله — حالته الحالية: ${current.status.label}');
    }

    await ref.update({
      'status': models.OrderStatus.restaurantRejected.name,
      'rejectionReason': reason.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'statusChangedAt': FieldValue.serverTimestamp(),
    });

    // رفض المطعم إنهاءٌ للطلب بلا خدمة، فيُعاد للعميل ما خُصم من محفظته تماماً
    // كالإلغاء — وإلا خسر رصيده بسبب رفضٍ لا ذنب له فيه.
    await _refundWalletOnCancel(current);
    NotifyRelay.orderEvent(orderId, OrderEvent.status);
  }

  /// تأكيد استلام السائق للطلب من المطعم — لحظة انتقال العُهدة.
  ///
  /// للطلبات النقدية تُقيَّد قيمة الطلب (الوجبات + الرسم الثابت) على محفظة
  /// السائق **هنا** لا عند التسليم: البضاعة صارت بيده وذمّته مشغولة بقيمتها
  /// حتى يحصّلها من العميل — وهو النموذج المعمول به في تطبيقات التوصيل
  /// السعودية (كيتا/مرسول). القيد وتغيير الحالة في دفعة واحدة، فلا استلام
  /// بلا قيد ولا قيد بلا استلام.
  Future<void> markPickedUpBySelf(String orderId) async {
    final ref = _orders.doc(orderId);
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('الطلب غير موجود');
    }

    final current = models.Order.fromMap(doc.data()!, doc.id);
    if (current.status != models.OrderStatus.readyForPickup &&
        current.status != models.OrderStatus.searchingDriver &&
        current.status != models.OrderStatus.driverAssigned &&
        current.status != models.OrderStatus.pickedUp) {
      throw Exception('لا يمكن تأكيد الاستلام من حالة ${current.status.label}');
    }

    final driverId = current.driverId ?? '';
    final needsCustody = current.paymentMethod == models.PaymentMethod.cash &&
        !current.custodyDebited &&
        driverId.isNotEmpty;

    final batch = _db.batch();
    batch.update(ref, {
      'status': models.OrderStatus.onTheWay.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'statusChangedAt': FieldValue.serverTimestamp(),
      if (needsCustody) 'custodyDebited': true,
    });

    // عُهدة صفرية (محفظة العميل غطّت حصّتَي المطعم والمنصّة بالضبط) لا
    // تستحق قيداً — يبقى custodyDebited=true فلا يُعاد القيد عند التسليم.
    if (needsCustody && current.custodyAmount != 0) {
      final custody = current.custodyAmount;
      final driverDoc = await _drivers.doc(driverId).get();
      final balance = driverDoc.exists && driverDoc.data() != null
          ? models.Driver.fromMap(driverDoc.data()!, driverDoc.id).balance
          : 0.0;
      final txRef = _driverTransactions.doc();
      batch.update(_drivers.doc(driverId), {
        'balance': FieldValue.increment(-custody),
      });
      batch.set(
        txRef,
        models.DriverTransaction(
          id: txRef.id,
          driverId: driverId,
          type: models.DriverTransactionType.orderCustody,
          amount: -custody,
          balanceAfter: balance - custody,
          orderId: orderId,
          orderNumber: current.orderNumber,
          performedBy: _auth.currentUser?.uid ?? driverId,
          createdAt: DateTime.now(),
        ).toMap(),
      );
    }

    await batch.commit();
    NotifyRelay.orderEvent(orderId, OrderEvent.status);
  }

  CollectionReference<Map<String, dynamic>> get _orderProofs =>
      _db.collection('order_proofs');

  CollectionReference<Map<String, dynamic>> get _banners =>
      _db.collection('banners');

  /// البنرات الفعّالة لشاشة العميل — الترتيب محلياً (sortOrder ثم الأحدث)
  /// فلا حاجة لفهرس مركّب.
  Stream<List<models.PromoBanner>> streamActiveBanners() => _banners
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => models.PromoBanner.fromMap(d.data(), d.id))
          .toList()
        ..sort((a, b) {
          final c = a.sortOrder.compareTo(b.sortOrder);
          return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
        }));

  /// كل البنرات لإدارة المدير.
  Stream<List<models.PromoBanner>> streamAllBanners() =>
      _banners.snapshots().map((s) => s.docs
          .map((d) => models.PromoBanner.fromMap(d.data(), d.id))
          .toList()
        ..sort((a, b) {
          final c = a.sortOrder.compareTo(b.sortOrder);
          return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
        }));

  Future<void> saveBanner(models.PromoBanner banner) =>
      _banners.doc(banner.id).set(banner.toMap());

  Future<void> setBannerActive(String id, bool active) =>
      _banners.doc(id).update({'isActive': active});

  Future<void> deleteBanner(String id) => _banners.doc(id).delete();

  /// تسجيل وصول السائق إلى المطعم: طابع زمني على الطلب (يقرؤه الجميع في
  /// نزاع «من أخّر؟») + الإحداثيات في وثيقة الإثبات.
  Future<void> recordArrivalAtRestaurant({
    required models.Order order,
    required double lat,
    required double lng,
  }) async {
    final driverId = order.driverId ?? '';
    if (driverId.isEmpty) return;
    final batch = _db.batch();
    batch.update(_orders.doc(order.id), {
      'arrivedAtRestaurantAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _orderProofs.doc(order.id),
      {
        'driverId': driverId,
        'orderNumber': order.orderNumber,
        'arrivedAt': FieldValue.serverTimestamp(),
        'arrivedLat': lat,
        'arrivedLng': lng,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// حفظ إثبات الاستلام من المطعم — يُكتب **قبل** تغيير الحالة وقيد
  /// العُهدة. الصورة اختيارية (سياسة المرونة)؛ الزمن والإحداثيات يُسجَّلان
  /// دائماً فهما بيّنة قائمة بذاتها.
  Future<void> savePickupProof({
    required models.Order order,
    Uint8List? photo,
    required double lat,
    required double lng,
  }) =>
      _orderProofs.doc(order.id).set({
        'driverId': order.driverId ?? '',
        'orderNumber': order.orderNumber,
        if (photo != null) 'pickupPhoto': Blob(photo),
        'pickupAt': FieldValue.serverTimestamp(),
        'pickupLat': lat,
        'pickupLng': lng,
      }, SetOptions(merge: true));

  /// حفظ إثبات التسليم عند العميل — قبل تأكيد التوصيل. الصورة اختيارية
  /// (سياسة المرونة)، و[distanceMeters] بُعد السائق عن موقع العميل المسجّل
  /// لحظة التسليم — يُسجَّل خاصةً حين يكون كبيراً، فهو البيّنة في نزاع
  /// «سلّم في مكان آخر».
  Future<void> saveDeliveryProof({
    required models.Order order,
    Uint8List? photo,
    required double lat,
    required double lng,
    double? distanceMeters,
  }) =>
      _orderProofs.doc(order.id).set({
        'driverId': order.driverId ?? '',
        'orderNumber': order.orderNumber,
        if (photo != null) 'deliveryPhoto': Blob(photo),
        'deliveryAt': FieldValue.serverTimestamp(),
        'deliveryLat': lat,
        'deliveryLng': lng,
        if (distanceMeters != null)
          'deliveryDistanceMeters': distanceMeters.round(),
      }, SetOptions(merge: true));

  /// وثيقة إثبات طلب — تعرضها شاشة الشكوى عند المدير خطاً زمنياً.
  Stream<models.OrderProof?> streamOrderProof(String orderId) =>
      _orderProofs.doc(orderId).snapshots().map((d) =>
          d.exists && d.data() != null
              ? models.OrderProof.fromMap(d.data()!, d.id)
              : null);

  /// عكس عُهدة طلب أُلغي بعد استلام السائق له — بدون هذا يبقى القيد على
  /// السائق لطلب لن يحصّل قيمته من أحد.
  Future<void> _reverseCustodyIfNeeded(models.Order order) async {
    final driverId = order.driverId ?? '';
    if (!order.custodyDebited || driverId.isEmpty || order.custodyAmount == 0) {
      return;
    }
    final driverDoc = await _drivers.doc(driverId).get();
    if (!driverDoc.exists || driverDoc.data() == null) return;
    final balance = models.Driver.fromMap(driverDoc.data()!, driverDoc.id).balance;
    final custody = order.custodyAmount;
    final txRef = _driverTransactions.doc();
    final batch = _db.batch();
    batch.update(_drivers.doc(driverId), {
      'balance': FieldValue.increment(custody),
    });
    batch.set(
      txRef,
      models.DriverTransaction(
        id: txRef.id,
        driverId: driverId,
        type: models.DriverTransactionType.custodyReversal,
        amount: custody,
        balanceAfter: balance + custody,
        orderId: order.id,
        orderNumber: order.orderNumber,
        note: 'إلغاء الطلب بعد الاستلام',
        performedBy: _auth.currentUser?.uid ?? '',
        createdAt: DateTime.now(),
      ).toMap(),
    );
    await batch.commit();
  }

  Future<void> assignDriver(String orderId, String driverId, String driverName) async {
    final ref = _orders.doc(orderId);
    final orderDoc = await ref.get();
    if (orderDoc.exists && orderDoc.data() != null) {
      final current = models.Order.fromMap(orderDoc.data()!, orderDoc.id);
      if (current.status == models.OrderStatus.readyForPickup) {
        await updateOrderStatus(orderId, models.OrderStatus.searchingDriver);
      }
    }

    final refreshedDoc = await ref.get();
    if (refreshedDoc.exists && refreshedDoc.data() != null) {
      final current = models.Order.fromMap(refreshedDoc.data()!, refreshedDoc.id);
      if (!_isValidStatusTransition(current.status, models.OrderStatus.driverAssigned)) {
        throw Exception(
            'انتقال حالة غير صالح: من ${current.status.name} إلى ${models.OrderStatus.driverAssigned.name}');
      }
    }

    final driverDoc = await _drivers.doc(driverId).get();
    final driverData = driverDoc.exists && driverDoc.data() != null
        ? models.Driver.fromMap(driverDoc.data()!, driverDoc.id)
        : null;
    final isDriverOnline = driverData?.isOnline ?? false;

    final batch = _db.batch();
    batch.update(ref, {
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverData?.phone,
      'status': models.OrderStatus.driverAssigned.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'statusChangedAt': FieldValue.serverTimestamp(),
      'driverAcknowledged': isDriverOnline,
    });
    batch.update(_drivers.doc(driverId), {'isAvailable': false});
    await batch.commit();
    // إشعار السائق بالإسناد — قد يكون تطبيقه مغلقاً لحظتها.
    NotifyRelay.orderEvent(orderId, OrderEvent.assigned);
  }

  static const int _driverCandidatesCount = 3;

  /// [excludeDriverId]: سائق يُستبعد من الترشيح — يُمرَّر عند إعادة الإسناد
  /// بعد رفضه للطلب، وإلا اختير «الأقرب» وهو الرافض نفسه فعاد إليه الطلب
  /// فوراً وبعلم إقرار مسبق فلا يظهر له شيء أصلاً.
  Future<bool> autoAssignNearestDriver(models.Order order,
      {String? excludeDriverId}) async {
    if (order.restaurantLat == null || order.restaurantLng == null) return false;
    final driversSnap = await _drivers.get();

    final candidateDrivers = <models.Driver>[];
    final candidateDistances = <double>[];
    for (final doc in driversSnap.docs) {
      final d = models.Driver.fromMap(doc.data(), doc.id);
      if (d.id == excludeDriverId) continue;
      if (!d.isOnline || !d.isAvailable) continue;
      if (d.lat == null || d.lng == null) continue;
      final distance =
          haversineDistanceKm(order.restaurantLat!, order.restaurantLng!, d.lat!, d.lng!);
      candidateDrivers.add(d);
      candidateDistances.add(distance);
    }
    if (candidateDrivers.isEmpty) return false;

    final indices = List<int>.generate(candidateDrivers.length, (i) => i);
    indices.sort((a, b) => candidateDistances[a].compareTo(candidateDistances[b]));

    final nearestIndices = indices.take(_driverCandidatesCount).toList();

    nearestIndices.sort(
        (a, b) => candidateDrivers[b].rating.compareTo(candidateDrivers[a].rating));
    final chosen = candidateDrivers[nearestIndices.first];

    final batch = _db.batch();
    batch.update(_orders.doc(order.id), {
      'driverId': chosen.id,
      'driverName': chosen.name,
      'driverPhone': chosen.phone,
      'updatedAt': FieldValue.serverTimestamp(),
      // عرض حقيقي لا إسناد صامت: كان يُكتب true هنا فيتجاوز المسارُ الأكثر
      // شيوعاً (الإسناد التلقائي) موافقةَ السائق كلياً — لا قبول ولا رفض ولا
      // حتى علمٌ مؤكَّد. الآن يظهر له عرض بالأجرة والمسافتين وعدّاد، وانقضاء
      // المهلة أو الرفض يمرّران الطلب لغيره.
      'driverAcknowledged': false,
    });
    batch.update(_drivers.doc(chosen.id), {'isAvailable': false});
    await batch.commit();
    // إشعار السائق المرشَّح — تطبيقه قد يكون بالخلفية لحظة العرض.
    NotifyRelay.orderEvent(order.id, OrderEvent.assigned);
    return true;
  }

  Future<bool> tryAutoAssignOnAcceptance(models.Order order) => autoAssignNearestDriver(order);

  Future<bool> retryAutoAssignIfNeeded(models.Order order) async {
    if (order.driverId != null && order.driverId!.isNotEmpty) return true;
    return autoAssignNearestDriver(order);
  }

  Future<void> acceptAssignedOrder(String orderId) async {
    final ref = _orders.doc(orderId);
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('الطلب غير موجود');
    }
    final current = models.Order.fromMap(doc.data()!, doc.id);
    if (!current.needsDriverAcknowledgement) {
      return;
    }
    final batch = _db.batch();
    batch.update(ref, {
      'driverAcknowledged': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // معدل القبول يُحسب من المستند لا من ذاكرة الجلسة — عدّاد الجلسة كان
    // يُصفَّر مع كل إعادة تشغيل فلا يتراكم معدل حقيقي.
    if (current.driverId != null && current.driverId!.isNotEmpty) {
      batch.update(_drivers.doc(current.driverId!), {
        'offersTotal': FieldValue.increment(1),
        'offersAccepted': FieldValue.increment(1),
      });
    }
    await batch.commit();
  }

  Future<void> rejectAssignedOrder(String orderId) async {
    final ref = _orders.doc(orderId);
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('الطلب غير موجود');
    }
    final current = models.Order.fromMap(doc.data()!, doc.id);
    if (!current.needsDriverAcknowledgement) {
      throw Exception('لا يمكن رفض هذا الطلب في حالته الحالية');
    }

    final batch = _db.batch();
    batch.update(ref, {
      'driverId': null,
      'driverName': null,
      'driverPhone': null,
      'driverAcknowledged': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (current.driverId != null && current.driverId!.isNotEmpty) {
      batch.update(_drivers.doc(current.driverId!), {
        'isAvailable': true,
        // الرفض (أو انقضاء مهلة العرض) عرضٌ وصل ولم يُقبل — يدخل المقام
        // دون البسط في معدل القبول.
        'offersTotal': FieldValue.increment(1),
      });
    }
    await batch.commit();

    final refreshedDoc = await ref.get();
    if (refreshedDoc.exists && refreshedDoc.data() != null) {
      final refreshedOrder = models.Order.fromMap(refreshedDoc.data()!, refreshedDoc.id);
      await autoAssignNearestDriver(refreshedOrder,
          excludeDriverId: current.driverId);
    }
  }

  Future<void> reassignDriver({
    required models.Order order,
    required String newDriverId,
    required String newDriverName,
    required String reason,
    required String performedBy,
  }) async {
    final newDriverDoc = await _drivers.doc(newDriverId).get();
    final newDriverPhone = newDriverDoc.exists && newDriverDoc.data() != null
        ? models.Driver.fromMap(newDriverDoc.data()!, newDriverDoc.id).phone
        : null;

    final batch = _db.batch();
    batch.update(_orders.doc(order.id), {
      'driverId': newDriverId,
      'driverName': newDriverName,
      'driverPhone': newDriverPhone,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_drivers.doc(newDriverId), {'isAvailable': false});
    if (order.driverId != null && order.driverId!.isNotEmpty) {
      batch.update(_drivers.doc(order.driverId!), {'isAvailable': true});
    }
    final logRef = _reassignments.doc();
    batch.set(
      logRef,
      models.DriverReassignment(
        id: logRef.id,
        orderId: order.id,
        orderNumber: order.orderNumber,
        oldDriverId: order.driverId,
        oldDriverName: order.driverName,
        newDriverId: newDriverId,
        newDriverName: newDriverName,
        reason: reason,
        performedBy: performedBy,
        createdAt: DateTime.now(),
      ).toMap(),
    );
    await batch.commit();

    // إعادة إسناد طلبٍ استُلم فعلاً (عُهدته مقيّدة على السائق القديم):
    // تُردّ العُهدة للقديم وتُقيَّد على الجديد — البضاعة انتقلت من يدٍ ليد،
    // والدفتران يجب أن يعكسا ذلك وإلا حُوسب سائق على طلب ليس بيده.
    if (order.custodyDebited && order.custodyAmount != 0) {
      await _reverseCustodyIfNeeded(order);
      final custody = order.custodyAmount;
      final newDoc = await _drivers.doc(newDriverId).get();
      final newBalance = newDoc.exists && newDoc.data() != null
          ? models.Driver.fromMap(newDoc.data()!, newDoc.id).balance
          : 0.0;
      final custodyTx = _driverTransactions.doc();
      final custodyBatch = _db.batch();
      custodyBatch.update(_drivers.doc(newDriverId), {
        'balance': FieldValue.increment(-custody),
      });
      custodyBatch.set(
        custodyTx,
        models.DriverTransaction(
          id: custodyTx.id,
          driverId: newDriverId,
          type: models.DriverTransactionType.orderCustody,
          amount: -custody,
          balanceAfter: newBalance - custody,
          orderId: order.id,
          orderNumber: order.orderNumber,
          note: 'إعادة إسناد بعد الاستلام',
          performedBy: performedBy,
          createdAt: DateTime.now(),
        ).toMap(),
      );
      await custodyBatch.commit();
    }

    NotifyRelay.orderEvent(order.id, OrderEvent.assigned);
  }

  Stream<List<models.DriverReassignment>> streamReassignments() => _reassignments
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => models.DriverReassignment.fromMap(d.data(), d.id)).toList());

  /// نفس مسار [markPickedUpBySelf] تماماً — تُبقى الدالتان لأن كلاً من شاشة
  /// السائق وشاشة الخريطة تستدعي باسم مختلف تاريخياً، والمنطق (قيد العُهدة
  /// مع تغيير الحالة) يجب أن يكون واحداً مهما كان المدخل.
  Future<void> markOrderPickedUp(String orderId) => markPickedUpBySelf(orderId);

  Future<void> markOrderDelivered(String orderId, String driverId) async {
    final orderDoc = await _orders.doc(orderId).get();
    if (!orderDoc.exists || orderDoc.data() == null) {
      throw Exception('الطلب غير موجود');
    }
    final order = models.Order.fromMap(orderDoc.data()!, orderDoc.id);
    if (!_isValidStatusTransition(order.status, models.OrderStatus.delivered)) {
      throw Exception(
          'انتقال حالة غير صالح: من ${order.status.name} إلى ${models.OrderStatus.delivered.name}');
    }
    final commission = order.calculatedCommission;
    final driverPayout = order.driverShare;
    final paymentMethod = order.paymentMethod;
    final orderNumber = order.orderNumber;
    // أثر التوصيل على رصيد السائق يعتمد على طريقة الدفع:
    //
    // • نقدي: قيمة الطلب قُيّدت عُهدةً لحظة الاستلام من المطعم
    //   (markPickedUpBySelf)، فلا قيد إضافياً هنا — القيد المزدوج كان
    //   سيُحمّل السائق الطلب مرّتين. الاستثناء: طلب استُلم بنسخة قديمة
    //   لا تعرف قيد العُهدة (custodyDebited=false)، فيُقيَّد هنا كالسابق
    //   حتى لا يضيع القيد كلياً أثناء الانتقال بين النسختين.
    // • إلكتروني: التطبيق هو من قبض المبلغ، فتُقيَّد أجرة السائق لصالحه.
    final isCash = paymentMethod == models.PaymentMethod.cash;
    final delta = isCash
        // المسار القديم (استلام بنسخة لا تعرف العُهدة): نفس معادلة العُهدة
        // بخصم المدفوع من المحفظة — لا -(itemsTotal+appShare) الخام.
        ? (order.custodyDebited ? 0.0 : -order.custodyAmount)
        : driverPayout;

    final driverDoc = await _drivers.doc(driverId).get();
    final currentBalance = driverDoc.exists && driverDoc.data() != null
        ? models.Driver.fromMap(driverDoc.data()!, driverDoc.id).balance
        : 0.0;

    final txRef = _driverTransactions.doc();
    final batch = _db.batch();
    batch.update(_orders.doc(orderId), {
      'status': models.OrderStatus.delivered.name,
      'isPaid': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'statusChangedAt': FieldValue.serverTimestamp(),
      'platformCommission': commission,
    });
    batch.update(_drivers.doc(driverId), {
      'totalDeliveries': FieldValue.increment(1),
      if (delta != 0) 'balance': FieldValue.increment(delta),
      'isAvailable': true,
    });
    // الحركة تُكتب في نفس الدفعة، فلا يتغيّر رصيد دون سجلّ يفسّره.
    // وحين لا تغيير على الرصيد (نقدي قُيّدت عُهدته عند الاستلام) لا تُكتب
    // حركة صفرية تُلوّث السجلّ.
    if (delta != 0) {
      batch.set(
        txRef,
        models.DriverTransaction(
          id: txRef.id,
          driverId: driverId,
          type: isCash
              ? models.DriverTransactionType.deliveryCash
              : models.DriverTransactionType.deliveryOnline,
          amount: delta,
          balanceAfter: currentBalance + delta,
          orderId: orderId,
          orderNumber: orderNumber,
          performedBy: _auth.currentUser?.uid ?? driverId,
          createdAt: DateTime.now(),
        ).toMap(),
      );
    }
    await batch.commit();
    // التسليم يغيّر الحالة داخل الدفعة لا عبر updateOrderStatus، فيُبلَّغ
    // الخادم هنا صراحةً ليصل العميلَ إشعارُ «تم التوصيل».
    NotifyRelay.orderEvent(orderId, OrderEvent.status);
  }

  /// تسجيل إيداع نقدي: السائق سلّم مبلغاً للإدارة، فيرتفع رصيده بقدره.
  Future<void> recordDriverDeposit({
    required String driverId,
    required double amount,
    String? note,
  }) =>
      _recordDriverLedgerEntry(
        driverId: driverId,
        amount: amount.abs(),
        type: models.DriverTransactionType.deposit,
        note: note,
      );

  /// تسجيل صرف مستحقّات: الإدارة دفعت للسائق، فينخفض رصيده بقدره.
  Future<void> recordDriverPayout({
    required String driverId,
    required double amount,
    String? note,
  }) =>
      _recordDriverLedgerEntry(
        driverId: driverId,
        amount: -amount.abs(),
        type: models.DriverTransactionType.payout,
        note: note,
      );

  /// مكافأة من الإدارة: تحدٍّ، إحالة سائق جديد، تميّز — تزيد رصيده وتُصرف
  /// له لاحقاً مع مستحقّاته.
  Future<void> recordDriverBonus({
    required String driverId,
    required double amount,
    String? note,
  }) =>
      _recordDriverLedgerEntry(
        driverId: driverId,
        amount: amount.abs(),
        type: models.DriverTransactionType.bonus,
        note: note,
      );

  /// تسوية يدوية بإشارة موجبة أو سالبة (تصحيح خطأ، خصم).
  Future<void> recordDriverAdjustment({
    required String driverId,
    required double amount,
    String? note,
  }) =>
      _recordDriverLedgerEntry(
        driverId: driverId,
        amount: amount,
        type: models.DriverTransactionType.adjustment,
        note: note,
      );

  /// يكتب حركة دفتر ويحدّث الرصيد معاً في دفعة واحدة — إمّا أن يتغيّر الرصيد
  /// ومعه سجلّه أو لا يتغيّر شيء، فلا يبقى رصيد بلا تفسير.
  Future<void> _recordDriverLedgerEntry({
    required String driverId,
    required double amount,
    required models.DriverTransactionType type,
    String? note,
  }) async {
    if (amount == 0) return;
    final doc = await _drivers.doc(driverId).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('السائق غير موجود');
    }
    final current = models.Driver.fromMap(doc.data()!, doc.id).balance;
    final txRef = _driverTransactions.doc();
    final batch = _db.batch();
    batch.update(_drivers.doc(driverId), {
      'balance': FieldValue.increment(amount),
      // الصرف يُراكم في إجمالي ما استلمه السائق فعلياً.
      if (type == models.DriverTransactionType.payout)
        'totalEarnings': FieldValue.increment(amount.abs()),
    });
    batch.set(
      txRef,
      models.DriverTransaction(
        id: txRef.id,
        driverId: driverId,
        type: type,
        amount: amount,
        balanceAfter: current + amount,
        note: note,
        performedBy: _auth.currentUser?.uid ?? '',
        createdAt: DateTime.now(),
      ).toMap(),
    );
    await batch.commit();
  }

  // -------------------------------------------------------------------------
  // تسويات المطاعم — دفتر المطعم بالطرح: المستحق (صافي طلباته المكتملة)
  // ناقص المدفوع (هذه الدفعات).
  // -------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _restaurantSettlements =>
      _db.collection('restaurant_settlements');

  Future<void> recordRestaurantSettlement({
    required String restaurantId,
    required String restaurantName,
    required double amount,
    String method = '',
    String? note,
  }) async {
    if (amount <= 0) throw Exception('أدخل مبلغاً أكبر من صفر');
    final ref = _restaurantSettlements.doc();
    await ref.set(models.RestaurantSettlement(
      id: ref.id,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      amount: amount,
      method: method.trim(),
      note: note?.trim(),
      performedBy: _auth.currentUser?.uid ?? '',
      createdAt: DateTime.now(),
    ).toMap());
  }

  /// تسويات مطعم واحد، الأحدث أولاً (ترتيب محلي — لا فهرس مركّب).
  Stream<List<models.RestaurantSettlement>> streamRestaurantSettlements(
          String restaurantId) =>
      _restaurantSettlements
          .where('restaurantId', isEqualTo: restaurantId)
          .limit(200)
          .snapshots()
          .map((s) {
        final list = s.docs
            .map((d) => models.RestaurantSettlement.fromMap(d.data(), d.id))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  /// كل التسويات للوحة الإدارة.
  Stream<List<models.RestaurantSettlement>> streamAllRestaurantSettlements() =>
      _restaurantSettlements.limit(500).snapshots().map((s) {
        final list = s.docs
            .map((d) => models.RestaurantSettlement.fromMap(d.data(), d.id))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  // -------------------------------------------------------------------------
  // أكواد الخصم — التحقق عند العميل، والتقييد عند إنشاء الطلب.
  // -------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _coupons =>
      _db.collection('coupons');

  /// سجلّ استخدام الكوبونات: معرّف المستند `CODE_uid` فيمنع تكرار المستخدم
  /// نفسه بلا استعلام، ويُحصى منه عدد مرّاته.
  CollectionReference<Map<String, dynamic>> get _couponUsages =>
      _db.collection('coupon_usages');

  String _usageId(String code, String uid) => '${code}_$uid';

  /// التحقق من كود خصم قبل تطبيقه. يرمي رسالة عربية مفهومة عند كل سبب رفض،
  /// ويعيد الكوبون صالحاً.
  ///
  /// ملاحظة أمنية: هذا تحقّق واجهة لتجربة المستخدم؛ الحارس النهائي أن قيمة
  /// الخصم تُعاد كتابتها من الكوبون نفسه لحظة إنشاء الطلب (لا من الشاشة)،
  /// وأن القواعد تمنع أي عبث بعدّاد الاستخدام.
  Future<models.Coupon> validateCoupon({
    required String rawCode,
    required String userId,
    required double itemsTotal,
    required String restaurantId,
  }) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) throw Exception('اكتب كود الخصم');
    final doc = await _coupons.doc(code).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('كود الخصم غير صحيح');
    }
    final coupon = models.Coupon.fromMap(doc.data()!, doc.id);
    if (!coupon.isActive) throw Exception('هذا الكود موقوف');
    if (coupon.isExpired) throw Exception('انتهت صلاحية هذا الكود');
    if (coupon.isExhausted) throw Exception('استُنفد هذا الكود');
    if (coupon.restaurantId.isNotEmpty && coupon.restaurantId != restaurantId) {
      throw Exception('هذا الكود لا يسري على هذا المطعم');
    }
    if (itemsTotal < coupon.minOrderTotal) {
      throw Exception(
          'الكود يبدأ من ${coupon.minOrderTotal.toStringAsFixed(0)} ر.س للوجبات');
    }
    if (coupon.perUserLimit > 0) {
      final usageDoc = await _couponUsages.doc(_usageId(code, userId)).get();
      final used = (usageDoc.data()?['count'] as num?)?.toInt() ?? 0;
      if (used >= coupon.perUserLimit) {
        throw Exception('استخدمت هذا الكود من قبل');
      }
    }
    return coupon;
  }

  /// تقييد استخدام الكوبون بعد نجاح الطلب — عدّاد كلي + عدّاد لكل مستخدم.
  /// يُستدعى بعد [placeOrder]؛ فشله لا يُلغي الطلب (الخصم مسجَّل في الطلب
  /// نفسه) لكنه يُسجَّل في السجلّ.
  Future<void> _recordCouponUse({
    required String code,
    required String userId,
    required String orderId,
  }) async {
    final batch = _db.batch();
    batch.update(_coupons.doc(code), {'usedCount': FieldValue.increment(1)});
    batch.set(
      _couponUsages.doc(_usageId(code, userId)),
      {
        'code': code,
        'userId': userId,
        'count': FieldValue.increment(1),
        'lastOrderId': orderId,
        'lastUsedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Stream<List<models.Coupon>> streamCoupons() =>
      _coupons.limit(200).snapshots().map((s) {
        final list =
            s.docs.map((d) => models.Coupon.fromMap(d.data(), d.id)).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  /// إنشاء/تعديل كوبون من لوحة الإدارة. `merge` يحفظ عدّاد الاستخدام
  /// القائم فلا يُصفَّر بتعديل قيمة الخصم.
  Future<void> saveCoupon(models.Coupon coupon) =>
      _coupons.doc(coupon.code.trim().toUpperCase()).set(
            coupon.toMap()..remove('usedCount'),
            SetOptions(merge: true),
          );

  Future<void> setCouponActive(String code, bool isActive) =>
      _coupons.doc(code).update({'isActive': isActive});

  Future<void> deleteCoupon(String code) => _coupons.doc(code).delete();

  // -------------------------------------------------------------------------
  // طلبات سحب المستحقّات — السائق يطلب، والإدارة تصرف أو ترفض.
  // -------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _payoutRequests =>
      _db.collection('payout_requests');

  /// تقديم طلب سحب من السائق نفسه. الحارسان هنا خط الدفاع الأول للتجربة
  /// (رسالة عربية مفهومة)؛ التسوية النهائية تظل عند الصرف حيث يُعاد فحص
  /// الرصيد لحظتها.
  Future<void> submitPayoutRequest({
    required String driverId,
    required String driverName,
    required double amount,
    required String method,
  }) async {
    if (amount <= 0) throw Exception('أدخل مبلغاً أكبر من صفر');
    final driverDoc = await _drivers.doc(driverId).get();
    final balance = driverDoc.exists && driverDoc.data() != null
        ? models.Driver.fromMap(driverDoc.data()!, driverDoc.id).balance
        : 0.0;
    if (amount > balance) {
      throw Exception(
          'المبلغ أكبر من رصيدك المتاح (${balance.toStringAsFixed(2)} ر.س)');
    }
    final existing = await _payoutRequests
        .where('driverId', isEqualTo: driverId)
        .get();
    final hasPending = existing.docs
        .map((d) => models.PayoutRequest.fromMap(d.data(), d.id))
        .any((r) => r.status == models.PayoutRequestStatus.pending);
    if (hasPending) {
      throw Exception('لديك طلب سحب قيد المعالجة بالفعل — انتظر بتّه أولاً');
    }
    final ref = _payoutRequests.doc();
    await ref.set(models.PayoutRequest(
      id: ref.id,
      driverId: driverId,
      driverName: driverName,
      amount: amount,
      method: method.trim(),
      createdAt: DateTime.now(),
    ).toMap());
  }

  /// طلبات سحب سائق واحد، الأحدث أولاً (ترتيب محلي — لا فهرس مركّب).
  Stream<List<models.PayoutRequest>> streamMyPayoutRequests(String driverId) =>
      _payoutRequests
          .where('driverId', isEqualTo: driverId)
          .limit(50)
          .snapshots()
          .map((s) {
        final list = s.docs
            .map((d) => models.PayoutRequest.fromMap(d.data(), d.id))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  /// كل طلبات السحب للوحة الإدارة، الأحدث أولاً.
  Stream<List<models.PayoutRequest>> streamAllPayoutRequests() =>
      _payoutRequests.limit(200).snapshots().map((s) {
        final list = s.docs
            .map((d) => models.PayoutRequest.fromMap(d.data(), d.id))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  /// صرف طلب سحب: خصم الرصيد + حركة payout + إغلاق الطلب — دفعة واحدة.
  /// فحص الحالة والرصيد من قراءة طازجة يمنع الصرف المزدوج (نفس درس
  /// resolveComplaint) والصرف فوق الرصيد إن تراكمت عُهدة بعد التقديم.
  Future<void> payPayoutRequest(models.PayoutRequest request,
      {String? adminNote}) async {
    final freshReq = await _payoutRequests.doc(request.id).get();
    if (!freshReq.exists || freshReq.data() == null) {
      throw Exception('الطلب غير موجود');
    }
    final fresh = models.PayoutRequest.fromMap(freshReq.data()!, freshReq.id);
    if (fresh.status != models.PayoutRequestStatus.pending) {
      throw Exception('هذا الطلب ${fresh.status.label} بالفعل');
    }
    final driverDoc = await _drivers.doc(fresh.driverId).get();
    if (!driverDoc.exists || driverDoc.data() == null) {
      throw Exception('السائق غير موجود');
    }
    final balance =
        models.Driver.fromMap(driverDoc.data()!, driverDoc.id).balance;
    if (fresh.amount > balance) {
      throw Exception(
          'رصيد السائق الحالي (${balance.toStringAsFixed(2)} ر.س) أقل من المبلغ — '
          'تغيّر بعد تقديم الطلب. ارفض الطلب أو انتظر تسويته');
    }
    final txRef = _driverTransactions.doc();
    final batch = _db.batch();
    batch.update(_drivers.doc(fresh.driverId), {
      'balance': FieldValue.increment(-fresh.amount),
      'totalEarnings': FieldValue.increment(fresh.amount),
    });
    batch.set(
      txRef,
      models.DriverTransaction(
        id: txRef.id,
        driverId: fresh.driverId,
        type: models.DriverTransactionType.payout,
        amount: -fresh.amount,
        balanceAfter: balance - fresh.amount,
        note: 'صرف طلب سحب (${fresh.method})',
        performedBy: _auth.currentUser?.uid ?? '',
        createdAt: DateTime.now(),
      ).toMap(),
    );
    batch.update(_payoutRequests.doc(fresh.id), {
      'status': models.PayoutRequestStatus.paid.name,
      'processedAt': Timestamp.fromDate(DateTime.now()),
      if (adminNote != null && adminNote.trim().isNotEmpty)
        'adminNote': adminNote.trim(),
    });
    await batch.commit();
  }

  /// رفض طلب سحب بسبب مكتوب يظهر للسائق.
  Future<void> rejectPayoutRequest(String requestId, String adminNote) async {
    final freshReq = await _payoutRequests.doc(requestId).get();
    if (!freshReq.exists || freshReq.data() == null) {
      throw Exception('الطلب غير موجود');
    }
    final fresh = models.PayoutRequest.fromMap(freshReq.data()!, freshReq.id);
    if (fresh.status != models.PayoutRequestStatus.pending) {
      throw Exception('هذا الطلب ${fresh.status.label} بالفعل');
    }
    await _payoutRequests.doc(requestId).update({
      'status': models.PayoutRequestStatus.rejected.name,
      'adminNote': adminNote.trim(),
      'processedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// سجلّ حركات سائق، الأحدث أولاً. (ترتيب محلي — انظر تعليق
  /// [streamWalletTransactions] عن الفهارس المركّبة.)
  Stream<List<models.DriverTransaction>> streamDriverTransactions(String driverId) =>
      _driverTransactions
          .where('driverId', isEqualTo: driverId)
          .snapshots()
          .map((s) => s.docs
              .map((d) => models.DriverTransaction.fromMap(d.data(), d.id))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  /// إلغاء إداري — من لوحة التحكم، ومسموح في أي حالة نشطة.
  Future<void> cancelOrder(String orderId) async {
    final order = await _getOrderOrThrow(orderId);
    await updateOrderStatus(orderId, models.OrderStatus.cancelled);
    await _refundWalletOnCancel(order);
    // إن كان السائق قد استلم الطلب فعُهدته مقيّدة عليه — تُردّ له، فالطلب
    // الملغى لن يحصّل قيمته من أحد.
    await _reverseCustodyIfNeeded(order);
  }

  /// إلغاء العميل لطلبه — مسموح فقط قبل أن يبدأ المطعم التحضير
  /// ([models.Order.canCustomerCancel]). التحقق هنا وليس في الواجهة فقط، حتى
  /// لا يمرّ إلغاء متأخر لو استُدعيت الدالة من مسار آخر أو تغيّرت الحالة بين
  /// عرض الزر والضغط عليه.
  Future<void> cancelOrderByCustomer(String orderId) async {
    final order = await _getOrderOrThrow(orderId);
    if (!order.canCustomerCancel) {
      throw Exception('لا يمكن إلغاء الطلب بعد بدء التحضير، تواصل مع الإدارة');
    }
    await updateOrderStatus(orderId, models.OrderStatus.cancelled);
    await _refundWalletOnCancel(order);
  }

  Future<models.Order> _getOrderOrThrow(String orderId) async {
    final doc = await _orders.doc(orderId).get();
    final data = doc.data();
    if (!doc.exists || data == null) {
      throw Exception('الطلب غير موجود');
    }
    return models.Order.fromMap(data, doc.id);
  }

  /// يُعيد إلى محفظة العميل ما خُصم منها لهذا الطلب عند إلغائه.
  ///
  /// بدون هذه الخطوة كان العميل يدفع من رصيده ثم يُلغى طلبه فيضيع الرصيد
  /// نهائياً — خسارة مباشرة له لا يراها إلا بمقارنة رصيده قبل الطلب وبعده.
  ///
  /// يُستدعى بعد نجاح تغيير الحالة لا قبله: لو فشل الإلغاء لسبب ما، لا يكون
  /// رصيد قد أُعيد لطلب ما زال قائماً.
  Future<void> _refundWalletOnCancel(models.Order order) async {
    if (order.walletUsed <= 0) return;
    await _recordWalletEntry(
      userId: order.customerId,
      amount: order.walletUsed,
      type: models.WalletTransactionType.orderReversal,
      orderId: order.id,
      orderNumber: order.orderNumber,
      note: 'إلغاء الطلب',
    );
  }

  Future<Map<String, dynamic>> getDeliverySettings() async {
    final doc = await _deliverySettings.doc('config').get();
    return doc.data() ?? {};
  }

  /// يحدّث متوسط تقييم المطعم تراكمياً بنفس أسلوب تقييم السائق. كان تقييم
  /// المطاعم لا يُحدَّث إطلاقاً، فتبقى كلها على القيمة الافتراضية 5.0 مهما
  /// بلغ عدد الطلبات — وهو ما يُفقد التقييمات معناها أمام العميل.
  Future<void> updateRestaurantRating(String restaurantId, double newRating) async {
    if (restaurantId.isEmpty) return;
    final doc = await _restaurants.doc(restaurantId).get();
    if (!doc.exists || doc.data() == null) return;
    final restaurant = models.Restaurant.fromMap(doc.data()!, doc.id);
    final newCount = restaurant.ratingCount + 1;
    // المطاعم بلا تقييمات سابقة تبدأ من التقييم الأول نفسه، لا من متوسط مع
    // القيمة الافتراضية 5.0 التي لم يمنحها أحد.
    final newAvg = restaurant.ratingCount <= 0
        ? newRating
        : ((restaurant.rating * restaurant.ratingCount) + newRating) / newCount;
    await _restaurants.doc(restaurantId).update({
      'rating': double.parse(newAvg.toStringAsFixed(1)),
      'ratingCount': newCount,
    });
  }

  Future<void> rateOrder({
    required String orderId,
    required String driverId,
    required double orderRating,
    required double driverRating,
    String? review,
    String? restaurantId,
  }) async {
    await _orders.doc(orderId).update({
      'customerRating': orderRating,
      'driverRating': driverRating,
      'isRated': true,
      // كان المفتاح 'review' بينما النموذج يقرأ 'customerReview' — فكل نص
      // تقييم كتبه عميل كان يُحفظ في حقل لا يقرؤه أحد ويضيع من كل الشاشات.
      if (review != null) 'customerReview': review,
    });
    await updateDriverRating(driverId, driverRating);
    if (restaurantId != null) {
      await updateRestaurantRating(restaurantId, orderRating);
    }
  }

  Stream<List<models.Complaint>> streamComplaints() => _complaints
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => models.Complaint.fromMap(d.data(), d.id)).toList());

  // شكاوى المستخدم الواحد: ترتيب محلي بدل orderBy — انظر تعليق
  // [streamWalletTransactions] عن الفهارس المركّبة.
  Stream<List<models.Complaint>> streamComplaintsSubmittedBy(String uid) => _complaints
      .where('submittedByUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => models.Complaint.fromMap(d.data(), d.id)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  Stream<List<models.Complaint>> streamComplaintsAgainst(String uid) => _complaints
      .where('againstUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => models.Complaint.fromMap(d.data(), d.id)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  /// شكاوى مطعم بعينه — تبويب «مقدَّمة عليّ» عند مدير المطعم. الشكوى ضد
  /// المطعم تُسجَّل بمعرّف المطعم في againstUid لا بمعرّف مديره، فالاستعلام
  /// هنا بمعرّف المطعم (وقاعدة الأمان تسمح لمديره بذلك تحديداً).
  Stream<List<models.Complaint>> streamComplaintsForRestaurant(String restaurantId) =>
      _complaints
          .where('restaurantId', isEqualTo: restaurantId)
          .snapshots()
          .map((s) => s.docs
              .map((d) => models.Complaint.fromMap(d.data(), d.id))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  /// متابعة حيّة لشكوى واحدة — تحتاجها شاشة التفاصيل ليرى مقدّمها تغيّر
  /// الحالة وصدور القرار لحظياً. `null` إن حُذفت.
  Stream<models.Complaint?> streamComplaint(String complaintId) =>
      _complaints.doc(complaintId).snapshots().map((d) =>
          d.exists && d.data() != null
              ? models.Complaint.fromMap(d.data()!, d.id)
              : null);

  Future<void> submitComplaint(models.Complaint complaint) =>
      _complaints.doc(complaint.id).set(complaint.toMap());

  Future<void> updateComplaintStatus(
    String complaintId,
    models.ComplaintStatus status, {
    String? adminNote,
    String? resolution,
  }) =>
      _complaints.doc(complaintId).update({
        'status': status.name,
        if (adminNote != null) 'adminNote': adminNote,
        if (resolution != null) 'resolution': resolution,
      });

  static const int _driverWarningThreshold = 3;

  Future<void> resolveComplaint({
    required models.Complaint complaint,
    required models.Order order,
    required String adminUid,
    double? refundPercentage,
    bool warnAgainstParty = false,
    String? reassignToDriverId,
    String? reassignToDriverName,
    String? adminNote,
  }) async {
    // حارس المضاعفة: الحل يُنفَّذ مرة واحدة. ضغطتان متتاليتان على «تأكيد
    // الحل» (أو نقرة من جهازين) كانتا تضيفان الاسترداد مرتين لمحفظة العميل.
    // الفحص على أحدث حالة في القاعدة لا على النسخة الممررة من الشاشة، فقد
    // تكون فُتحت قبل أن يحلها مدير آخر.
    final freshDoc = await _complaints.doc(complaint.id).get();
    final freshStatus = models.Complaint.fromMap(
            freshDoc.data() ?? const {}, complaint.id)
        .status;
    if (freshStatus == models.ComplaintStatus.resolved ||
        freshStatus == models.ComplaintStatus.closed) {
      throw Exception('هذه الشكوى محلولة مسبقاً — لا يُنفَّذ الحل مرتين');
    }

    if (refundPercentage != null && refundPercentage > 0) {
      // الاسترداد يُحسب على **قيمة الوجبات** لا على إجمالي الطلب: أجرة
      // التوصيل خدمة أُدّيت فعلاً ووصلت للسائق، فإعادتها للعميل تعني خصمها
      // من المنصّة بلا سبب. الاسترداد الكامل (100%) وحده يشمل الإجمالي لأن
      // الطلب حينها يُعدّ كأن لم يكن.
      // والاسترداد الكامل يُعيد **ما دفعه العميل فعلاً** (بعد خصم الكوبون)
      // لا القيمة قبل الخصم — وإلا رُدّ له أكثر مما دفع.
      final isFullRefund = refundPercentage >= 100;
      final refundAmount = isFullRefund
          ? order.payableTotal
          : order.itemsTotal * (refundPercentage / 100);

      await addWalletCredit(
        order.customerId,
        refundAmount,
        orderId: order.id,
        orderNumber: order.orderNumber,
        note: 'استرداد ${refundPercentage.toStringAsFixed(0)}% — شكوى',
      );

      // الاسترداد الكامل يُنهي الطلب مالياً، فتُضبط حالته على «تم الاسترداد»
      // بدل بقائه «تم التوصيل» فيظهر في التقارير كإيراد محقّق.
      if (isFullRefund) {
        await _orders.doc(order.id).update({
          'status': models.OrderStatus.refunded.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'statusChangedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    if (warnAgainstParty &&
        complaint.againstRole == models.UserRole.driver &&
        complaint.againstUid != null) {
      final driverRef = _drivers.doc(complaint.againstUid!);
      final driverDoc = await driverRef.get();
      if (driverDoc.exists && driverDoc.data() != null) {
        final driver = models.Driver.fromMap(driverDoc.data()!, driverDoc.id);
        final newCount = driver.warningCount + 1;
        final updates = <String, dynamic>{'warningCount': newCount};
        if (newCount >= _driverWarningThreshold) {
          updates['isAvailable'] = false;
          updates['isOnline'] = false;
        }
        await driverRef.update(updates);
      }
    }

    if (reassignToDriverId != null && reassignToDriverName != null) {
      await reassignDriver(
        order: order,
        newDriverId: reassignToDriverId,
        newDriverName: reassignToDriverName,
        reason: 'نقل بناءً على شكوى #${complaint.orderNumber}',
        performedBy: adminUid,
      );
    }

    final actionsSummary = <String>[
      if (refundPercentage != null && refundPercentage > 0)
        'استرداد ${refundPercentage.toStringAsFixed(0)}%',
      if (warnAgainstParty) 'تسجيل إنذار',
      if (reassignToDriverId != null) 'نقل الطلب لسائق آخر',
    ].join(' + ');

    await _complaints.doc(complaint.id).update({
      'status': models.ComplaintStatus.resolved.name,
      'adminNote': adminNote ??
          (actionsSummary.isEmpty ? 'تم الحل بلا إجراء إضافي' : actionsSummary),
    });
  }

  /// دردشة داخلية بين المدير ومقدّم الشكوى — نفس بنية ChatMessage تماماً
  /// المستخدَمة في order_chat_screen.dart، لكن مربوطة بمعرّف الشكوى
  /// (complaintId) بدل معرّف الطلب (orderId)، ومخزَّنة في مجموعة منفصلة
  /// (complaint_messages) حتى لا تختلط بدردشة الطلب بين العميل والسائق.
  Stream<List<models.ChatMessage>> streamComplaintChat(String complaintId) =>
      _complaintMessages
          .where('orderId', isEqualTo: complaintId)
          .snapshots()
          .map((s) => s.docs.map((d) => models.ChatMessage.fromMap(d.data(), d.id)).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));

  Future<void> sendComplaintChatMessage(models.ChatMessage message) =>
      _complaintMessages.doc(message.id).set(message.toMap());

  Stream<List<models.ChatMessage>> streamChatMessages(String orderId) => _messages
      .where('orderId', isEqualTo: orderId)
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map((d) => models.ChatMessage.fromMap(d.data(), d.id)).toList());

  Future<void> sendChatMessage(models.ChatMessage message) =>
      _messages.doc(message.id).set(message.toMap());

  Stream<List<models.BroadcastMessage>> streamBroadcasts(models.BroadcastAudience audience) => _broadcasts
      .where('audience', isEqualTo: audience.name)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => models.BroadcastMessage.fromMap(d.data(), d.id)).toList());

  Future<void> sendBroadcast(models.BroadcastMessage message) =>
      _broadcasts.doc(message.id).set(message.toMap());
}