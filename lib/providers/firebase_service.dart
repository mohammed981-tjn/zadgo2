// lib/providers/firebase_service.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart' as models;
import '../utils/api_config.dart';
import '../utils/dispatch_score.dart';
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
  CollectionReference<Map<String, dynamic>> get _driverApplications =>
      _db.collection('driver_applications');
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
  CollectionReference<Map<String, dynamic>> get _restaurantRequests =>
      _db.collection('restaurant_requests');

  /// تسجيل طلب «أضيفوا هذا المطعم» (ح5): المعرّف الاسم مطبَّعاً فتتجمع
  /// طلبات نفس المطعم عدّاداً واحداً. set بدمج: أول طالبٍ يُنشئ والباقون
  /// يزيدون — والقواعد تضبط الزيادة +1 كنمط عدّاد الكوبون.
  Future<void> requestRestaurant(String rawName) async {
    final name = rawName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length < 2) throw Exception('اكتب اسم المطعم');
    final slug = name.replaceAll(' ', '-');
    await _restaurantRequests.doc(slug).set({
      'name': name,
      'count': FieldValue.increment(1),
      'lastRequestedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<models.RestaurantRequest>> streamRestaurantRequests() =>
      _restaurantRequests.snapshots().map((s) {
        final list = s.docs
            .map((d) => models.RestaurantRequest.fromMap(d.data(), d.id))
            .toList();
        list.sort((a, b) => b.count.compareTo(a.count));
        return list;
      });

  Future<void> removeRestaurantRequest(String id) =>
      _restaurantRequests.doc(id).delete().then((_) {
        logAdminAction('restaurantRequest.done', 'مطعم مطلوب أُضيف: $id');
      });

  /// تبديل مطعم في مفضلة العميل (ح2) — arrayUnion/Remove ذرّيتان فلا
  /// يفسد سباقُ ضغطتين متتاليتين المصفوفةَ، والقاعدة القائمة تسمح بها
  /// (المستخدم يعدّل مستنده عدا الدور والتفعيل والرصيد صعوداً).
  Future<void> toggleFavoriteRestaurant(
      String uid, String restaurantId, bool add) =>
      _users.doc(uid).update({
        'favoriteRestaurantIds': add
            ? FieldValue.arrayUnion([restaurantId])
            : FieldValue.arrayRemove([restaurantId]),
      });

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

  /// التحقق الخادمي من دفعة ميسر (د٣-أ): verify.php يسأل البوابة بالمفتاح
  /// السري ويختم verified_payments — وقواعد الإنشاء ترفض طلب بطاقة بلا
  /// ختم. يعيد true عند الختم، وfalse عند أي فشل (شبكة/خادم/دفعة غير
  /// مدفوعة) — والمستدعي يقرر الإعادة، فالمبلغ محجوز ولا يجوز إضاعته.
  Future<bool> verifyCardPayment(String paymentId) async {
    if (!ApiConfig.isConfigured || paymentId.trim().isEmpty) return false;
    try {
      final token = await _auth.currentUser?.getIdToken();
      if (token == null) return false;
      final res = await http
          .post(ApiConfig.verifyEndpoint,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'payment_id': paymentId.trim()}))
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('verifyCardPayment: $e');
      return false;
    }
  }

  /// حذف الحساب داخل التطبيق (هـ٤ — قاعدة آبل 5.1.1(v) وGoogle Play).
  ///
  /// إخفاء هوية لا حذف سجلّ: بيانات التعريف تُمحى من مستند المستخدم
  /// ويُحذف حساب الدخول نهائياً، وتبقى الطلبات والدفاتر المالية كما هي —
  /// قواعدنا نفسها تمنع حذف السجلّ المحاسبي، والمتاجر تطلب حذف الحساب
  /// لا تزوير التاريخ المالي. يرمي استثناءً يعرضه المستدعي (أشهره
  /// requires-recent-login فيُطلب من المستخدم كلمة مروره).
  Future<void> deleteMyAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('لا حساب مسجّل دخوله');
    }
    // إعادة مصادقة إلزامية: حذف حساب بجلسة قديمة مخاطرة يمنعها Firebase.
    await user.reauthenticateWithCredential(EmailAuthProvider.credential(
        email: user.email!, password: password));
    await _users.doc(user.uid).update({
      'name': 'مستخدم محذوف',
      'phone': '',
      'email': '',
    });
    await user.delete();
  }

  /// قيد في سجلّ التدقيق الإداري — نفس المجموعة وأسماء الأفعال التي
  /// تكتبها لوحة الويب (`admin_audit`)، مع `source: 'app'` تمييزاً لقيود
  /// الجوّال، فيقرأ المالك سجلاً واحداً مهما اختلف الجهاز.
  ///
  /// لا await عند الاستدعاء ولا إشعار عند الفشل: الفعل الإداري نفسه نجح،
  /// وقيدٌ ضاع لعطل شبكة عابر لا يستحق مقاطعة المدير — صفحة السجل في
  /// اللوحة تكشف أي انقطاع. والقواعد تشترط by == uid فلا يُنسب قيد لغير
  /// كاتبه.
  Future<void> logAdminAction(String action, String summary,
      {Map<String, dynamic> extra = const {}}) async {
    try {
      final u = _auth.currentUser;
      await _db.collection('admin_audit').add({
        'action': action,
        'summary': summary.length > 300 ? summary.substring(0, 300) : summary,
        'by': u?.uid ?? '',
        'byName': u?.displayName ?? '',
        'byEmail': u?.email ?? '',
        'source': 'app',
        ...extra,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('audit write failed: $action $e');
    }
  }

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
    String referredByCode = '',
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
        referredByCode: referredByCode.trim().toUpperCase(),
      );
      await ref.set(entry.toMap());
      logAdminAction('code.create',
          'إصدار كود تسجيل $code (${role.name})'
          '${restaurantName.isEmpty ? '' : ' — $restaurantName'}');
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

  Future<void> revokeRegistrationCode(String code) async {
    await _registrationCodes.doc(code.trim().toUpperCase()).delete();
    logAdminAction('code.delete', 'حذف كود تسجيل ${code.trim().toUpperCase()}');
  }

  Future<models.AppUser> registerWithCode({
    required String code,
    required String name,
    required String email,
    required String password,
    required String phone,
    String? nationalId,
    models.UserRole? expectedRole,
    String? referredByCode,
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
        // ختم الكود باسم صاحبه **داخل المعاملة** لا بعد إنشاء المستخدم:
        // حارس القواعد الجديد يتحقّق أن مستند المستخدم يحمل كوداً مختوماً
        // بمعرّفه هو، فلا يُنشئ أحد مستنده بدور admin. ولو تأخّر الختم
        // لرُفض إنشاء المستخدم لأن الكود لم يُنسب إليه بعد.
        tx.update(ref, {
          'isUsed': true,
          'usedAt': FieldValue.serverTimestamp(),
          'usedByUid': uid,
          'usedByName': name.trim(),
        });
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
        registrationCode: ref.id,
      );
      await createUser(newUser);
      if (claimed.role == models.UserRole.driver) {
        await addDriver(models.Driver(
          id: uid,
          name: name.trim(),
          phone: phone.trim(),
          vehicleType: 'دراجة نارية',
          // كود الداعي يُثبَّت لحظة التسجيل ولا يُعدَّل بعدها: إتاحة
          // إضافته لاحقاً تعني إحالات تُدّعى بأثر رجعي لسائقين عملوا
          // شهوراً. وتاريخ الانضمام أساس نافذة شرط التوصيلات.
          // كود الداعي: ما كتبه المتقدّم، وإلا ما حمله كود التسجيل نفسه
          // (يضعه المدير عند قبول طلب انضمام جاء عبر رابط إحالة) — فلا
          // تضيع الإحالة لأنه نسي نقل الكود بيده.
          referredByCode: (referredByCode ?? '').trim().isNotEmpty
              ? referredByCode!.trim().toUpperCase()
              : claimed.referredByCode,
          createdAt: DateTime.now(),
        ));
      }
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

  /// إحداثيات المطعم الحيّة بدل لقطة الطلب: الطلب يلتقط موقع المطعم لحظة
  /// إنشائه، فإذا صحّح المدير الموقع بعدها بقي سائق الطلب الجاري يُقاد
  /// للموقع القديم (ملاحظة المالك ٢٠٢٦-٠٨-١١ بعد تجربة فرع فطير ستيشن).
  /// تُستدعى قبل كل استخدام ملاحي؛ الفشل أو غياب الإحداثيات يُبقي اللقطة —
  /// ملاحة بموقع أمس خير من تعطّلها كلياً.
  Future<models.Order> withLiveRestaurantCoords(models.Order o) async {
    try {
      final r = await getRestaurantOnce(o.restaurantId);
      if (r?.lat != null && r?.lng != null) {
        return o.copyWith(restaurantLat: r!.lat, restaurantLng: r.lng);
      }
    } catch (_) {}
    return o;
  }

  /// نشر موقع المطعم المصحَّح على طلباته الجارية — تُستدعى من شاشة المدير
  /// بعد حفظ تعديل الموقع، فتتصحح لقطات الطلبات النشطة دفعةً واحدة: خريطة
  /// الكابتن ودبابيسها وخريطة متابعة العميل كلها تقرأ من مستند الطلب.
  /// الطلبات المنتهية تُترك بلقطتها عمداً — سجلّ تاريخي لما جرى فعلاً.
  Future<int> propagateRestaurantLocation(
      String restaurantId, double lat, double lng) async {
    final active = models.OrderStatus.values
        .where((s) => s.isActive)
        .map((s) => s.name)
        .toList();
    final snap = await _orders
        .where('restaurantId', isEqualTo: restaurantId)
        .where('status', whereIn: active)
        .get();
    if (snap.docs.isEmpty) return 0;
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'restaurantLat': lat, 'restaurantLng': lng});
    }
    await batch.commit();
    return snap.docs.length;
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

  /// بحث مباشر عن طلب برقمه خارج نافذة الطلبات المحمّلة (٥٠٠ الأحدث) —
  /// شبكة أمان لسجلّ الإدارة: رقم الطلب هو أول ٦ خانات من معرّف المستند
  /// بأحرف كبيرة، فيكفي بحث مدى على المعرّف نفسه بلا حقل جديد ولا فهرس.
  Future<List<models.Order>> findOrdersByNumber(String orderNumber) async {
    final prefix = orderNumber.trim().toLowerCase().replaceAll('#', '');
    if (prefix.isEmpty) return [];
    final snap = await _orders
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: prefix)
        .where(FieldPath.documentId, isLessThan: '$prefix\uF8FF')
        .limit(10)
        .get();
    return snap.docs
        .map((d) => models.Order.fromMap(d.data(), d.id))
        .toList();
  }

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

  /// قراءة لحظية لمستند الطلب — لقرارٍ لا يحتمل لقطةً قديمة (الإسناد مثلاً).
  Future<models.Order?> getOrderOnce(String orderId) async {
    final doc = await _orders.doc(orderId).get();
    if (!doc.exists || doc.data() == null) return null;
    return models.Order.fromMap(doc.data()!, doc.id);
  }

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

  /// تأكيد المطعم تسليمَ الطلب للكابتن — **بلا تغيير حالة** (طلب المالك
  /// ٢٠٢٦-٠٨-١١): الانتقال إلى «في الطريق» يبقى بضغطة الكابتن وحده كما
  /// كان (ضغطة المطعم لا تُثبت استلاماً لم يقع)، وهذا الختم يسجّل الوجه
  /// الثاني للتسليم فيصير في الطلب إقرارُ طرفين لا طرف واحد — وهو ما
  /// يُحتكم إليه في نزاع «سلّمتُه» / «لم يصلني».
  Future<void> confirmRestaurantHandover(String orderId) async {
    final order = await getOrderOnce(orderId);
    if (order == null) throw Exception('الطلب غير موجود');
    if (order.restaurantHandoverAt != null) return; // ختمٌ لا يتكرر
    if (order.status.isFinished) {
      throw Exception('الطلب لم يعد نشطاً — حالته: ${order.status.label}');
    }
    await _orders.doc(orderId).update({
      'restaurantHandoverAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
    await _releaseOrderDriver(current);
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
    var current = await getOrderOnce(orderId);
    if (current == null) throw Exception('الطلب غير موجود');

    // إسناد مبكر (الطلب ما زال عند المطعم): يُربط السائق **بلا تغيير حالة**،
    // تماماً كما يفعل الإسناد التلقائي لحظة قبول المطعم. تحويل الحالة هنا
    // كان يقفز فوق مرحلتَي التحضير والجهوزية ويُسقط دور المطعم من التتبّع —
    // ولذلك كان الإسناد اليدوي يفشل أصلاً على طلبٍ عالق قبل الجهوزية.
    final earlyStage = current.status == models.OrderStatus.restaurantPending ||
        current.status == models.OrderStatus.restaurantAccepted ||
        current.status == models.OrderStatus.preparing;

    if (!earlyStage) {
      if (current.status == models.OrderStatus.readyForPickup) {
        await updateOrderStatus(orderId, models.OrderStatus.searchingDriver);
        current = await getOrderOnce(orderId) ?? current;
      }
      if (!_isValidStatusTransition(
          current.status, models.OrderStatus.driverAssigned)) {
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
      if (!earlyStage) 'status': models.OrderStatus.driverAssigned.name,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!earlyStage) 'statusChangedAt': FieldValue.serverTimestamp(),
      'driverAcknowledged': isDriverOnline,
    });
    batch.update(_drivers.doc(driverId), {'isAvailable': false});
    await batch.commit();
    // إشعار السائق بالإسناد — قد يكون تطبيقه مغلقاً لحظتها.
    NotifyRelay.orderEvent(orderId, OrderEvent.assigned);
  }

  static const int _driverCandidatesCount = 3;

  /// الإسناد التلقائي — أُعيدت كتابته بعد بلاغ المالك (٢٠٢٦-٠٨-١١): طلبات
  /// مطعم بعينه لم تصل أي سائق بعد قبول المطعم لها. كانت الدالة تنسحب
  /// **صامتةً** في ثلاث حالات، وكلها واردة في التشغيل الحقيقي:
  ///
  ///   ١) المطعم بلا إحداثيات على الخريطة (يُضاف من اللوحة ويُنسى موقعه) —
  ///      كان السطر الأول يُرجع false فوراً، فلا يرى الطلبَ سائقٌ أبداً.
  ///   ٢) السائق «غير متاح» عالقاً: إلغاء طلبٍ مُسنَد لم يكن يحرّره، فيبقى
  ///      مشغولاً بطلبٍ لم يعد قائماً — إلى الأبد.
  ///   ٣) سائق بلا إحداثيات (إذن موقع مرفوض) — كان يُستبعَد كلياً.
  ///
  /// المبدأ الآن: **الطلب يخرج لسائقٍ ما دام هناك سائق متصل**؛ المسافة
  /// تُحسّن الاختيار ولا تشترطه، والتقييم يحكم حين تغيب المسافة.
  ///
  /// [excludeDriverId]: سائق يُستبعد من الترشيح — يُمرَّر عند إعادة الإسناد
  /// بعد رفضه للطلب، وإلا اختير «الأقرب» وهو الرافض نفسه فعاد إليه الطلب
  /// فوراً وبعلم إقرار مسبق فلا يظهر له شيء أصلاً.
  Future<bool> autoAssignNearestDriver(models.Order order,
      {String? excludeDriverId}) async {
    // الطلب المجدول (ح4): لا إسناد قبل نافذة موعده — البوابة هنا في
    // القلب لا عند المستدعين، فتحمي كل المسارات (قبول المطعم، إعادة
    // المحاولة، المصالحة، معالجات التعليق) دفعةً واحدة.
    if (order.scheduledStillEarly) return false;

    final driversSnap = await _drivers.get();
    final online = driversSnap.docs
        .map((doc) => models.Driver.fromMap(doc.data(), doc.id))
        .where((d) => d.id != excludeDriverId && d.isOnline)
        .toList();
    if (online.isEmpty) return false;

    // ── الترشيح بالحمولة والعنقود ───────────────────────────────────────
    // قرار المالك ٢٠٢٦-٠٨-١١: «إمكانية استلام السائق لثلاث طلبات في نطاق
    // مطاعم قريبة وليست بعيدة». فالسقف **حدٌّ صارم**، وقُرب المطاعم
    // **تفضيل** لا مانع مطلق — وإلا عاد الانسداد الذي عطّل التشغيل اليوم
    // (كابتن واحد بحمولة، فلا يجد الطلب من يحمله ويبقى بلا سائق للأبد).
    //
    //   ١) الفارغون (حمولة صفر) — الأقرب للمطعم أولاً.
    //   ٢) من له حمولة دون السقف **ومطعمُه ضمن نطاق عنقوده** — التجميع
    //      المقصود: ثلاثة مطاعم متجاورة في خط سير واحد.
    //   ٣) من له حمولة دون السقف أياً كانت المسافة — آخر الحلول حتى لا
    //      يبقى طلبٌ بلا كابتن، والكابتن نفسه يقبل أو يرفض.
    // ومن بلغ السقف لا يُرشَّح إطلاقاً — هذا هو الحد الذي لا يُخترق.
    // من مستند `incentives` لا `config`: القواعد المنشورة تقصر قراءة
    // `config` على المدير وحده، وهذه الدالة تعمل في **تطبيق المطعم** —
    // فقراءتها من هناك ترتدّ برفض صامت، ويعمل الرقمان بالافتراضي أبداً
    // فيصيران مبرمَجين فعلياً مهما ضبطهما المدير (خلاف بند ج١).
    // اكتُشف بعد تنبيه مساعد الويب ٢٠٢٦-٠٨-١١ إلى القيد نفسه.
    var maxLoad = 3;
    var stackKm = 2.0;
    try {
      final s = await getIncentiveSettings();
      maxLoad = s.maxOrdersPerDriver;
      stackKm = s.stackRadiusKm;
    } catch (_) {
      // تعذّرت القراءة — الافتراضيات المعتمدة، والإسناد لا يتوقف لأجل رقم.
    }

    var underCap = online.where((d) => d.activeOrders < maxLoad).toList();
    // عدّاد الحمولة يكتبه **جهاز الكابتن**، فإن أُغلق التطبيق بعد آخر طلب
    // بقي العدّاد على قيمته الأخيرة إلى الأبد. وكابتنٌ عالقٌ على السقف
    // يُخرج نفسه من كل ترشيح لاحق — وبأسطولٍ من كابتن واحد يعني ذلك أن
    // **كل** طلب تالٍ يبقى بلا سائق بلا أثر ظاهر. فقبل الاستسلام تُجرَّب
    // المصالحة (تُصفّر عدّاد من لا طلب جارياً له فعلاً)؛ وهي تنجح في لوحة
    // الإدارة وترتدّ بهدوء في تطبيق المطعم — فلا تُكلّف شيئاً حين تتعذّر.
    var reconciled = false;
    if (underCap.isEmpty) {
      underCap = await _freeStuckDrivers(online);
      if (underCap.isEmpty) return false;
      reconciled = true;
    }

    bool inCluster(models.Driver d) {
      if (d.activeOrders == 0) return true;
      if (d.clusterLat == null ||
          d.clusterLng == null ||
          order.restaurantLat == null ||
          order.restaurantLng == null) {
        return false;
      }
      return haversineDistanceKm(d.clusterLat!, d.clusterLng!,
              order.restaurantLat!, order.restaurantLng!) <=
          stackKm;
    }

    // بعد مصالحةٍ ناجحة صار المحرَّرون فارغين فعلاً في القاعدة، ونسخُهم في
    // الذاكرة وحدها هي المتقادمة — فلا تُعاد المصالحة ولا يُستبعدون بعدّاد
    // بطل مفعوله.
    var available = reconciled
        ? underCap
        : underCap.where((d) => d.activeOrders == 0).toList();
    // الفارغ حسب العلم القديم قد يكون عالقاً — المصالحة تُصحّح متى أمكنت.
    if (available.isEmpty) available = await _freeStuckDrivers(online);
    if (available.isEmpty) {
      available = underCap.where(inCluster).toList();
    }
    if (available.isEmpty) available = underCap;

    // الترشيح بالمسافة حين تتوفر النقطتان، وإلا بالتقييم — لا انسحاب.
    final located = order.restaurantLat != null && order.restaurantLng != null
        ? (available.where((d) => d.lat != null && d.lng != null).toList()
          ..sort((a, b) => haversineDistanceKm(
                  order.restaurantLat!, order.restaurantLng!, a.lat!, a.lng!)
              .compareTo(haversineDistanceKm(
                  order.restaurantLat!, order.restaurantLng!, b.lat!, b.lng!))))
        : <models.Driver>[];
    final pool = located.isNotEmpty
        ? located.take(_driverCandidatesCount).toList()
        : (available.toList()..sort((a, b) => b.rating.compareTo(a.rating)))
            .take(_driverCandidatesCount)
            .toList();

    // أثر معدل القبول (نفذ ٣): كان الرقم يُعرض للكابتن بلا أي أثر — حافز
    // بلا مفعول يفقد معناه سريعاً. الآن يدخل الاختيار بين الأقرب: درجة
    // مركّبة ثلثاها معدل القبول وثلثها التقييم (من ٥ إلى ٠..١) — القبول
    // أثقل لأنه سلوكٌ تجاه المنصّة يومياً والتقييم انطباع عملاء يتجمّد
    // بعد حين. ومن لا تاريخ عروض له يُحسب كاملاً (1.0) لا صفراً ظالماً —
    // نفس مبدأ «—» في شاشة أرباحه. ولا مساس بالمال: الأجرة واحدة للجميع،
    // الأثر في أولوية الترشيح وحدها (بند ج١ سليم).
    pool.sort((a, b) {
      double score(models.Driver d) =>
          dispatchScore(acceptanceRate: d.acceptanceRate, rating: d.rating);
      return score(b).compareTo(score(a));
    });
    final chosen = pool.first;

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

  /// تحرير السائقين العالقين على «غير متاح» بلا طلبٍ جارٍ فعلاً.
  ///
  /// `isAvailable` يُضبط false عند الإسناد ويعود true عند التسليم أو الرفض
  /// أو التحويل — لكن **الإلغاء** كان ينسى تحريره، وكذلك أي انقطاع بين
  /// الخطوتين. فيكفي طلب اختباري واحد أُلغي ليختفي سائق عن كل الطلبات
  /// اللاحقة بلا أثر ظاهر. المصالحة تُشغَّل فقط حين لا يوجد متاح أصلاً —
  /// استعلام واحد إضافي في أسوأ الحالات لا في كل إسناد.
  /// سرد كل الطلبات مسموحٌ للمدير وحده في القواعد، فتفشل المصالحة بهدوء
  /// حين تُستدعى من تطبيق المطعم — ولذلك تُشغَّلها لوحة الإدارة أيضاً عند
  /// فتح «المتابعة الحية» ([reconcileDriverAvailability])، وهي البيئة التي
  /// تملك الصلاحية فعلاً.
  Future<List<models.Driver>> _freeStuckDrivers(
      List<models.Driver> online) async {
    try {
      final busy = <String>{};
      final snap =
          await _orders.orderBy('createdAt', descending: true).limit(300).get();
      for (final doc in snap.docs) {
        final o = models.Order.fromMap(doc.data(), doc.id);
        final id = o.driverId ?? '';
        if (id.isNotEmpty && o.status.isActive) busy.add(id);
      }
      final stuck = online
          .where((d) =>
              (!d.isAvailable || d.activeOrders > 0) && !busy.contains(d.id))
          .toList();
      if (stuck.isEmpty) return [];
      // المصالحة تصحّح العلم **والعدّاد** معاً: عدّادٌ متقادم من جهاز مغلق
      // يمنع الترشيح تماماً كعلم عالق.
      final batch = _db.batch();
      for (final d in stuck) {
        batch.update(_drivers.doc(d.id), {
          'isAvailable': true,
          'activeOrders': 0,
        });
      }
      await batch.commit();
      return stuck;
    } catch (_) {
      // صلاحية سرد ناقصة أو انقطاع — لا نُفشل الإسناد بسبب محاولة إصلاح.
      return [];
    }
  }

  /// بثّ حمولة الكابتن من **جهازه هو** (القواعد المنشورة لا تسمح لتطبيق
  /// المطعم بكتابة غير `isAvailable` على مستند سائق آخر): عدد طلباته
  /// الجارية، ومرساة عنقوده (مطعم أول طلب في الحمولة)، وعلم السعة.
  /// تُستدعى من تدفّق طلباته، ولا تكتب إلا عند تغيّر فعلي — فلا كتابة
  /// دورية تُضاف على خنق الموقع القائم.
  Future<void> publishDriverLoad({
    required String driverId,
    required int activeOrders,
    required bool hasCapacity,
    double? clusterLat,
    double? clusterLng,
  }) async {
    await _drivers.doc(driverId).update({
      'activeOrders': activeOrders,
      'isAvailable': hasCapacity,
      'clusterLat': clusterLat,
      'clusterLng': clusterLng,
    });
  }

  /// سقف الطلبات المتزامنة كما ضبطه المدير (٣ افتراضاً) — يقرؤه تطبيق
  /// الكابتن ليحسب علم سعته بنفس القاعدة التي يرشّح بها المطعم.
  Future<int> maxOrdersPerDriver() async {
    try {
      return (await getIncentiveSettings()).maxOrdersPerDriver;
    } catch (_) {
      return 3;
    }
  }

  /// مصالحة توافر السائقين من لوحة الإدارة — تُحرّر كل من عَلِق «غير متاح»
  /// بلا طلب جارٍ. تُرجع عدد من حُرِّروا (صفر في الحالة السليمة).
  Future<int> reconcileDriverAvailability() async {
    final snap = await _drivers.get();
    final online = snap.docs
        .map((d) => models.Driver.fromMap(d.data(), d.id))
        .where((d) => d.isOnline && !d.isAvailable)
        .toList();
    if (online.isEmpty) return 0;
    return (await _freeStuckDrivers(online)).length;
  }

  /// تحرير سائق طلبٍ انتهى قبل أوانه (إلغاء/رفض) — الوقاية التي تُغني عن
  /// المصالحة أعلاه: يُستدعى في كل مسار إنهاء لا يمرّ بالتسليم.
  Future<void> _releaseOrderDriver(models.Order order) async {
    final id = order.driverId ?? '';
    if (id.isEmpty) return;
    try {
      await _drivers.doc(id).update({'isAvailable': true});
    } catch (_) {
      // فشل التحرير لا يُفشل الإلغاء نفسه — المصالحة ستلتقطه لاحقاً.
    }
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

  /// [dueToTimeout]: انقضت مهلة العرض دون قرار — وهي حالة مختلفة عن الرفض
  /// الصريح: إن لم يوجد كابتن بديل يبقى العرض قائماً لدى صاحبه بدل أن
  /// يُجرَّد الطلب من سائقه فيصير يتيماً لا يلتقطه أحد (لا خادم يعيد
  /// المحاولة، والقواعد تمنع السائقين من سرد الطلبات بلا سائق). هذا هو ما
  /// كان يبتلع طلبات أسطولٍ من كابتن واحد: مهلة تمرّ ← تجريد ← لا بديل ←
  /// طلب معلّق للأبد.
  Future<void> rejectAssignedOrder(String orderId,
      {bool dueToTimeout = false}) async {
    final ref = _orders.doc(orderId);
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('الطلب غير موجود');
    }
    final current = models.Order.fromMap(doc.data()!, doc.id);
    if (!current.needsDriverAcknowledgement) {
      throw Exception('لا يمكن رفض هذا الطلب في حالته الحالية');
    }

    if (dueToTimeout) {
      // يُجرَّب البديل أولاً؛ فإن لم يوجد يُترك كل شيء كما هو.
      final moved = await autoAssignNearestDriver(current,
          excludeDriverId: current.driverId);
      if (!moved) return;
      if ((current.driverId ?? '').isNotEmpty) {
        await _drivers.doc(current.driverId!).update({
          'isAvailable': true,
          'offersTotal': FieldValue.increment(1),
        });
      }
      return;
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
    logAdminAction('order.reassign',
        'إعادة إسناد طلب #${order.orderNumber} إلى $newDriverName',
        extra: {'orderId': order.id});

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
    // الإكرامية (ح3): إلكترونياً قبضتها المنصّة مع المبلغ فتُقيَّد للكابتن
    // هنا مع أجرته — كاملةً بلا اقتطاع. نقدياً هي بيده أصلاً مع التحصيل
    // فلا قيد لها (كأجرته النقدية تماماً).
    final delta = isCash
        // المسار القديم (استلام بنسخة لا تعرف العُهدة): نفس معادلة العُهدة
        // بخصم المدفوع من المحفظة — لا -(itemsTotal+appShare) الخام.
        ? (order.custodyDebited ? 0.0 : -order.custodyAmount)
        : driverPayout + order.driverTip;

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
  Future<void> saveCoupon(models.Coupon coupon) {
    final data = coupon.toMap()..remove('usedCount');
    // toMap يُسقط expiresAt حين يكون null، والدمج يُبقي القيمة القديمة في
    // المستند — فكان زر مسح تاريخ الانتهاء يُظهر نجاحاً والكوبون يحتفظ
    // بتاريخه القديم صامتاً. تُكتب null صراحةً ليُمحى فعلاً.
    data['expiresAt'] = coupon.expiresAt == null
        ? null
        : Timestamp.fromDate(coupon.expiresAt!);
    final code = coupon.code.trim().toUpperCase();
    return _coupons.doc(code).set(data, SetOptions(merge: true)).then((_) {
      logAdminAction('coupon.create', 'حفظ كوبون $code');
    });
  }

  /// هل الكود مستخدَم مسبقاً؟ يُفحص قبل إنشاء كوبون جديد — الحفظ بالدمج على
  /// معرّف = الكود، فبلا هذا الفحص يندمج «الجديد» في القائم صامتاً.
  Future<bool> couponExists(String code) async =>
      (await _coupons.doc(code.trim().toUpperCase()).get()).exists;

  Future<void> setCouponActive(String code, bool isActive) async {
    await _coupons.doc(code).update({'isActive': isActive});
    logAdminAction('coupon.update',
        isActive ? 'تفعيل كوبون $code' : 'إيقاف كوبون $code');
  }

  Future<void> deleteCoupon(String code) async {
    await _coupons.doc(code).delete();
    logAdminAction('coupon.delete', 'حذف كوبون $code');
  }

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
    logAdminAction('payout.pay',
        'صرف سحب ${fresh.amount.toStringAsFixed(2)} ر.س للسائق ${fresh.driverName}',
        extra: {'driverId': fresh.driverId, 'requestId': fresh.id});
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
    logAdminAction('payout.reject',
        'رفض سحب ${fresh.amount.toStringAsFixed(2)} ر.س للسائق ${fresh.driverName}',
        extra: {'driverId': fresh.driverId, 'requestId': requestId});
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
    // ويعود متاحاً: بلا هذا كان يبقى «مشغولاً» بطلبٍ أُلغي فلا تصله عروض.
    await _releaseOrderDriver(order);
    await _compensateRestaurantIfCooked(order);
    await _releaseCouponOnCancel(order);
  }

  /// إرجاع كوبون الطلب الملغى (نفذ ٢): الاستخدام قُيّد لحظة إنشاء الطلب،
  /// فإن أُلغي الطلب خسر العميل كوبونه نهائياً بلا علاج — عقوبة على شيء
  /// ليس ذنبه غالباً (مطعم اعتذر، إدارة ألغت). يُنقَص العدّادان معاً:
  /// عدّاد الكوبون العام وسجلّ استخدام العميل.
  ///
  /// «أفضل جهد» عمداً: القواعد المنشورة اليوم تسمح بالإنقاص للمدير وحده،
  /// فالإرجاع ينجح في إلغاء الإدارة (وهو أكثر الإلغاءات) ويرتدّ صامتاً في
  /// إلغاء العميل المبكر حتى تُنشر القواعد المحدَّثة — وفشله لا يمسّ
  /// الإلغاء نفسه.
  Future<void> _releaseCouponOnCancel(models.Order order) async {
    final code = order.couponCode;
    if (code == null || code.isEmpty || order.discountAmount <= 0) return;
    try {
      final batch = _db.batch();
      batch.update(_coupons.doc(code), {'usedCount': FieldValue.increment(-1)});
      batch.update(_couponUsages.doc(_usageId(code, order.customerId)),
          {'count': FieldValue.increment(-1)});
      await batch.commit();
    } catch (e) {
      debugPrint('⚠️ تعذّر إرجاع الكوبون $code: $e');
    }
  }

  /// هل بدأ المطعم التحضير فعلاً قبل الإلغاء؟ من «جاري التحضير» فصاعداً
  /// تكون تكلفة الطعام قد وقعت — أما «بانتظار الموافقة» و«تم القبول» فلا
  /// طبخ فيهما، والإلغاء عندها «كأن الطلب لم يكن» (قرار المالك).
  static bool _wasCooked(models.OrderStatus s) =>
      s == models.OrderStatus.preparing ||
      s == models.OrderStatus.readyForPickup ||
      s == models.OrderStatus.searchingDriver ||
      s == models.OrderStatus.driverAssigned ||
      s == models.OrderStatus.pickedUp ||
      s == models.OrderStatus.onTheWay;

  /// تعويض المطعم عن طلبٍ أُلغي بعد طبخه — بالمعيار العالمي (يوبر إيتس
  /// ودور داش): يُدفع للمطعم متى قَبِل وطبخ ولم يكن الإلغاء بسببه. يُختم
  /// على مستند الطلب نفسه (لا مجموعة جديدة تحتاج قواعد جديدة)، فتقرأه
  /// دفاتر المطعم والإدارة مباشرةً.
  ///
  /// النسبة من إعدادات المدير لا من الكود (بند ج١)، و٠٪ تعني «لا تعويض»
  /// فيبقى الباب مفتوحاً لسياسة أخرى بلا إصدار جديد.
  Future<void> _compensateRestaurantIfCooked(models.Order order) async {
    if (!_wasCooked(order.status)) return;
    if (order.restaurantCompensation > 0) return; // لا يتكرر
    try {
      // من مستند الإعدادات نفسه الذي يضبطه المدير من لوحته (لا من `config`
      // الذي لا واجهة له) — فيبقى الرقم بيده لا في الكود (بند ج١).
      final pct = (await getIncentiveSettings())
          .restaurantCancelCompensationPercent;
      if (pct <= 0) return;
      final amount = order.itemsTotal * (pct / 100);
      if (amount <= 0) return;
      await _orders.doc(order.id).update({
        'restaurantCompensation': amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // فشل التعويض لا يُبطل الإلغاء — يُصحَّح بقيد تسوية من الدفتر.
    }
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
    await _releaseOrderDriver(order);
    await _releaseCouponOnCancel(order);
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

  /// الحدّ الأدنى لإصدار التطبيق — يضبطه المدير فتُحجب النسخ الأقدم.
  ///
  /// يُقرأ من `delivery_settings/app`، وقراءته **مفتوحة للجميع بلا تسجيل
  /// دخول** في القواعد: تطبيق العميل يسمح بالتصفّح كزائر، ولو اشترطنا
  /// التسجيل لفشلت القراءة عند الزائر فانفتحت البوابة أمامه — بوابةٌ
  /// تُبنى وتبدو سليمة ولا تحجب أحداً.
  ///
  /// عند أي خطأ يُعاد نصٌّ فارغ = لا حجب. الفشل مفتوح عمداً: خللٌ في
  /// الشبكة أو القواعد يجب ألا يُعطّل التطبيق على كل مستخدميه.
  Stream<String> streamMinAppVersion() => _deliverySettings
      .doc('app')
      .snapshots()
      .map((d) => (d.data()?['minAppVersion'] as String?)?.trim() ?? '')
      .handleError((_) {})
      .cast<String>();

  Future<void> setMinAppVersion(String version) async {
    await _deliverySettings
        .doc('app')
        .set({'minAppVersion': version.trim()}, SetOptions(merge: true));
    logAdminAction('settings.save',
        'الحد الأدنى لإصدار التطبيق: ${version.trim().isEmpty ? 'بلا حد' : version.trim()}');
  }

  // ═══════════════════════════════════════════════════════════════════
  // طلبات انضمام الكباتن — تصل من صفحة التسجيل على الويب
  // ═══════════════════════════════════════════════════════════════════

  /// طلبات الانضمام مرتّبةً: المعلّقة أولاً ثم الأحدث. الترتيب في الذاكرة
  /// لا في الاستعلام حتى لا يلزم فهرس مركّب لمجموعة صغيرة كهذه.
  Stream<List<models.DriverApplication>> streamDriverApplications() =>
      _driverApplications.snapshots().map((s) {
        final list = s.docs
            .map((d) => models.DriverApplication.fromMap(d.data(), d.id))
            .toList();
        list.sort((a, b) {
          final ap = a.status == models.DriverApplicationStatus.pending;
          final bp = b.status == models.DriverApplicationStatus.pending;
          if (ap != bp) return ap ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        });
        return list;
      });

  /// قبول طلب انضمام: يولّد كود تسجيل للسائق محمّلاً بكود الداعي، ثم يختم
  /// الطلب بالكود الصادر. الكود يُولَّد أولاً — لو فشل الختم بقي الكود
  /// صالحاً ويراه المدير في شاشة الأكواد، بينما ختمٌ بلا كود يترك المتقدّم
  /// «مقبولاً» بلا وسيلة تسجيل.
  Future<models.RegistrationCode> approveDriverApplication({
    required models.DriverApplication application,
    Duration? validity,
  }) async {
    final entry = await generateRegistrationCode(
      role: models.UserRole.driver,
      validity: validity,
      referredByCode: application.referredByCode,
    );
    await _driverApplications.doc(application.id).update({
      'status': models.DriverApplicationStatus.approved.name,
      'issuedCode': entry.code,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    logAdminAction('application.approve',
        'قبول طلب انضمام ${application.name} وإصدار كود ${entry.code}',
        extra: {'applicationId': application.id});
    return entry;
  }

  Future<void> rejectDriverApplication({
    required String applicationId,
    required String note,
  }) =>
      _driverApplications.doc(applicationId).update({
        'status': models.DriverApplicationStatus.rejected.name,
        'reviewNote': note,
        'reviewedAt': FieldValue.serverTimestamp(),
      }).then((_) {
        logAdminAction('application.reject', 'رفض طلب انضمام',
            extra: {'applicationId': applicationId});
      });

  Future<void> deleteDriverApplication(String applicationId) async {
    await _driverApplications.doc(applicationId).delete();
    logAdminAction('application.delete', 'حذف طلب انضمام',
        extra: {'applicationId': applicationId});
  }

  /// صورة مستند متقدّم من مجموعة `driver_application_docs` — قيمة الحقل
  /// في الطلب معرّفُ مستندٍ هنا (نمط الويب: الصور Blob في Firestore لأن
  /// zadgo.co على GitHub Pages بلا خادم رفع؛ وعند Blaze تصير روابط
  /// Storage والتطبيق يفرّق بـstartsWith('http') بلا تغيير بنية).
  Future<Uint8List?> fetchApplicationDocImage(String docId) async {
    final doc =
        await _db.collection('driver_application_docs').doc(docId).get();
    final img = doc.data()?['image'];
    return img is Blob ? img.bytes : null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // الحوافز: الإحالة وتحدي نهاية الأسبوع
  // ═══════════════════════════════════════════════════════════════════

  /// إعدادات الحوافز — مستند واحد يضبط كل المبالغ والشروط من لوحة المدير.
  /// المستند غير الموجود يعطي الافتراضيات المعتمدة، فالنظام يعمل من أول
  /// تشغيل بلا إعداد مسبق.
  Stream<models.IncentiveSettings> streamIncentiveSettings() =>
      _deliverySettings.doc('incentives').snapshots().map(
          (d) => models.IncentiveSettings.fromMap(d.data() ?? const {}));

  Future<models.IncentiveSettings> getIncentiveSettings() async {
    final doc = await _deliverySettings.doc('incentives').get();
    return models.IncentiveSettings.fromMap(doc.data() ?? const {});
  }

  Future<void> saveIncentiveSettings(models.IncentiveSettings s) async {
    await _deliverySettings.doc('incentives').set(s.toMap());
    logAdminAction('settings.save', 'حفظ إعدادات الحوافز');
  }

  /// صرف مكافأة إحالة: حركتان في دفتر كل طرف + ختم السائق المُحال بأنها
  /// صُرفت. الختم يسبق الحركتين منطقياً لكنه يُكتب بعدهما عمداً — لو فشل
  /// الختم بقيت الحركتان موثّقتين وظهرت الإحالة مستحقّة مجدداً (تكرار
  /// ظاهر يصلحه المدير)، بينما ختمٌ بلا صرف يُضيع المكافأة صامتاً.
  Future<void> payReferralBonus({
    required models.Driver referrer,
    required models.Driver referee,
    required double referrerAmount,
    required double refereeAmount,
  }) async {
    // الحارس الذرّي: قراءة ختم referralRewarded وكتابته في معاملة واحدة —
    // النسخة السابقة كانت تصفّي على لقطة البثّ في الذاكرة ثم تختم **بعد**
    // الصرف، فجهازا مدير بالتوازي (أو المسح التلقائي معهما) يصرفان
    // المكافأتين مرتين، وفشل جزئي بين الكتابات كان يترك صرفاً بلا ختم
    // يتكرر مع كل مسح تالٍ.
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_drivers.doc(referee.id));
      if (snap.data()?['referralRewarded'] as bool? ?? false) {
        throw Exception('صُرفت مكافأة هذه الإحالة مسبقاً');
      }
      tx.update(_drivers.doc(referee.id), {'referralRewarded': true});
    });
    // الختم قبل الصرف عمداً — نفس عقيدة payChallengeBonus: ختمٌ بلا صرف
    // يُكتشف ويُصلَح يدوياً، أما صرفٌ بلا ختم فيتكرر صامتاً.
    if (referrerAmount > 0) {
      await recordDriverBonus(
        driverId: referrer.id,
        amount: referrerAmount,
        note: 'مكافأة إحالة — ${referee.name}',
      );
    }
    if (refereeAmount > 0) {
      await recordDriverBonus(
        driverId: referee.id,
        amount: refereeAmount,
        note: 'مكافأة ترحيب — دعوة ${referrer.name}',
      );
    }
  }

  /// صرف مكافأة تحدٍّ — مرة واحدة لكل سائق في كل نافذة.
  ///
  /// الحارس يُقرأ من القاعدة لا من النسخة المعروضة على الشاشة: الصرف
  /// التلقائي قد يعمل من جهازين، والشاشة قد تكون فُتحت قبل صرف مدير آخر.
  /// ويُختم المستند قبل كتابة الحركة عمداً — ختمٌ بلا صرف يُكتشف ويُصلَح
  /// يدوياً، أما صرفٌ بلا ختم فيتكرر مع كل تحديث.
  Future<void> payChallengeBonus({
    required String driverId,
    required double amount,
    required int deliveries,
    required DateTime windowStart,
  }) async {
    final key = models.IncentiveSettings.windowKey(windowStart);
    final snap = await _drivers.doc(driverId).get();
    final current = snap.data()?['lastChallengeWindow'] as String? ?? '';
    if (current == key) {
      throw Exception('صُرفت مكافأة هذه النافذة لهذا السائق مسبقاً');
    }
    await _drivers.doc(driverId).update({'lastChallengeWindow': key});
    await recordDriverBonus(
      driverId: driverId,
      amount: amount,
      note: 'تحدي ${windowStart.day}/${windowStart.month} — '
          '$deliveries توصيلة',
    );
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
      }).then((_) {
        logAdminAction('complaint.status', 'تغيير حالة شكوى إلى ${status.label}',
            extra: {'complaintId': complaintId});
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
    String? resolution,
    bool chargeRestaurant = false,
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

      // الخصم على المطعم (سياسة المالك 2026-08-13): شكوى الجودة المقبولة
      // يتحمّل المطعمُ استردادَها لا المنصّة. يُختم على الطلب فيطرحه
      // الدفتران (المطعم والإدارة) من المستحق. مسقوف بصافي المطعم من
      // الطلب: لا يُحمَّل من طلبٍ واحد أكثرَ مما كسب منه.
      if (chargeRestaurant) {
        final cap = (order.restaurantNet - order.restaurantChargeback)
            .clamp(0.0, double.infinity);
        final charge = refundAmount.clamp(0.0, cap);
        if (charge > 0) {
          await _orders.doc(order.id).update({
            'restaurantChargeback':
                order.restaurantChargeback + charge,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

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
        'استرداد ${refundPercentage.toStringAsFixed(0)}%'
            '${chargeRestaurant ? " على حساب المطعم" : ""}',
      if (warnAgainstParty) 'تسجيل إنذار',
      if (reassignToDriverId != null) 'نقل الطلب لسائق آخر',
    ].join(' + ');

    // الردّ الذي يقرؤه الشاكي (نفذ ٢): كلمة المدير أولاً إن كتبها، ثم
    // ملخّص الإجراءات — فلا يرى «تم الحل بلا إجراء إضافي» إلا إذا صمت
    // المدير ولم يُتَّخذ أي إجراء فعلاً.
    final reply = [
      if (resolution != null && resolution.isNotEmpty) resolution,
      if (actionsSummary.isNotEmpty) actionsSummary,
    ].join(' — ');
    await _complaints.doc(complaint.id).update({
      'status': models.ComplaintStatus.resolved.name,
      'resolution': reply.isEmpty ? 'تم الحل بلا إجراء إضافي' : reply,
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

  Future<void> sendBroadcast(models.BroadcastMessage message) async {
    await _broadcasts.doc(message.id).set(message.toMap());
    logAdminAction('broadcast.send', 'رسالة جماعية: ${message.title}');
  }
}