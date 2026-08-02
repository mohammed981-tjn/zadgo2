// lib/providers/firebase_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/models.dart' as models;
import '../utils/helpers.dart' show haversineDistanceKm;

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _restaurants => _db.collection('restaurants');
  CollectionReference<Map<String, dynamic>> get _orders => _db.collection('orders');
  CollectionReference<Map<String, dynamic>> get _drivers => _db.collection('drivers');
  CollectionReference<Map<String, dynamic>> get _complaints => _db.collection('complaints');
  CollectionReference<Map<String, dynamic>> get _messages => _db.collection('chat_messages');
  CollectionReference<Map<String, dynamic>> get _reassignments => _db.collection('reassignments');
  CollectionReference<Map<String, dynamic>> get _broadcasts => _db.collection('broadcasts');
  CollectionReference<Map<String, dynamic>> get _registrationCodes =>
      _db.collection('registrationCodes');

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
        return to == models.OrderStatus.searchingDriver;
      case models.OrderStatus.searchingDriver:
        return to == models.OrderStatus.driverAssigned ||
            to == models.OrderStatus.noDriverFound;
      case models.OrderStatus.driverAssigned:
        return to == models.OrderStatus.pickedUp;
      case models.OrderStatus.pickedUp:
        return to == models.OrderStatus.onTheWay;
      case models.OrderStatus.onTheWay:
        return to == models.OrderStatus.delivered;
      case models.OrderStatus.delivered:
      case models.OrderStatus.restaurantRejected:
      case models.OrderStatus.noDriverFound:
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

  Stream<List<models.AppUser>> streamUsers() => _users
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => models.AppUser.fromMap(d.data(), d.id)).toList());

  Future<void> updateUser(models.AppUser user) => _users.doc(user.uid).update(user.toMap());

  Future<void> setUserActive(String uid, bool isActive) =>
      _users.doc(uid).update({'isActive': isActive});

  Future<void> deleteUserDoc(String uid) => _users.doc(uid).delete();

  /// ينشئ حساب مستخدم جديد (مثل مدير مطعم) بدون تسجيل خروج المدير الحالي،
  /// عبر تطبيق Firebase ثانوي مؤقت.
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

  /// يرسل رابط إعادة تعيين كلمة المرور إلى بريد المستخدم — تُستخدم من إدارة
  /// التطبيق للتحكم الكامل في بيانات اعتماد أي حساب (بما فيه مدير المطعم)
  /// دون الحاجة لمعرفة كلمة المرور الحالية.
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  static const String _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _randomCode() {
    final rnd = Random.secure();
    return List.generate(6, (_) => _codeChars[rnd.nextInt(_codeChars.length)]).join();
  }

  /// يولّد كود تسجيل جديد وحيد الاستخدام لدور محدد (مدير عام/سائق/مدير
  /// مطعم)، ليُرسله المدير العام يدوياً (واتساب/اتصال) للشخص المستهدف.
  /// يستخدم الرمز نفسه كمعرّف للمستند لضمان عدم تكرار نفس الرمز لرمزين
  /// مختلفين في آن واحد. [restaurantId]/[restaurantName] مطلوبان فقط عند
  /// توليد رمز لدور مدير مطعم.
  Future<models.RegistrationCode> generateRegistrationCode({
    required models.UserRole role,
    String restaurantId = '',
    String restaurantName = '',
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
      );
      await ref.set(entry.toMap());
      return entry;
    }
    throw Exception('تعذّر توليد كود تسجيل فريد، حاول مرة أخرى');
  }

  /// رموز التسجيل الخاصة بمطعم محدد (لعرضها/إعادة إرسالها/إلغائها من لوحة المدير).
  Stream<List<models.RegistrationCode>> streamRegistrationCodes(
          String restaurantId) =>
      _registrationCodes
          .where('restaurantId', isEqualTo: restaurantId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map((d) => models.RegistrationCode.fromMap(d.data(), d.id))
              .toList());

  /// يُبطل كود تسجيل لم يُستخدم بعد (مثلاً عند إرسال رمز جديد بدلاً منه).
  Future<void> revokeRegistrationCode(String code) =>
      _registrationCodes.doc(code.trim().toUpperCase()).delete();

  /// يتحقق أولاً (قراءة فقط، بدون تسجيل دخول) من صلاحية كود التسجيل، ثم
  /// يُنشئ الحساب بالمصادقة (`createUserWithEmailAndPassword`)، وبعد أن
  /// يصبح المستخدم مُصادَقاً (`request.auth != null`) يستهلك الرمز عبر
  /// معاملة Firestore (Transaction) لضمان استخدامه مرة واحدة فقط حتى مع
  /// محاولات متزامنة، بالدور المحدَّد في الرمز (مدير عام/سائق/مدير مطعم) —
  /// ويربطه تلقائياً بالمطعم صاحب الرمز إن كان الدور مدير مطعم، أو ينشئ سجل
  /// سائق إن كان الدور سائق.
  /// في حال فشل استهلاك الرمز بعد إنشاء الحساب (مثلاً استُهلك الرمز من
  /// محاولة متزامنة أخرى بين التحقق الأولي وإنشاء الحساب)، يُحذف الحساب
  /// المُصادَق حديثاً لتفادي ترك حساب "يتيم" بلا رمز صالح.
  /// [expectedRole] (اختياري): حين تُمرَّر من نكهة تطبيق مقيّدة بدور واحد
  /// (سائق/مطعم/أدمن)، يُرفض أي كود بدور مختلف فوراً كقراءة فقط قبل إنشاء
  /// الحساب أصلاً — لا تغيير في ترتيب استهلاك الرمز.
  Future<models.AppUser> registerWithCode({
    required String code,
    required String name,
    required String email,
    required String password,
    required String phone,
    String? nationalId,
    // الدور المتوقَع لهذه النكهة (سائق/مطعم/أدمن)؛ null يعني بلا قيد (النكهة
    // الكاملة). فحص قراءة فقط لا يغيّر ترتيب الكتابة على registrationCodes.
    models.UserRole? expectedRole,
  }) async {
    final ref = _registrationCodes.doc(code.trim().toUpperCase());

    // 1) تحقق أولي (قراءة فقط) قبل أي تسجيل دخول — لا يتطلب كتابة على
    // registrationCodes، فيعمل حتى بدون مصادقة.
    final initialSnap = await ref.get();
    if (!initialSnap.exists || initialSnap.data() == null) {
      throw Exception('كود التسجيل غير صحيح');
    }
    final initial = models.RegistrationCode.fromMap(initialSnap.data()!, initialSnap.id);
    if (initial.isUsed) {
      throw Exception('تم استخدام هذا الرمز من قبل، يرجى طلب رمز جديد');
    }
    if (expectedRole != null && initial.role != expectedRole) {
      throw Exception('هذا الكود غير مخصص لهذا التطبيق');
    }

    // 2) إنشاء الحساب بالمصادقة — بعدها يصبح request.auth != null.
    final cred = await register(email.trim(), password.trim());
    final uid = cred.user!.uid;

    try {
      // 3) الآن بعد المصادقة، استهلك الرمز عبر معاملة Firestore لضمان
      // الذرّية حتى مع محاولات متزامنة.
      final claimed = await _db.runTransaction<models.RegistrationCode>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists || snap.data() == null) {
          throw Exception('كود التسجيل غير صحيح');
        }
        final current = models.RegistrationCode.fromMap(snap.data()!, snap.id);
        if (current.isUsed) {
          throw Exception('تم استخدام هذا الرمز من قبل، يرجى طلب رمز جديد');
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
      // فشل استهلاك الرمز أو إنشاء بيانات المستخدم بعد إنشاء حساب المصادقة
      // — نحذف حساب المصادقة اليتيم لتفادي ترك حساب بلا بيانات مرتبطة به.
      try {
        await cred.user?.delete();
      } catch (_) {
        // تجاهل أي خطأ أثناء التنظيف، الأولوية لإعادة رمي الخطأ الأصلي.
      }
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
      .orderBy('sortOrder')
      .snapshots()
      .map((s) => s.docs.map((d) => models.MenuCategory.fromMap(d.data(), d.id)).toList());

  Future<void> addCategory(models.MenuCategory cat) =>
      _categories(cat.restaurantId).doc(cat.id).set(cat.toMap());

  Stream<List<models.MenuItem>> streamMenuItems(String rId) => _items(rId)
      .snapshots()
      .map((s) => s.docs.map((d) => models.MenuItem.fromMap(d.data(), d.id)).toList());

  Future<void> addMenuItem(models.MenuItem item) =>
      _items(item.restaurantId).doc(item.id).set(item.toMap());
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

  // ✅ تتبع حي لموقع السائق
  Future<void> updateDriverLocation(String driverId, double lat, double lng) =>
      _drivers.doc(driverId).update({
        'lat': lat,
        'lng': lng,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });

  Future<void> markPayoutDone(String driverId, double amount) =>
      _drivers.doc(driverId).update({
        'totalEarnings': FieldValue.increment(amount),
        'pendingPayout': 0,
      });

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
    return order.id;
  }

  Stream<List<models.Order>> streamAllOrders() => _orders
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => models.Order.fromMap(d.data(), d.id)).toList());

  /// جميع الطلبات النشطة والقادمة (لشاشة متابعة الطلبات الحية في لوحة المدير)
  Stream<List<models.Order>> streamActiveOrders() => _orders
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => models.Order.fromMap(d.data(), d.id))
          .where((o) => o.status.isActive)
          .toList());

  /// طلبات مطعم محدد فقط (لتطبيق/دور مدير المطعم)
  Stream<List<models.Order>> streamRestaurantOrders(String restaurantId) => _orders
      .where('restaurantId', isEqualTo: restaurantId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => models.Order.fromMap(d.data(), d.id)).toList());

  Stream<List<models.Order>> streamCustomerOrders(String customerId) => _orders
      .where('customerId', isEqualTo: customerId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => models.Order.fromMap(d.data(), d.id)).toList());

  Stream<List<models.Order>> streamDriverOrders(String driverId) => _orders
      .where('driverId', isEqualTo: driverId)
      .orderBy('createdAt', descending: true)
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

    final batch = _db.batch();
    batch.update(ref, {
      'driverId': driverId,
      'driverName': driverName,
      'status': models.OrderStatus.driverAssigned.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'statusChangedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_drivers.doc(driverId), {'isAvailable': false});
    await batch.commit();
  }

  /// خوارزمية تعيين السائق التلقائي: تبحث عن أقرب سائق متصل ومتاح لموقع
  /// المطعم (باستخدام معادلة Haversine) وتُسند له الطلب تلقائياً.
  /// تُعيد true إذا تم إيجاد سائق مناسب وتعيينه، أو false إن لم يوجد.
  Future<bool> autoAssignNearestDriver(models.Order order) async {
    if (order.restaurantLat == null || order.restaurantLng == null) return false;
    final driversSnap = await _drivers.get();
    models.Driver? nearest;
    double nearestDistance = double.infinity;
    for (final doc in driversSnap.docs) {
      final d = models.Driver.fromMap(doc.data(), doc.id);
      if (!d.isOnline || !d.isAvailable) continue;
      if (d.lat == null || d.lng == null) continue;
      final distance = haversineDistanceKm(order.restaurantLat!, order.restaurantLng!, d.lat!, d.lng!);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = d;
      }
    }
    if (nearest == null) return false;
    await assignDriver(order.id, nearest.id, nearest.name);
    return true;
  }

  /// تحويل الطلب من سائق إلى آخر (يستخدمها المدير فقط عند الطوارئ)
  /// آلية استقبال الطلب من قبل السائق الأول تبقى دون أي تغيير.
  Future<void> reassignDriver({
    required models.Order order,
    required String newDriverId,
    required String newDriverName,
    required String reason,
    required String performedBy,
  }) async {
    final batch = _db.batch();
    batch.update(_orders.doc(order.id), {
      'driverId': newDriverId,
      'driverName': newDriverName,
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
  }

  Stream<List<models.DriverReassignment>> streamReassignments() => _reassignments
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => models.DriverReassignment.fromMap(d.data(), d.id)).toList());

  Future<void> markOrderPickedUp(String orderId) async {
    await updateOrderStatus(orderId, models.OrderStatus.pickedUp);
    await updateOrderStatus(orderId, models.OrderStatus.onTheWay);
  }

  Future<void> markOrderDelivered(String orderId, String driverId) async {
    final orderDoc = await _orders.doc(orderId).get();
    double commission = 0;
    double driverPayout = 10;
    if (orderDoc.exists && orderDoc.data() != null) {
      final order = models.Order.fromMap(orderDoc.data()!, orderDoc.id);
      if (!_isValidStatusTransition(order.status, models.OrderStatus.delivered)) {
        throw Exception(
            'انتقال حالة غير صالح: من ${order.status.name} إلى ${models.OrderStatus.delivered.name}');
      }
      commission = order.calculatedCommission;
      driverPayout = order.driverShare;
    }
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
      'pendingPayout': FieldValue.increment(driverPayout),
      'isAvailable': true,
    });
    await batch.commit();
  }

  Future<void> cancelOrder(String orderId) =>
      updateOrderStatus(orderId, models.OrderStatus.cancelled);

  Future<void> rateOrder({
    required String orderId,
    required String driverId,
    required double orderRating,
    required double driverRating,
    String? review,
  }) async {
    await _orders.doc(orderId).update({
      'customerRating': orderRating,
      'driverRating': driverRating,
      'isRated': true,
      if (review != null) 'review': review,
    });
    await updateDriverRating(driverId, driverRating);
  }

  Stream<List<models.Complaint>> streamComplaints() => _complaints
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => models.Complaint.fromMap(d.data(), d.id)).toList());

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

  // ✅ الشات — دردشة بين العميل والسائق
  Stream<List<models.ChatMessage>> streamChatMessages(String orderId) => _messages
      .where('orderId', isEqualTo: orderId)
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map((d) => models.ChatMessage.fromMap(d.data(), d.id)).toList());

  Future<void> sendChatMessage(models.ChatMessage message) =>
      _messages.doc(message.id).set(message.toMap());

  // ✅ البث الجماعي (Broadcast) — رسالة عامة من المدير العام لكل السائقين أو
  // لكل العملاء دفعة واحدة. شاشة منفصلة تماماً عن دردشة الطلب الفردية.
  Stream<List<models.BroadcastMessage>> streamBroadcasts(models.BroadcastAudience audience) => _broadcasts
      .where('audience', isEqualTo: audience.name)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => models.BroadcastMessage.fromMap(d.data(), d.id)).toList());

  Future<void> sendBroadcast(models.BroadcastMessage message) =>
      _broadcasts.doc(message.id).set(message.toMap());
}
