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
  CollectionReference<Map<String, dynamic>> get _adminSecrets =>
      _db.collection('admin_secrets');
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

  /// إلغاء صلاحية حسابٍ بتحويل دوره (المدير وحده، تحرسه القاعدة): الوصول
  /// الحقيقي مبنيٌّ على حقل `role` (hasRole في القواعد)، فتحويله إلى
  /// `customer` يسحب صلاحية الدعم/المشغّل/مدير المطعم فوراً على الخادم —
  /// بخلاف «تعطيل» (isActive) وهو علمٌ ناعم لا تفحصه القواعد.
  /// **ملاحظة**: صفة «المدير العام» ادّعاءٌ موقّع لا حقل دور، فتُسحب من ورشة
  /// Admin claim (revoke) لا من هنا.
  Future<void> setUserRole(String uid, models.UserRole role) =>
      _users.doc(uid).update({'role': role.name});

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

  CollectionReference<Map<String, dynamic>> get _suggestions =>
      _db.collection('suggestions');

  /// اقتراح/نصيحة عامة (2026-08-20): يكتبها الزائر بلا تسجيل — النصّ
  /// إلزامي والاسم والهاتف اختياريان. القاعدة تحرس الحقول والأحجام،
  /// والقراءة للمدير حصراً. لا أعلام auth: بابٌ عام مقصود.
  // صندوق التطبيق و«قل لنا» في الموقع يكتبان مجموعة `suggestions` نفسها،
  // فتُوحَّد القاعدة (دمج 2026-08-20): نكتب `uid` و`status:'new'` كما تشترط
  // القاعدة الموحّدة كي يمرّ الصندوقان منها إلى صندوق واردٍ واحدٍ للمدير.
  // الحدّ الأدنى ٥ أحرف والاسم ≤٦٠ مطابقةً للقاعدة (كان ٣ و١٠٠).
  Future<void> submitSuggestion(String text,
      {String? name, String? phone}) async {
    final t = text.trim();
    if (t.length < 5) throw Exception('اكتب اقتراحك (٥ أحرف على الأقل)');
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('تعذّر الإرسال — أعد فتح التطبيق');
    final n = (name ?? '').trim();
    final p = (phone ?? '').trim();
    await _suggestions.add({
      'text': t.length > 2000 ? t.substring(0, 2000) : t,
      if (n.isNotEmpty) 'name': n.length > 60 ? n.substring(0, 60) : n,
      if (p.isNotEmpty) 'phone': p.length > 30 ? p.substring(0, 30) : p,
      'uid': uid,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// أحدث ٢٠٠ اقتراح للمدير (ترتيب خادمي — createdAt وحده، لا فهرس مركّب).
  Stream<List<models.Suggestion>> streamSuggestions() => _suggestions
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs
          .map((d) => models.Suggestion.fromMap(d.data(), d.id))
          .toList());

  Future<void> deleteSuggestion(String id) => _suggestions.doc(id).delete();

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
          // سقف ٢٠٠ حركة (نواقص لا-Blaze 2026-08-20): كان بلا حدّ فينزل
          // كل التاريخ في كل فتح. الترتيب صار خادمياً (لا محلياً) ليأخذ
          // الحدّ **الأحدث** فعلاً لا عيّنةً عشوائية — والفهرس المركّب
          // (userId+createdAt) يُنشر آلياً عبر deploy-firestore. الرصيد
          // حقلٌ مخزَّن لا يُحسب من المعروض، فالقصّ لا يكذب رقماً.
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots()
          .map((s) => s.docs
              .map((d) => models.WalletTransaction.fromMap(d.data(), d.id))
              .toList());

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

  /// سجلّ التدقيق الإداري للعرض (نواقص لا-Blaze 2026-08-20): كان يُكتب
  /// من الجوّال والويب (٣١+١٤ موضعاً) ولا شاشة تقرؤه — سجلٌّ لا يُرى لا
  /// يردع. أحدث ٢٠٠ قيد بترتيب خادمي (createdAt وحده — لا فهرس مركّب).
  /// يُعاد كـmap خام: القيود متغايرة الحقول (لكل فعلٍ extra مختلف) فلا
  /// نموذج يسعها، والشاشة تقرأ ما تعرفه وتتجاهل الباقي.
  Stream<List<Map<String, dynamic>>> streamAdminAudit() => _db
      .collection('admin_audit')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

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
    // مجموعة لا دوراً واحداً: نكهة الإدارة تقبل كودَي «مدير عام»
    // و«موظف دعم» معاً — المساواة الصارمة كانت سترفض كود الدعم فيها.
    Set<models.UserRole>? allowedRoles,
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
    if (allowedRoles != null && !allowedRoles.contains(initial.role)) {
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
        if (allowedRoles != null && !allowedRoles.contains(current.role)) {
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

  // أُزيلت updateDriverRating/updateRestaurantRating المنفصلتان: كانتا
  // تكتبان العدّاد مباشرةً بلا ربطٍ بطلب، وهو ما فتح ثغرة §٠. الحساب
  // انتقل داخل [rateOrder] في دفعةٍ ذرّية تُنشئ علامة الطلب وتزيد العدّاد
  // معاً — والقواعد ترفض أي زيادةٍ بلا علامة، فلا يعمل المسار المباشر أصلاً.

  Future<String> placeOrder(models.Order order) async {
    // دفعة ٠-ب: الإنشاء وختمُ استهلاك الدفعة وتقييدُ الكوبون في **دفعة ذرّية
    // واحدة** — لم يعد التقييد لاحقاً «غير حرج»، بل تشترطه القاعدة في نفس
    // اللحظة (existsAfter): الخصم لا يُقبل بلا علامة استخدامٍ تُنشأ معه، ودفعة
    // البطاقة لا تُقبل بلا ختم استهلاكٍ يمنع إعادة استخدامها. فإمّا أن يقع
    // الكل أو لا يقع الطلب — لا خصمٌ بلا تقييد ولا دفعةٌ قابلة لإعادة الاستخدام.
    final batch = _db.batch();
    batch.set(_orders.doc(order.id), {
      ...order.toMap(),
      if (order.statusChangedAt == null)
        'statusChangedAt': FieldValue.serverTimestamp(),
    });
    _stampPaymentConsumption(batch, order);
    _stampCouponUse(batch, order);
    await batch.commit();
    // إشعار فوري لمديري المطعم بالطلب الجديد عبر الخادم المرافق — بدونه لا
    // يعلم المطعم بالطلب إلا حين يكون تطبيقه مفتوحاً على الشاشة.
    NotifyRelay.orderEvent(order.id, OrderEvent.created);
    return order.id;
  }

  /// ختم استهلاك دفعة البطاقة داخل دفعة الطلب (C3): مستند بمعرّف الدفعة
  /// يُنشأ مرة واحدة — القاعدة تشترط وجوده (existsAfter) وتمنع إعادة إنشائه،
  /// فلا تُستخدم دفعةٌ واحدة لطلبات كثيرة. للطلبات المدفوعة بالبطاقة فقط.
  void _stampPaymentConsumption(WriteBatch batch, models.Order order) {
    final pid = order.paymentId;
    if (pid == null || pid.isEmpty) return;
    batch.set(_paymentConsumptions.doc(pid), {
      'uid': order.customerId,
      'orderId': order.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// تقييد استهلاك الكوبون داخل دفعة الطلب (H6): عدّاد كلّي + عدّاد لكل مستخدم
  /// يُكتبان ذرّياً مع الطلب — القاعدة تربط الخصم بوجودهما فلا خصمَ بلا تقييد.
  void _stampCouponUse(WriteBatch batch, models.Order order) {
    final code = order.couponCode;
    if (code == null || code.isEmpty || order.discountAmount <= 0) return;
    batch.update(_coupons.doc(code), {'usedCount': FieldValue.increment(1)});
    batch.set(
      _couponUsages.doc(_usageId(code, order.customerId)),
      {
        'code': code,
        'userId': order.customerId,
        'count': FieldValue.increment(1),
        'lastOrderId': order.id,
        'lastUsedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// إنشاء الطلب وخصم المحفظة في **معاملة ذرّية واحدة**.
  ///
  /// كان الخصم (`spendFromWallet`) والإنشاء (`placeOrder`) نداءين منفصلين:
  /// لو نجح الخصم ثم فشل الإنشاء (شبكة/صلاحية) خسر العميل رصيده على طلبٍ لا
  /// وجود له — **ولا يستطيع ردّه بنفسه** لأن القواعد تمنع العميل من زيادة
  /// رصيده (وهو الصحيح: الزيادة استرداد إداري لا شحن ذاتي). الجمع في معاملة
  /// واحدة يجعل الخصم والإنشاء يقعان معاً أو لا يقع أيٌّ منهما — فلا رصيدَ
  /// يُخصم بلا طلب. بلا محفظة، يمرّ الطلب عبر المسار العادي بلا معاملة.
  Future<String> placeOrderWithWallet(
      models.Order order, double walletAmount) async {
    if (walletAmount <= 0) return placeOrder(order);

    final userRef = _users.doc(order.customerId);
    final walletTxRef = _walletTransactions.doc();
    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(userRef);
      final data = snap.data();
      if (!snap.exists || data == null) {
        throw Exception('حساب العميل غير موجود');
      }
      final current = (data['walletBalance'] as num?)?.toDouble() ?? 0;
      if (current + 0.001 < walletAmount) {
        throw Exception('رصيد المحفظة غير كافٍ');
      }
      transaction.update(userRef, {'walletBalance': current - walletAmount});
      transaction.set(
        walletTxRef,
        models.WalletTransaction(
          id: walletTxRef.id,
          userId: order.customerId,
          type: models.WalletTransactionType.orderPayment,
          amount: -walletAmount,
          balanceAfter: current - walletAmount,
          orderId: order.id,
          orderNumber: order.orderNumber,
          createdAt: DateTime.now(),
        ).toMap(),
      );
      transaction.set(_orders.doc(order.id), {
        ...order.toMap(),
        if (order.statusChangedAt == null)
          'statusChangedAt': FieldValue.serverTimestamp(),
      });
      // ختم الدفعة وتقييد الكوبون داخل نفس المعاملة (C3/H6) — كتاباتٌ بلا
      // قراءات إضافية فلا تخرق قاعدة «القراءات قبل الكتابات». تشترطهما
      // القاعدة ذرّياً مع إنشاء الطلب.
      final pid = order.paymentId;
      if (pid != null && pid.isNotEmpty) {
        transaction.set(_paymentConsumptions.doc(pid), {
          'uid': order.customerId,
          'orderId': order.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      final code = order.couponCode;
      if (code != null && code.isNotEmpty && order.discountAmount > 0) {
        transaction.update(
            _coupons.doc(code), {'usedCount': FieldValue.increment(1)});
        transaction.set(
          _couponUsages.doc(_usageId(code, order.customerId)),
          {
            'code': code,
            'userId': order.customerId,
            'count': FieldValue.increment(1),
            'lastOrderId': order.id,
            'lastUsedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    });

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

  /// طلبات نطاق زمني **كاملةً** — بلا سقف الـ٥٠٠. البديل الصادق للشاشات
  /// المالية: نافذة «أحدث ٥٠٠» تقصّ التقرير بصمت فتكذب عناوين «منذ
  /// البداية»، بينما مدى التاريخ يحدّ الحجم بطبيعته (فترة قصيرة = طلبات
  /// قليلة). مدى + ترتيب على الحقل نفسه فلا فهرس مركّباً جديداً.
  Stream<List<models.Order>> streamOrdersSince(DateTime since) => _orders
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => models.Order.fromMap(d.data(), d.id)).toList());

  /// العدد الحقيقي لكل الطلبات منذ إنشاء المنصة — استعلام تجميع خادمي
  /// (لا تنزيل مستندات)، به تعرف شاشة «الكل» إن كانت نافذتها مقصوصة
  /// فتصارح المدير بدل عنوانٍ يدّعي الكمال.
  Future<int> countAllOrders() async {
    final snap = await _orders.count().get();
    return snap.count ?? 0;
  }

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

  /// أسماء الحالات المعروضة في المتابعة الحية (النشطة + `noDriverFound`
  /// الذي يُعرض للتدخّل اليدوي). مشتقّة من `isActive` نفسها فلا تتباعد
  /// عنها لو أُضيفت حالة — عشرُ قيمٍ ضمن حدّ whereIn.
  static final List<String> _activeStatusNames = models.OrderStatus.values
      .where((s) =>
          s.isActive || s == models.OrderStatus.noDriverFound)
      .map((s) => s.name)
      .toList();

  /// الطلبات النشطة (نواقص لا-Blaze 2026-08-20): كان يُنزِّل أحدث ٣٠٠
  /// طلبٍ **كاملةً** ثم يصفّي النشط محلياً — فمعظم المنقول مكتملٌ لا
  /// يُعرض، وعند تجاوز الأرشيف ٣٠٠ نشطاً قد يسقط طلبٌ جارٍ من المتابعة.
  /// الآن `whereIn` على الحالة يجلب النشط وحده (فهرس status+createdAt
  /// يُنشر آلياً)، وسقفُ ٥٠٠ حدُّ أمانٍ بعيدٌ لا يُبلَغ عملياً.
  Stream<List<models.Order>> streamActiveOrders() => _orders
      .where('status', whereIn: _activeStatusNames)
      .orderBy('createdAt', descending: true)
      .limit(500)
      .snapshots()
      .map((s) => s.docs
          .map((d) => models.Order.fromMap(d.data(), d.id))
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
      // رفض المطعم إنهاءٌ للطلب بلا خدمة فيُعاد ما خُصم من المحفظة —
      // لكن **ليس من هذا الجهاز**: هذه الدالة تعمل على جهاز المطعم،
      // والقواعد تمنعه — بحق — من زيادة رصيد عميل، فكان نداء الاسترداد
      // المباشر هنا يُرفض ويضيع الرصيد بصمت (فحص السلوك 2026-08-20 —
      // نفس داء الإلغاء الذاتي الذي عولج 2026-08-15 ولم يُنقل علاجه).
      // الختم walletRefundPending يُظهره في بطاقة «ردود محفظة معلّقة»
      // برئيسة الإدارة فيصرفه المدير بضغطة.
      if (current.walletUsed > 0) 'walletRefundPending': true,
    });

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
    // معاملة ذرّية (دفعة ١، عطل السباق ٣): كان الفحص قراءةً منفصلة ثم batch،
    // فضغطتان متزامنتان (بطاقة السائق + شاشة الخريطة تستدعيان الاستلام) تقرآن
    // «جاهز للاستلام» قبل ثبوت أولاهما فتمرّان معاً — قيدُ عُهدةٍ **مرّتين**
    // على الكابتن. الآن القراءة والفحص والقيد في معاملة واحدة: الثانية تقرأ
    // «في الطريق» داخل معاملتها فتخرج بلا أثر (حصانة تكرار)، وقراءة رصيد
    // السائق داخل المعاملة قبل أي كتابة (شرط فايرستور: القراءات قبل الكتابات).
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists || snap.data() == null) {
        throw Exception('الطلب غير موجود');
      }
      final current = models.Order.fromMap(snap.data()!, snap.id);
      // حصانة التكرار: استُلم فعلاً (في الطريق أو أبعد) أو أُنهي — لا قيد ثانٍ.
      if (current.status == models.OrderStatus.onTheWay ||
          current.status == models.OrderStatus.delivered ||
          current.status == models.OrderStatus.cancelled ||
          current.status == models.OrderStatus.refunded) {
        return;
      }
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

      // قراءة رصيد السائق داخل المعاملة (قبل الكتابة) لحساب balanceAfter.
      double balance = 0;
      if (needsCustody && current.custodyAmount != 0) {
        final driverSnap = await tx.get(_drivers.doc(driverId));
        balance = driverSnap.exists && driverSnap.data() != null
            ? models.Driver.fromMap(driverSnap.data()!, driverSnap.id).balance
            : 0.0;
      }

      tx.update(ref, {
        'status': models.OrderStatus.onTheWay.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusChangedAt': FieldValue.serverTimestamp(),
        if (needsCustody) 'custodyDebited': true,
      });

      // عُهدة صفرية (محفظة العميل غطّت حصّتَي المطعم والمنصّة بالضبط) لا
      // تستحق قيداً — يبقى custodyDebited=true فلا يُعاد القيد عند التسليم.
      if (needsCustody && current.custodyAmount != 0) {
        final custody = current.custodyAmount;
        final txRef = _driverTransactions.doc();
        tx.update(_drivers.doc(driverId), {
          'balance': FieldValue.increment(-custody),
          // دفعة ٠-ب (C1/H2): مؤشّر لحركة الدفتر المرافقة في نفس المعاملة —
          // القاعدة ترفض أي تغيير رصيد بلا حركةٍ مطابقةٍ يشير إليها هذا الحقل.
          'lastLedgerTxId': txRef.id,
        });
        tx.set(
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
    });
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

  // ── مشغّل الأسطول (دفعة «ابدأ المشغل») ─────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _fleetOperators =>
      _db.collection('fleet_operators');

  /// كل المشغّلين — للمدير (إدارة وإسناد).
  Stream<List<models.FleetOperator>> streamFleetOperators() =>
      _fleetOperators.snapshots().map((s) => s.docs
          .map((d) => models.FleetOperator.fromMap(d.data(), d.id))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name)));

  /// ملف مشغّلٍ بعينه — يقرؤه المشغّل نفسه (شاشته) والمدير.
  Stream<models.FleetOperator?> streamFleetOperator(String id) =>
      _fleetOperators.doc(id).snapshots().map((d) =>
          d.exists ? models.FleetOperator.fromMap(d.data()!, d.id) : null);

  /// المدير يُنشئ/يحدّث ملف المشغّل بمعرّف حسابه (الرصيد يبدأ صفراً).
  Future<void> saveFleetOperator(models.FleetOperator op) =>
      _fleetOperators.doc(op.id).set(op.toMap(), SetOptions(merge: true));

  /// المدير يضبط نسبة المشغّل ورسمه الشهري (لا رقم مبرمَج — بند ج١).
  Future<void> setOperatorRates(String id,
          {required double driverSharePerDelivery,
          required double monthlyFee}) =>
      _fleetOperators.doc(id).set({
        'driverSharePerDelivery': driverSharePerDelivery,
        'monthlyFee': monthlyFee,
      }, SetOptions(merge: true));

  /// المدير يسند كابتناً لمشغّل (أو يفكّه بتمرير operatorId فارغ)، وينسخ
  /// حصّة الكابتن الافتراضية من نسبة المشغّل. محميّ في القواعد للمدير وحده.
  Future<void> assignDriverOperator(String driverId,
          {required String operatorId, required double operatorDriverShare}) =>
      _drivers.doc(driverId).update({
        'operatorId': operatorId,
        'operatorDriverShare': operatorDriverShare,
      });

  /// كباتن مشغّلٍ بعينه — لشاشته وللمدير. الترتيب محلياً فلا فهرس مركّب.
  Stream<List<models.Driver>> streamOperatorDrivers(String operatorId) =>
      _drivers
          .where('operatorId', isEqualTo: operatorId)
          .snapshots()
          .map((s) => s.docs
              .map((d) => models.Driver.fromMap(d.data(), d.id))
              .toList()
            ..sort((a, b) => b.totalDeliveries.compareTo(a.totalDeliveries)));

  /// طلبات مشغّلٍ المسلَّمة — لجمع مستحقّاته (مجموع operatorShare). محدود
  /// بأحدث ٢٠٠ كنظائره في الدفتر، والجمع محلياً فلا فهرس مركّب.
  Stream<List<models.Order>> streamOperatorOrders(String operatorId) =>
      _orders
          .where('operatorId', isEqualTo: operatorId)
          .limit(400)
          .snapshots()
          .map((s) =>
              s.docs.map((d) => models.Order.fromMap(d.data(), d.id)).toList());

  /// المدير يسجّل دفعةً للمشغّل: تُنقص من رصيده (كتسوية دفتر الكابتن).
  Future<void> recordOperatorPayout(String operatorId, double amount) =>
      _fleetOperators
          .doc(operatorId)
          .set({'balance': FieldValue.increment(-amount.abs())},
              SetOptions(merge: true));

  /// إظهار/إخفاء البنر الافتراضي المدمج (دفعة «الإعلانات الذكية»): يُخزَّن في
  /// `delivery_settings/banners` (قراءةٌ عامة كي يراه الزائر). الافتراضي
  /// true — فالسلوك القديم يبقى حتى يطفئه المدير من لوحته.
  Stream<bool> streamShowDefaultBanner() => _deliverySettings
      .doc('banners')
      .snapshots()
      .map((d) => (d.data()?['showDefault'] as bool?) ?? true);

  Future<void> setShowDefaultBanner(bool show) => _deliverySettings
      .doc('banners')
      .set({'showDefault': show}, SetOptions(merge: true));

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
    // الإسناد النهائي في معاملة ذرّية (دفعة ١، عطل السباق ١): كان batch يقرأ
    // المرشَّح متاحاً (قراءةٌ سابقة على المعاملة) ثم يُسنده، فطلبان يُسنَدان
    // متزامنين يقرآن نفس السائق متاحاً فيُسنَد لكليهما (خرق سقف الحمولة). الآن
    // نعيد قراءة مرشَّحي المجموعة (مرتَّبين سلفاً) **داخل المعاملة** ونُسند أوّل
    // من يبقى متاحاً فعلاً؛ وطلبٌ أُسنِد من مسارٍ آخر لا يُدهَس (driverId موجود).
    final assignedId = await _db.runTransaction<String?>((tx) async {
      final orderSnap = await tx.get(_orders.doc(order.id));
      if (!orderSnap.exists || orderSnap.data() == null) return null;
      final existing = (orderSnap.data()!['driverId'] as String?) ?? '';
      if (existing.isNotEmpty) return null; // أُسنِد بالفعل — لا ازدواج
      models.Driver? pick;
      for (final cand in pool) {
        final ds = await tx.get(_drivers.doc(cand.id));
        if (ds.exists &&
            ds.data() != null &&
            (ds.data()!['isAvailable'] as bool? ?? false)) {
          pick = models.Driver.fromMap(ds.data()!, ds.id);
          break;
        }
      }
      if (pick == null) return null; // سُبِق كل المرشَّحين — يُعاد لاحقاً
      tx.update(_orders.doc(order.id), {
        'driverId': pick.id,
        'driverName': pick.name,
        'driverPhone': pick.phone,
        'updatedAt': FieldValue.serverTimestamp(),
        // عرض حقيقي لا إسناد صامت: كان يُكتب true هنا فيتجاوز المسارُ الأكثر
        // شيوعاً (الإسناد التلقائي) موافقةَ السائق كلياً. الآن يظهر له عرض
        // بالأجرة والمسافتين وعدّاد، وانقضاء المهلة أو الرفض يمرّران الطلب لغيره.
        'driverAcknowledged': false,
      });
      tx.update(_drivers.doc(pick.id), {'isAvailable': false});
      return pick.id;
    });
    if (assignedId == null) return false;
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
      // كل الطلبات النشطة لا «آخر ٣٠٠» (دفعة ١، عطل السباق ٦): النافذة ذات
      // الحدّ الثابت تُسقط طلباً نشطاً أقدم منها في يومٍ مزدحم، فيُحرَّر سائقٌ
      // مشغولٌ فعلاً ويتلقّى عرضاً وهو يوصّل (خرق سقف الحمولة). الحالات النشطة
      // تسعٌ (≤10) فتصلح لاستعلام whereIn المفهرَس تلقائياً بلا فهرس مركّب.
      final activeStatuses = models.OrderStatus.values
          .where((s) => s.isActive)
          .map((s) => s.name)
          .toList();
      final snap =
          await _orders.where('status', whereIn: activeStatuses).get();
      for (final doc in snap.docs) {
        final o = models.Order.fromMap(doc.data(), doc.id);
        final id = o.driverId ?? '';
        if (id.isNotEmpty) busy.add(id);
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

  /// بثّ مستند مطعم واحد — يحتاجه شريط تطبيق المطعم لعرض حالة الإيقاف
  /// المؤقت حيّةً (زر يتلوّن ويحمل موعد الاستئناف).
  Stream<models.Restaurant?> streamRestaurant(String restaurantId) =>
      _restaurants.doc(restaurantId).snapshots().map((d) =>
          d.exists && d.data() != null
              ? models.Restaurant.fromMap(d.data()!, d.id)
              : null);

  /// إيقاف الاستقبال مؤقتاً / استئنافه — بيد مدير المطعم من تطبيقه
  /// (يوم المطعم 2026-08-20). الاستئناف تلقائي بانقضاء الموعد: لا كتابة
  /// ثانية تُنسى، وnull يعني «استأنف الآن».
  Future<void> setRestaurantPaused(String restaurantId, DateTime? until) =>
      _restaurants.doc(restaurantId).update({
        'pausedUntil': until == null ? null : Timestamp.fromDate(until),
      });

  /// قبول المطعم للطلب **مع وقت تحضيره** بكتابة واحدة — نفس حارس
  /// الانتقال في [updateOrderStatus]، والدقائق اختيارية (null = قبول
  /// بلا تقدير، كما كان).
  Future<void> acceptOrderWithPrep(String orderId, int? prepMinutes) async {
    final ref = _orders.doc(orderId);
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) throw Exception('الطلب غير موجود');
    final current = models.Order.fromMap(doc.data()!, doc.id);
    if (!_isValidStatusTransition(
        current.status, models.OrderStatus.restaurantAccepted)) {
      throw Exception(
          'انتقال حالة غير صالح: من ${current.status.name} إلى restaurantAccepted');
    }
    await ref.update({
      'status': models.OrderStatus.restaurantAccepted.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'statusChangedAt': FieldValue.serverTimestamp(),
      if (prepMinutes != null && prepMinutes > 0) 'prepMinutes': prepMinutes,
    });
    NotifyRelay.orderEvent(orderId, OrderEvent.status);
  }

  /// ردّ المطعم على تقييم عميل — مرة واحدة لكل تقييم (الحوار لا يفتح
  /// لمردودٍ عليه)، ويظهر للعميل تحت تقييمه في «طلباتي».
  Future<void> replyToOrderReview(String orderId, String reply) =>
      _orders.doc(orderId).update({
        'restaurantReply': reply.trim(),
        'restaurantRepliedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// «تعذّر التسليم» — مخرج الكابتن على باب عميلٍ يرفض الاستلام أو لا
  /// يردّ (درع النقد 2026-08-20). **علمٌ لا إغلاق**: الحالة لا تتغير،
  /// فالإغلاق المالي (إلغاء بعكس العُهدة، أو إعادة محاولة) قرارُ مديرٍ
  /// تُشعله البطاقة الحمراء في المتابعة الحية — ضغطةُ كابتنٍ لا تصفّي
  /// طلباً نقدياً بضاعتُه وعُهدته بيده.
  Future<void> markDeliveryFailed(models.Order order, String reason) async {
    await _orders.doc(order.id).update({
      'deliveryFailed': true,
      'undeliveredReason': reason,
      'undeliveredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    NotifyRelay.orderEvent(order.id, OrderEvent.status);
  }

  /// رفع/فرض حظر النقدي يدوياً — من تبويب المستخدمين (المدير حين يقتنع
  /// بعذر العميل يرفعه، والعدّاد يُصفَّر معه فلا يعود الحظر من أول كنسة).
  Future<void> setCashBlocked(String uid, bool blocked) async {
    await _users.doc(uid).update({
      'cashBlocked': blocked,
      if (!blocked) 'cashNoShowCount': 0,
    });
    logAdminAction('user.cashBlock',
        blocked ? 'حظر الدفع النقدي عن عميل' : 'رفع حظر النقدي عن عميل',
        extra: {'uid': uid});
  }

  /// كنس أعلام درع النقد — مع فتح المتابعة الحية (نمط «أقصى ما يمكن بلا
  /// خادم»): (١) **الترقية**: عميلٌ في نافذة الطلبات الأخيرة سُلِّم له
  /// طلبٌ وليس موثوقاً بعد → `cashTrusted` فيسقط عنه سقف أول طلب؛
  /// (٢) **الحظر**: عميلٌ ظهر له «تعذّر تسليم» نقدي بسبب رفض/غياب →
  /// يُعاد عدّ كامل تاريخه النقدي الفاشل بدقة (استعلام مباشر لا نافذة)،
  /// وإن بلغ حدَّ المدير (`cashNoShowLimit`، صفر يعطّل) حُظر النقدي عنه.
  Future<({int promoted, int blocked})> reconcileCashFlags() async {
    var promoted = 0, blocked = 0;
    try {
      final settings = await getIncentiveSettings();
      final snap = await _orders
          .orderBy('createdAt', descending: true)
          .limit(300)
          .get();
      final deliveredCustomers = <String>{};
      final failedCashCustomers = <String>{};
      for (final doc in snap.docs) {
        final o = models.Order.fromMap(doc.data(), doc.id);
        if (o.status == models.OrderStatus.delivered) {
          deliveredCustomers.add(o.customerId);
        }
        if (o.deliveryFailed &&
            o.paymentMethod == models.PaymentMethod.cash) {
          failedCashCustomers.add(o.customerId);
        }
      }
      for (final uid in deliveredCustomers) {
        try {
          final u = await _users.doc(uid).get();
          if (u.data()?['cashTrusted'] == true) continue;
          await _users.doc(uid).update({'cashTrusted': true});
          promoted++;
        } catch (_) {}
      }
      if (settings.cashNoShowLimit > 0) {
        for (final uid in failedCashCustomers) {
          try {
            final u = await _users.doc(uid).get();
            if (u.data()?['cashBlocked'] == true) continue;
            final fails = await _orders
                .where('customerId', isEqualTo: uid)
                .where('deliveryFailed', isEqualTo: true)
                .get();
            final cashFails = fails.docs
                .map((d) => models.Order.fromMap(d.data(), d.id))
                .where((o) => o.paymentMethod == models.PaymentMethod.cash)
                .length;
            await _users.doc(uid).update({'cashNoShowCount': cashFails});
            if (cashFails >= settings.cashNoShowLimit) {
              await _users.doc(uid).update({'cashBlocked': true});
              blocked++;
              logAdminAction('user.cashBlock',
                  'حظر النقدي تلقائياً: $cashFails رفض استلام (الحد ${settings.cashNoShowLimit})',
                  extra: {'uid': uid});
            }
          } catch (_) {}
        }
      }
    } catch (_) {
      // الكنس تحسين لا شرط.
    }
    return (promoted: promoted, blocked: blocked);
  }

  /// كنس الطلبات العالقة — يعمل من لوحة المتابعة لحظة فتحها (نمط «أقصى
  /// ما يمكن بلا خادم» نفسه الذي يعتمده صرف الحوافز والمصالحة).
  /// عطلان كشفهما فحص السلوك 2026-08-20 وكلاهما كان بلا أي مخرج:
  ///
  /// **١) العرض الميت**: عرضُ الإسناد التلقائي مهلته ٤٥ ثانية تعدّ على
  /// جهاز الكابتن وحده — فإن مات جهازه لحظتها بقي الطلب معلّقاً عليه
  /// للأبد (driverAcknowledged=false) والكابتن محجوزاً «غير متاح».
  /// هنا: كل عرضٍ مرّت عليه ٣ دقائق (المهلة + هامش أعطال سخيّ كي لا
  /// نسابق عدّاداً حياً) يُحرَّر كابتنُه ويُعاد ترشيح الطلب فوراً من
  /// هذا الجهاز. **قصداً لا يمسّ الإسناد اليدوي** (حالته driverAssigned
  /// — قد يكون المدير أسند كابتناً غير متصل عمداً بعد مهاتفته).
  ///
  /// **٢) الطلب المتجاهَل**: طلبٌ لم يردّ عليه المطعم أطول من ضعف مهلة
  /// التنبيه (restaurantResponseTimeoutMinutes×٢، وبحد أدنى ١٠ دقائق —
  /// الضعف يترك للتنبيه الأصفر فرصة معالجة يدوية قبل البتر) يُلغى
  /// بالمسار الإداري الكامل: استرداد المحفظة مباشرةً (هذا الجهاز مدير)،
  /// تحرير الكوبون والكابتن، وإشعار العميل — بدل انتظارٍ بلا نهاية
  /// يقتل ثقته من أول طلب.
  Future<({int reclaimedOffers, int cancelledIgnored})>
      reconcileStuckOrders() async {
    var reclaimed = 0, cancelled = 0;
    try {
      final now = DateTime.now();
      final cfg = await getDeliverySettings();
      final alertMin =
          (cfg['restaurantResponseTimeoutMinutes'] as num?)?.toInt() ?? 5;
      final cancelAfter = Duration(
          minutes: (alertMin * 2) < 10 ? 10 : (alertMin * 2));
      final snap = await _orders
          .orderBy('createdAt', descending: true)
          .limit(300)
          .get();
      for (final doc in snap.docs) {
        final o = models.Order.fromMap(doc.data(), doc.id);
        final age =
            now.difference(o.statusChangedAt ?? o.updatedAt ?? o.createdAt);
        final offerAge = now.difference(o.updatedAt ?? o.createdAt);

        if (o.status == models.OrderStatus.searchingDriver &&
            o.needsDriverAcknowledgement &&
            offerAge > const Duration(minutes: 3)) {
          try {
            final deadDriverId = o.driverId!;
            await _orders.doc(o.id).update({
              'driverId': null,
              'driverName': null,
              'driverPhone': null,
              'driverAcknowledged': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            await _drivers
                .doc(deadDriverId)
                .update({'isAvailable': true});
            reclaimed++;
            logAdminAction('order.reclaimOffer',
                'استرجاع عرض ميت للطلب #${o.orderNumber} وإعادة ترشيحه',
                extra: {'orderId': o.id});
            final fresh = await getOrderOnce(o.id);
            if (fresh != null) await autoAssignNearestDriver(fresh);
          } catch (_) {
            // فشل استرجاع طلبٍ لا يوقف كنس البقية.
          }
        } else if (o.status == models.OrderStatus.restaurantPending &&
            age > cancelAfter) {
          try {
            await cancelOrder(o.id);
            cancelled++;
            logAdminAction('order.autoCancelIgnored',
                'إلغاء تلقائي لطلب #${o.orderNumber} تجاهله المطعم '
                '${age.inMinutes} دقيقة',
                extra: {'orderId': o.id});
          } catch (_) {}
        }
      }
    } catch (_) {
      // الكنس تحسين لا شرط لعمل اللوحة.
    }
    return (reclaimedOffers: reclaimed, cancelledIgnored: cancelled);
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
    // كل شيء في **معاملة ذرّية واحدة** (مراجعة 2026-08-15): كان الفحص
    // قراءةً منفصلة ثم batch، فضغطتان متزامنتان من جهازين (بطاقة السائق +
    // إنهاء المدير) تقرآن الحالة قبل ثبوت أولاهما فتمرّان معاً — أجرة
    // وإكرامية مرّتين وعدّاد توصيلات +2. الآن القراءة والفحص والقيود في
    // معاملة واحدة: الثانية تقرأ delivered داخل معاملتها فتخرج بلا أثر.
    final txRef = _driverTransactions.doc();
    await _db.runTransaction((tx) async {
      final orderSnap = await tx.get(_orders.doc(orderId));
      if (!orderSnap.exists || orderSnap.data() == null) {
        throw Exception('الطلب غير موجود');
      }
      final order = models.Order.fromMap(orderSnap.data()!, orderSnap.id);
      // حصانة التكرار: طلبٌ سُلّم فعلاً يخرج بلا أثر. الفحص هنا لا في
      // `_isValidStatusTransition` (التي تمرّر from==to) كي لا نغيّر سلوك
      // بقية المستدعين.
      if (order.status == models.OrderStatus.delivered) return;
      if (!_isValidStatusTransition(
          order.status, models.OrderStatus.delivered)) {
        throw Exception(
            'انتقال حالة غير صالح: من ${order.status.name} إلى ${models.OrderStatus.delivered.name}');
      }
      // أثر التوصيل على رصيد السائق يعتمد على طريقة الدفع:
      //
      // • نقدي: قيمة الطلب قُيّدت عُهدةً لحظة الاستلام من المطعم
      //   (markPickedUpBySelf)، فلا قيد إضافياً هنا — القيد المزدوج كان
      //   سيُحمّل السائق الطلب مرّتين. الاستثناء: طلب استُلم بنسخة قديمة
      //   لا تعرف قيد العُهدة (custodyDebited=false)، فيُقيَّد هنا كالسابق.
      // • إلكتروني: التطبيق هو من قبض المبلغ، فتُقيَّد أجرة السائق لصالحه.
      //   والإكرامية (ح3) معها كاملةً بلا اقتطاع — نقديّها بيده أصلاً.
      final isCash = order.paymentMethod == models.PaymentMethod.cash;
      final delta = isCash
          ? (order.custodyDebited ? 0.0 : -order.custodyAmount)
          : order.driverShare + order.driverTip;

      final driverSnap = await tx.get(_drivers.doc(driverId));
      final driverModel = driverSnap.exists && driverSnap.data() != null
          ? models.Driver.fromMap(driverSnap.data()!, driverSnap.id)
          : null;
      final currentBalance = driverModel?.balance ?? 0.0;

      // قسمة أجرة التوصيل مع مشغّل الأسطول (دفعة «ابدأ المشغل»): كابتنٌ تابعٌ
      // لمشغّل يحتفظ بحصّته (operatorDriverShare) والباقي للمشغّل، ويُثبَّت
      // على الطلب (operatorShare) ليجمعه المشغّل من دفتره. **الكابتن المستقلّ
      // (operatorId فارغ) لا يتغيّر في حسابه شيء إطلاقاً** — الفرع كله يُتخطّى.
      final operatorId = driverModel?.operatorId ?? '';
      double operatorShare = 0;
      if (operatorId.isNotEmpty) {
        operatorShare = order.driverShare - (driverModel?.operatorDriverShare ?? 0);
        if (operatorShare < 0) operatorShare = 0;
        if (operatorShare > order.driverShare) operatorShare = order.driverShare;
      }
      // الكابتن يحتفظ بأقلّ بمقدار حصّة المشغّل — نقداً كان أو إلكترونياً:
      //   إلكتروني: أجرته+الإكرامية − حصة المشغّل = حصّته+الإكرامية.
      //   نقدي: قبض كامل المبلغ، فيدين للمشغّل بحصّته (رصيده − حصة المشغّل).
      final effectiveDelta = delta - operatorShare;

      tx.update(_orders.doc(orderId), {
        'status': models.OrderStatus.delivered.name,
        'isPaid': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusChangedAt': FieldValue.serverTimestamp(),
        'platformCommission': order.calculatedCommission,
        if (operatorId.isNotEmpty) 'operatorId': operatorId,
        if (operatorId.isNotEmpty) 'operatorShare': operatorShare,
      });
      tx.update(_drivers.doc(driverId), {
        'totalDeliveries': FieldValue.increment(1),
        if (effectiveDelta != 0) 'balance': FieldValue.increment(effectiveDelta),
        // دفعة ٠-ب (C1/H2): مؤشّر لحركة التسليم — يُكتب حصراً حين يتغيّر الرصيد
        // (نفس شرط السطر أعلاه) فتراه القاعدة مقروناً بالحركة والطلب المُسلَّم.
        if (effectiveDelta != 0) 'lastLedgerTxId': txRef.id,
        'isAvailable': true,
      });
      // الحركة في نفس المعاملة، فلا يتغيّر رصيد دون سجلّ يفسّره. وحين لا
      // تغيير (نقدي قُيّدت عُهدته عند الاستلام، ولا مشغّل) لا حركة صفرية تلوّث السجلّ.
      if (effectiveDelta != 0) {
        tx.set(
          txRef,
          models.DriverTransaction(
            id: txRef.id,
            driverId: driverId,
            type: isCash
                ? models.DriverTransactionType.deliveryCash
                : models.DriverTransactionType.deliveryOnline,
            amount: effectiveDelta,
            balanceAfter: currentBalance + effectiveDelta,
            orderId: orderId,
            orderNumber: order.orderNumber,
            performedBy: _auth.currentUser?.uid ?? driverId,
            createdAt: DateTime.now(),
          ).toMap(),
        );
      }
    });
    // التسليم يغيّر الحالة داخل المعاملة لا عبر updateOrderStatus، فيُبلَّغ
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

  /// دفتر مطعمٍ كامل التاريخ — قراءة واحدة لكل طلباته وتسوياته معاً.
  ///
  /// **بلا سقف عمداً** (فحص السلوك 2026-08-20): كان «المتبقي» يُحسب من
  /// صافي أحدث ٢٠٠ طلب مقابل مدفوعاتٍ كاملةِ التاريخ — طرفا معادلة من
  /// عمرين مختلفين، فينحرف الدفتر فور تجاوز الـ٢٠٠ ويهدم ثقة التسوية.
  /// حجم مطعم واحد محتملٌ في مرحلة الإطلاق (get لا تدفّق حي)؛ وحين يكبر
  /// التاريخ فالحل رصيدٌ جارٍ مخزَّن يحدّثه الخادم (المسار د).
  Future<
      ({
        double meals,
        double commission,
        double compensations,
        double chargebacks,
        double paid,
        int deliveredCount,
      })> restaurantLedgerBalance(String restaurantId) async {
    final ordersSnap =
        await _orders.where('restaurantId', isEqualTo: restaurantId).get();
    double meals = 0, commission = 0, comp = 0, charge = 0;
    var delivered = 0;
    for (final d in ordersSnap.docs) {
      final o = models.Order.fromMap(d.data(), d.id);
      if (o.status == models.OrderStatus.delivered) {
        meals += o.itemsTotal;
        commission += o.effectiveCommission;
        delivered++;
      }
      comp += o.restaurantCompensation;
      charge += o.restaurantChargeback;
    }
    final setSnap = await _restaurantSettlements
        .where('restaurantId', isEqualTo: restaurantId)
        .get();
    final paid = setSnap.docs.fold(
        0.0, (s, d) => s + ((d.data()['amount'] as num?)?.toDouble() ?? 0));
    return (
      meals: meals,
      commission: commission,
      compensations: comp,
      chargebacks: charge,
      paid: paid,
      deliveredCount: delivered,
    );
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

  /// ختوم استهلاك دفعات البطاقة (دفعة ٠-ب، C3): مستند لكل paymentId يمنع
  /// إعادة استخدام دفعةٍ واحدة لطلبات كثيرة.
  CollectionReference<Map<String, dynamic>> get _paymentConsumptions =>
      _db.collection('payment_consumptions');

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
    // كوبون نسبة بلا سقف: القواعد (بعد تحصين 2026-08-15) ترفضه لحظة إنشاء
    // الطلب — فلو مرّ من هنا لفشل الطلب **بعد** شحن البطاقة. يُرفض مبكراً
    // برسالة تدلّ المدير على العلاج بدل فشلٍ غامض عند الدفع.
    if (coupon.type == models.CouponType.percentage && coupon.maxDiscount <= 0) {
      throw Exception('هذا الكود يحتاج ضبط «سقف الخصم» من لوحة الإدارة');
    }
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

  // أُزيلت _recordCouponUse: صار تقييد الكوبون يقع **ذرّياً داخل دفعة إنشاء
  // الطلب** (_stampCouponUse في placeOrder، ومباشرةً في معاملة
  // placeOrderWithWallet) لا بعده — فالقاعدة تربط الخصم بوجود العلامة في نفس
  // اللحظة (existsAfter)، ولا يبقى مسارٌ لاحقٌ يفشل فيمرّ الخصم بلا تقييد.

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
          // سقف ٢٠٠ حركة بترتيب خادمي — كسابقتها (نواقص لا-Blaze
          // 2026-08-20)؛ الفهرس (driverId+createdAt) يُنشر آلياً.
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots()
          .map((s) => s.docs
              .map((d) => models.DriverTransaction.fromMap(d.data(), d.id))
              .toList());

  /// إلغاء إداري — من لوحة التحكم، ومسموح في أي حالة نشطة.
  Future<void> cancelOrder(String orderId) async {
    final order = await _getOrderOrThrow(orderId);
    // حصانة التكرار **بمعاملة ذرّية** لا فحصاً منفصلاً (مراجعة 2026-08-15):
    // الفحص المنفصل يمنع التكرار المتعاقب فقط — ضغطتان متزامنتان من
    // جهازين تقرآن الحالة قبل ثبوت أولاهما فتمرّان معاً ويتكرر الاسترداد
    // وعكس العُهدة. هنا القراءة والقفل (كتابة cancelled) في معاملة واحدة:
    // واحدٌ فقط يفوز بالقفل ويجري الآثار المالية، والثاني يقرأ cancelled
    // داخل معاملته فيخرج بصمت. لا نحجب noDriverFound — إلغاؤه مشروع.
    //
    // دفعة ١ (عطل السباق ٥): **عكس العُهدة داخل نفس المعاملة** — كان نداءً
    // منفصلاً بعد القفل، فلو مات جهاز المدير بينهما بقي القيد على الكابتن
    // لطلبٍ أُلغي (خصمٌ على توصيلة لن يحصّلها) بلا إعادة، لأن إعادة الإلغاء
    // تخرج مبكراً «أُلغي سلفاً». المدير يتخطّى قيود القواعد (isAdmin) فلا يلزمه
    // lastLedgerTxId، ونضيفه اتساقاً. بقية الآثار (المحفظة/الكوبون/الإتاحة/
    // تعويض المطعم) تبقى بعده — أقلّ حرجاً (المحفظة علمٌ يراه المدير).
    final won = await _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(_orders.doc(orderId));
      final data = snap.data();
      if (!snap.exists || data == null) return false;
      final o = models.Order.fromMap(data, orderId);
      if (o.status == models.OrderStatus.cancelled ||
          o.status == models.OrderStatus.refunded) {
        return false;
      }
      // قراءة رصيد الكابتن (قبل الكتابة) إن كانت العُهدة مقيَّدة عليه.
      final driverId = o.driverId ?? '';
      final reverse =
          o.custodyDebited && o.custodyAmount != 0 && driverId.isNotEmpty;
      double driverBalance = 0;
      if (reverse) {
        final dSnap = await tx.get(_drivers.doc(driverId));
        driverBalance = dSnap.exists && dSnap.data() != null
            ? models.Driver.fromMap(dSnap.data()!, dSnap.id).balance
            : 0.0;
      }
      tx.update(_orders.doc(orderId), {
        'status': models.OrderStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusChangedAt': FieldValue.serverTimestamp(),
      });
      if (reverse) {
        final custody = o.custodyAmount;
        final txRef = _driverTransactions.doc();
        tx.update(_drivers.doc(driverId), {
          'balance': FieldValue.increment(custody),
          'lastLedgerTxId': txRef.id,
        });
        tx.set(
          txRef,
          models.DriverTransaction(
            id: txRef.id,
            driverId: driverId,
            type: models.DriverTransactionType.custodyReversal,
            amount: custody,
            balanceAfter: driverBalance + custody,
            orderId: orderId,
            orderNumber: o.orderNumber,
            note: 'إلغاء الطلب بعد الاستلام',
            performedBy: _auth.currentUser?.uid ?? '',
            createdAt: DateTime.now(),
          ).toMap(),
        );
      }
      return true;
    });
    if (!won) return;
    NotifyRelay.orderEvent(orderId, OrderEvent.status);
    await _refundWalletOnCancel(order);
    // عكس العُهدة تمّ داخل المعاملة (عطل السباق ٥) — لا نداء منفصل هنا.
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
    // لا يُعاد الإنقاص لطلبٍ سبق إرجاع كوبونه (دفعة ٠-ب، H7): الختم
    // couponReleased يحرس من التكرار في القاعدة، ونتخطّاه هنا مبكراً فلا
    // دفعةً مرفوضة بلا داعٍ.
    if (order.couponReleased) return;
    try {
      final batch = _db.batch();
      batch.update(_coupons.doc(code), {'usedCount': FieldValue.increment(-1)});
      batch.update(_couponUsages.doc(_usageId(code, order.customerId)),
          {'count': FieldValue.increment(-1)});
      // ختم «أُرجع» على الطلب في نفس الدفعة — القاعدة تشترط رفعَه ذرّياً مع
      // الإنقاص (getAfter) فيصير الإرجاع لمرّة واحدة لا يتكرّر.
      batch.update(_orders.doc(order.id), {'couponReleased': true});
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
    // القلب معاملةً (نفس حصانة الإلغاء الإداري)، **وبلا استرداد من جهاز
    // العميل** (مراجعة 2026-08-15): القواعد — بحق — تمنع العميل من زيادة
    // رصيده، فكان `_refundWalletOnCancel` يُرفض بصمت: الطلب يُلغى فعلاً
    // ورصيده يضيع بلا أثر، والرسالة تكذب «تعذّر الإلغاء». الآن يُختم
    // `walletRefundPending` على الطلب فيظهر لدى المدير ليصرفه بضغطة —
    // الاسترداد الآلي الحق يحتاج خادماً (المسار د).
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_orders.doc(orderId));
      final data = snap.data();
      if (!snap.exists || data == null) throw Exception('الطلب غير موجود');
      final status = models.OrderStatus.values.firstWhere(
        (s) => s.name == (data['status'] as String? ?? ''),
        orElse: () => models.OrderStatus.created,
      );
      if (status == models.OrderStatus.cancelled ||
          status == models.OrderStatus.refunded) {
        return; // أُلغي من مسار آخر — لا تكرار للآثار.
      }
      tx.update(_orders.doc(orderId), {
        'status': models.OrderStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusChangedAt': FieldValue.serverTimestamp(),
        if (order.walletUsed > 0) 'walletRefundPending': true,
      });
    });
    NotifyRelay.orderEvent(orderId, OrderEvent.status);
    await _releaseOrderDriver(order);
    await _releaseCouponOnCancel(order);
  }

  /// طلبات الإلغاء الذاتي التي تنتظر ردّ رصيد المحفظة — يصرفها المدير.
  Stream<List<models.Order>> streamWalletRefundsPending() => _orders
      .where('walletRefundPending', isEqualTo: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => models.Order.fromMap(d.data(), d.id)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  /// صرف استرداد المحفظة المعلّق — بصلاحية المدير (الزيادة محظورة على
  /// العميل). يمسح العلم أولاً ثم يضيف الرصيد، فتكرار الضغط لا يصرف مرتين.
  Future<void> settlePendingWalletRefund(models.Order order) async {
    final cleared = await _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(_orders.doc(order.id));
      if (snap.data()?['walletRefundPending'] != true) return false;
      tx.update(_orders.doc(order.id), {'walletRefundPending': false});
      return true;
    });
    if (!cleared) return;
    await addWalletCredit(
      order.customerId,
      order.walletUsed,
      type: models.WalletTransactionType.orderReversal,
      orderId: order.id,
      orderNumber: order.orderNumber,
      note: 'ردّ رصيد إلغاء ذاتي',
    );
    logAdminAction('wallet.refund',
        'ردّ ${order.walletUsed.toStringAsFixed(2)} ر.س لمحفظة عميل الطلب #${order.orderNumber}');
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
  Future<Uint8List?> fetchApplicationDocImage(String docId,
      {String collection = 'driver_application_docs'}) async {
    final doc = await _db.collection(collection).doc(docId).get();
    final img = doc.data()?['image'];
    return img is Blob ? img.bytes : null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // التسجيل داخل التطبيق — كابتن ومطعم (نمط أوبر: حساب ← نموذج ومستندات
  // ← انتظار حيّ ← اعتماد المدير فيُفتح التطبيق وحده، بلا كود)
  // ═══════════════════════════════════════════════════════════════════

  CollectionReference<Map<String, dynamic>> get _restaurantApplications =>
      _db.collection('restaurant_applications');

  /// طلب المتقدّم نفسه — معرّف المستند هو uid حسابه (طلبات التطبيق فقط؛
  /// طلبات الويب معرّفها عشوائي فلا تلتقطها هذه، وهذا مقصود).
  Stream<models.DriverApplication?> streamOwnDriverApplication(String uid) =>
      _driverApplications.doc(uid).snapshots().map((d) =>
          d.exists && d.data() != null
              ? models.DriverApplication.fromMap(d.data()!, d.id)
              : null);

  Stream<models.RestaurantApplication?> streamOwnRestaurantApplication(
          String uid) =>
      _restaurantApplications.doc(uid).snapshots().map((d) =>
          d.exists && d.data() != null
              ? models.RestaurantApplication.fromMap(d.data()!, d.id)
              : null);

  /// دور حساب المتقدّم لحظياً — شاشة الانتظار تبثّه لتنقلب وحدها لحظة
  /// أن يمنحه الاعتمادُ دورَه (تغيير الدور هو «مفتاح الفتح» لا حالة الطلب).
  Stream<models.UserRole?> streamOwnRole(String uid) =>
      _users.doc(uid).snapshots().map((d) {
        final raw = d.data()?['role'] as String?;
        if (raw == null) return null;
        return models.UserRole.values
            .where((r) => r.name == raw)
            .firstOrNull;
      });

  /// يرفع صور المستندات كمستندات Blob ويعيد {مفتاح المستند: معرّفه}.
  /// الطلب يجب أن يكون قائماً «معلّقاً» قبل الرفع — القاعدة تربط كل صورة
  /// بطلبٍ يملكه المتصل (ownsPendingApplication) فتُرفض قبله.
  Future<Map<String, String>> _uploadApplicationDocs({
    required String collection,
    required String applicationId,
    required Map<String, Uint8List> images,
  }) async {
    final ids = <String, String>{};
    for (final e in images.entries) {
      final ref = _db.collection(collection).doc();
      await ref.set({
        'applicationId': applicationId,
        'label': e.key,
        'image': Blob(e.value),
        'createdAt': FieldValue.serverTimestamp(),
      });
      ids[e.key] = ref.id;
    }
    return ids;
  }

  /// تقديم (أو إعادة تقديم) طلب انضمام كابتن من داخل التطبيق. معرّف
  /// المستند = uid، فإعادة التقديم بعد الرفض تفتح المستند نفسه «معلّقاً»
  /// بدل أن تكدّس نسخاً أمام المدير. الطلب يُكتب أولاً بلا مستندات ثم
  /// تُرفع الصور ويُربط بها — الترتيب شرط القاعدة لا تفضيلاً.
  Future<void> submitDriverApplication({
    required String uid,
    required String name,
    required String phone,
    required String email,
    required String nationalId,
    required String vehicleType,
    required String vehiclePlate,
    String referredByCode = '',
    required Map<String, Uint8List> docImages,
    required List<Uint8List> vehiclePhotos,
  }) async {
    final ref = _driverApplications.doc(uid);
    await ref.set({
      'uid': uid,
      'source': 'app',
      'name': name.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'nationalId': nationalId.trim(),
      'vehicleType': vehicleType.trim(),
      'vehiclePlate': vehiclePlate.trim(),
      'referredByCode': referredByCode.trim().toUpperCase(),
      'documents': <String, String>{},
      'vehiclePhotos': <String>[],
      'status': models.DriverApplicationStatus.pending.name,
      'issuedCode': '',
      'reviewNote': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final docIds = await _uploadApplicationDocs(
      collection: 'driver_application_docs',
      applicationId: uid,
      images: docImages,
    );
    final photoIds = <String>[];
    for (var i = 0; i < vehiclePhotos.length; i++) {
      final ids = await _uploadApplicationDocs(
        collection: 'driver_application_docs',
        applicationId: uid,
        images: {'vehicle_$i': vehiclePhotos[i]},
      );
      photoIds.add(ids.values.first);
    }
    await ref.update({'documents': docIds, 'vehiclePhotos': photoIds});
  }

  Future<void> submitRestaurantApplication({
    required String uid,
    required String restaurantName,
    required String ownerName,
    required String phone,
    required String email,
    required String district,
    required String description,
    required Map<String, Uint8List> docImages,
  }) async {
    final ref = _restaurantApplications.doc(uid);
    await ref.set({
      'uid': uid,
      'restaurantName': restaurantName.trim(),
      'ownerName': ownerName.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'district': district.trim(),
      'description': description.trim(),
      'documents': <String, String>{},
      'status': models.DriverApplicationStatus.pending.name,
      'reviewNote': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    final docIds = await _uploadApplicationDocs(
      collection: 'restaurant_application_docs',
      applicationId: uid,
      images: docImages,
    );
    await ref.update({'documents': docIds});
  }

  /// اعتماد مباشر لطلب كابتن قُدّم من التطبيق: منح الدور هو الفتح نفسه —
  /// شاشة الانتظار عنده تبثّ دوره فتنقلب لحظة هذا التحديث. مستند السائق
  /// يُنشئه جهازُه هو بعد الفتح (قاعدة الإنشاء تفرض أرصدة صفرية ولا تسمح
  /// لغير صاحب المعرّف — حتى المدير — بإنشائه).
  Future<void> approveDriverApplicationDirect(
      models.DriverApplication application) async {
    await _users.doc(application.uid).update({
      'role': models.UserRole.driver.name,
      if (application.nationalId.trim().isNotEmpty)
        'nationalId': application.nationalId.trim(),
      if (application.phone.trim().isNotEmpty)
        'phone': application.phone.trim(),
    });
    await _driverApplications.doc(application.id).update({
      'status': models.DriverApplicationStatus.approved.name,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    logAdminAction('application.approve',
        'اعتماد مباشر لكابتن ${application.name} — تطبيقه يُفتح فوراً',
        extra: {'applicationId': application.id});
  }

  /// مستند السائق بعد الاعتماد — يستدعيه جهاز الكابتن نفسه لحظة الفتح.
  /// موجود مسبقاً؟ لا شيء يُمسّ (إعادة فتح التطبيق لا تصفّر شيئاً).
  Future<void> ensureDriverDocFromApplication(
      models.DriverApplication app) async {
    final existing = await _drivers.doc(app.uid).get();
    if (existing.exists) return;
    await addDriver(models.Driver(
      id: app.uid,
      name: app.name,
      phone: app.phone,
      vehicleType: app.vehicleType.isEmpty ? 'دراجة نارية' : app.vehicleType,
      vehiclePlate: app.vehiclePlate,
      referredByCode: app.referredByCode,
    ));
  }

  Stream<List<models.RestaurantApplication>> streamRestaurantApplications() =>
      _restaurantApplications.snapshots().map((s) {
        final list = s.docs
            .map((d) => models.RestaurantApplication.fromMap(d.data(), d.id))
            .toList();
        list.sort((a, b) {
          final ap = a.status == models.DriverApplicationStatus.pending;
          final bp = b.status == models.DriverApplicationStatus.pending;
          if (ap != bp) return ap ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        });
        return list;
      });

  /// اعتماد طلب مطعم: يربط الحساب بمطعمٍ يختاره المدير (يُنشأ من شاشة
  /// المطاعم أولاً إن لم يوجد) ويمنحه دور «مدير مطعم». الربط قبل الدور
  /// في التحديث نفسه — دورٌ بلا restaurantId حسابٌ معلّق في الفراغ.
  Future<void> approveRestaurantApplication({
    required models.RestaurantApplication application,
    required String restaurantId,
  }) async {
    await _users.doc(application.uid).update({
      'role': models.UserRole.restaurantManager.name,
      'restaurantId': restaurantId,
      if (application.phone.trim().isNotEmpty)
        'phone': application.phone.trim(),
    });
    await _restaurantApplications.doc(application.id).update({
      'status': models.DriverApplicationStatus.approved.name,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    logAdminAction('application.approve',
        'اعتماد مطعم ${application.restaurantName} وربطه بحساب مديره',
        extra: {'applicationId': application.id, 'restaurantId': restaurantId});
  }

  Future<void> rejectRestaurantApplication({
    required String applicationId,
    required String note,
  }) =>
      _restaurantApplications.doc(applicationId).update({
        'status': models.DriverApplicationStatus.rejected.name,
        'reviewNote': note,
        'reviewedAt': FieldValue.serverTimestamp(),
      }).then((_) {
        logAdminAction('application.reject', 'رفض طلب انضمام مطعم',
            extra: {'applicationId': applicationId});
      });

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

  // يحسب المتوسط التراكمي الجديد بعد إضافة تقييمٍ واحد. المطاعم/السائقون
  // بلا تقييمٍ سابق يبدؤون من التقييم الأول نفسه لا من متوسطٍ مع الافتراضي 5.0.
  double _nextAvg(double curAvg, int curCount, double newRating) =>
      curCount <= 0
          ? double.parse(newRating.toStringAsFixed(1))
          : double.parse(
              (((curAvg * curCount) + newRating) / (curCount + 1))
                  .toStringAsFixed(1));

  /// تقييم طلبٍ مسلَّم — إصلاح ثغرة §٠ (تكرار/تلفيق التقييم).
  ///
  /// الزيادة في عدّاد المطعم/السائق **مربوطةٌ بعلامة تقييمٍ للطلب** تُنشأ في
  /// **الدفعة الذرّية نفسها**: `drivers|restaurants/{id}/ratings/{orderId}`.
  /// القواعد ترفض زيادة العدّاد إلا إن أُنشئت العلامة في هذه الدفعة
  /// (`existsAfter`) ولم تكن موجودة — والعلامة تُنشأ مرة واحدة فقط (create)
  /// وتشترط طلباً مسلَّماً يملكه العميل. فالتكرار مستحيل (لا علامة مرتين)،
  /// والتلفيق مستحيل (لا طلب حقيقي = لا علامة). الدفعة كلها تنجح أو تفشل معاً،
  /// فطلبان متزامنان لا يزيدان العدّاد مرتين (الثاني يصطدم بعلامةٍ موجودة).
  Future<void> rateOrder({
    required String orderId,
    required String driverId,
    required double orderRating,
    required double driverRating,
    String? review,
    String? restaurantId,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    // فحصٌ مسبق لتجربةٍ ألطف (لا يُعرض الحوار ثانيةً)، والحارس الحقيقي
    // هو العلامة في القاعدة: لو سبق التقييم فشلت الدفعة ذرّياً على أي حال.
    final orderSnap = await _orders.doc(orderId).get();
    if (!orderSnap.exists || orderSnap.data()?['isRated'] == true) return;

    final hasDriver = driverId.isNotEmpty;
    final hasRest = restaurantId != null && restaurantId.isNotEmpty;

    // معاملة ذرّية (دفعة ١، عطل السباق ٤): كان متوسط التقييم والعدّاد يُحسبان
    // من قراءةٍ **خارج الدفعة**، فتقييمان متزامنان لنفس الكابتن/المطعم يقرآن
    // العدّاد نفسه فيكتب كلاهما «+١» واحداً (تحديثٌ ضائع) ومتوسطاً منحرفاً.
    // الآن القراءة والحساب والكتابة في معاملة واحدة: التزامن يُعيد المحاولة
    // فيقرأ العدّاد المحدَّث ويحسب عليه. والعلامة الخالدة لكل طلب تبقى تمنع
    // تكرار تقييم الطلب نفسه (قراءتها/كتابتها ذرّياً كما كانت).
    try {
      await _db.runTransaction((tx) async {
        final oSnap = await tx.get(_orders.doc(orderId));
        if (!oSnap.exists || oSnap.data() == null) return;
        if (oSnap.data()!['isRated'] == true) return; // حصانة تكرار
        final dSnap = hasDriver ? await tx.get(_drivers.doc(driverId)) : null;
        final rSnap = hasRest ? await tx.get(_restaurants.doc(restaurantId)) : null;

        tx.update(_orders.doc(orderId), {
          'customerRating': orderRating,
          'driverRating': driverRating,
          'isRated': true,
          if (review != null) 'customerReview': review,
        });

        if (dSnap != null && dSnap.exists && dSnap.data() != null) {
          final d = models.Driver.fromMap(dSnap.data()!, dSnap.id);
          tx.set(_drivers.doc(driverId).collection('ratings').doc(orderId), {
            'stars': driverRating,
            'customerId': uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.update(_drivers.doc(driverId), {
            'rating': _nextAvg(d.rating, d.ratingCount, driverRating),
            'ratingCount': d.ratingCount + 1,
            'ratingOrderId': orderId,
          });
        }

        if (rSnap != null && rSnap.exists && rSnap.data() != null) {
          final r = models.Restaurant.fromMap(rSnap.data()!, rSnap.id);
          tx.set(
              _restaurants.doc(restaurantId).collection('ratings').doc(orderId), {
            'stars': orderRating,
            'customerId': uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.update(_restaurants.doc(restaurantId), {
            'rating': _nextAvg(r.rating, r.ratingCount, orderRating),
            'ratingCount': r.ratingCount + 1,
            'ratingOrderId': orderId,
          });
        }
      });
    } on FirebaseException catch (e) {
      // permission-denied المتوقّع الوحيد هنا: علامةٌ موجودة (سبق التقييم من
      // جهازٍ آخر بين الفحص والدفع) — نجاحٌ خامل لا خطأ يُعرض للعميل.
      if (e.code != 'permission-denied') rethrow;
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
        // ختم الحل أساس الإغلاق التلقائي؛ وإعادة الفتح تمسح علامة
        // «أعادها صاحبها» كي لا تلتصق بالشكوى بعد معالجتها من جديد.
        if (status == models.ComplaintStatus.resolved)
          'resolvedAt': FieldValue.serverTimestamp(),
        if (status == models.ComplaintStatus.inProgress)
          'reopenedBySubmitter': FieldValue.delete(),
        if (adminNote != null) 'adminNote': adminNote,
        if (resolution != null) 'resolution': resolution,
      }).then((_) {
        logAdminAction('complaint.status', 'تغيير حالة شكوى إلى ${status.label}',
            extra: {'complaintId': complaintId});
      });

  /// جواب مقدّم الشكوى على «هل حُلّت شكواك؟» (دورة حياة الشكوى):
  /// نعم ← تُغلق برضاه (الإغلاق الصادق الوحيد)؛ لا ← تعود «قيد
  /// المعالجة» موسومة بأنها ارتدت — القواعد تسمح له بهذين التحولين
  /// تحديداً من حالة «محلولة» فقط.
  Future<void> confirmComplaintResolution(
    String complaintId, {
    required bool solved,
  }) =>
      _complaints.doc(complaintId).update(solved
          ? {'status': models.ComplaintStatus.closed.name}
          : {
              'status': models.ComplaintStatus.inProgress.name,
              'reopenedBySubmitter': true,
            });

  /// كنس المحلولات الصامتة: كل «محلولة» مضت مهلة تأكيدها (٣ أيام) بلا
  /// جواب من صاحبها تُغلق تلقائياً. يُستدعى عند فتح شاشة شكاوى الإدارة —
  /// كسل مقصود: لا خادم عندنا يجدول، فتُنفَّذ الصيانة حيث تُقرأ البيانات.
  Future<int> closeStaleResolvedComplaints() async {
    final snap = await _complaints
        .where('status', isEqualTo: models.ComplaintStatus.resolved.name)
        .get();
    var closed = 0;
    for (final d in snap.docs) {
      final c = models.Complaint.fromMap(d.data(), d.id);
      if (c.autoCloseDue) {
        await d.reference
            .update({'status': models.ComplaintStatus.closed.name});
        closed++;
      }
    }
    return closed;
  }

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
      // دورة حياة الشكوى: الحل لا يُغلق — يفتح مهلة تأكيد صاحبها
      // (resolvedAt أساسها)، ومسح علامة الارتداد إن كانت من جولة سابقة.
      'resolvedAt': FieldValue.serverTimestamp(),
      'reopenedBySubmitter': FieldValue.delete(),
      'resolution': reply.isEmpty ? 'تم الحل بلا إجراء إضافي' : reply,
      'adminNote': adminNote ??
          (actionsSummary.isEmpty ? 'تم الحل بلا إجراء إضافي' : actionsSummary),
    });
  }

  /// تقرير الذراع الخادمية (دفعة الذراع ١ — 2026-08-16): تكتبه دالة
  /// Supabase Edge بحساب الخدمة، والعملاء ممنوعون من كتابته بالقواعد —
  /// فما يظهر هنا موثوق أنه من الخادم لا من جهاز.
  Stream<Map<String, dynamic>?> streamServerReport(String reportId) => _db
      .collection('server_reports')
      .doc(reportId)
      .snapshots()
      .map((d) => d.data());

  /// مفتاح شريك إعلانات zol (دفعة الإعلانات 2026-08-16): يُلصق مرة من
  /// اللوحة ويُخزَّن في admin_secrets (للمدير حصراً في القواعد) — لا
  /// يُدفن في كود التطبيق أبداً لأنه يُستخرج من أي APK.
  Future<String?> getZolPartnerKey() async {
    final doc = await _adminSecrets.doc('zol_partner').get();
    final key = (doc.data()?['key'] as String?)?.trim();
    return (key == null || key.isEmpty) ? null : key;
  }

  Future<void> saveZolPartnerKey(String key) => _adminSecrets
          .doc('zol_partner')
          .set({'key': key.trim(), 'updatedAt': FieldValue.serverTimestamp()})
          .then((_) {
        // يُسجَّل الفعل لا السر — المفتاح نفسه لا يدخل سجلّ التدقيق.
        logAdminAction('ads.key', 'تحديث مفتاح شريك الإعلانات (zol)');
      });

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