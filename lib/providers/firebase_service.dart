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
  CollectionReference<Map<String, dynamic>> get _complaintMessages =>
      _db.collection('complaint_messages');
  CollectionReference<Map<String, dynamic>> get _reassignments => _db.collection('reassignments');
  CollectionReference<Map<String, dynamic>> get _broadcasts => _db.collection('broadcasts');
  CollectionReference<Map<String, dynamic>> get _registrationCodes =>
      _db.collection('registrationCodes');
  CollectionReference<Map<String, dynamic>> get _deliverySettings =>
      _db.collection('delivery_settings');

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
        return to == models.OrderStatus.driverAssigned;
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

  Stream<List<models.AppUser>> streamUsers() => _users
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => models.AppUser.fromMap(d.data(), d.id)).toList());

  Future<void> updateUser(models.AppUser user) => _users.doc(user.uid).update(user.toMap());

  Future<void> setUserActive(String uid, bool isActive) =>
      _users.doc(uid).update({'isActive': isActive});

  Future<void> deleteUserDoc(String uid) => _users.doc(uid).delete();

  Future<void> addWalletCredit(String userId, double amount) =>
      _users.doc(userId).update({'walletBalance': FieldValue.increment(amount)});

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

  Stream<List<models.RegistrationCode>> streamRegistrationCodes(
          String restaurantId) =>
      _registrationCodes
          .where('restaurantId', isEqualTo: restaurantId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map((d) => models.RegistrationCode.fromMap(d.data(), d.id))
              .toList());

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

  Stream<List<models.Order>> streamActiveOrders() => _orders
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => models.Order.fromMap(d.data(), d.id))
          .where((o) => o.status.isActive || o.status == models.OrderStatus.noDriverFound)
          .toList());

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
  }

  Future<void> markPickedUpBySelf(String orderId) async {
    final ref = _orders.doc(orderId);
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('الطلب غير موجود');
    }

    final current = models.Order.fromMap(doc.data()!, doc.id);
    if (current.status != models.OrderStatus.readyForPickup &&
        current.status != models.OrderStatus.searchingDriver &&
        current.status != models.OrderStatus.driverAssigned) {
      throw Exception('لا يمكن تأكيد الاستلام من حالة ${current.status.label}');
    }

    await ref.update({
      'status': models.OrderStatus.onTheWay.name,
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
  }

  static const int _driverCandidatesCount = 3;

  Future<bool> autoAssignNearestDriver(models.Order order) async {
    if (order.restaurantLat == null || order.restaurantLng == null) return false;
    final driversSnap = await _drivers.get();

    final candidateDrivers = <models.Driver>[];
    final candidateDistances = <double>[];
    for (final doc in driversSnap.docs) {
      final d = models.Driver.fromMap(doc.data(), doc.id);
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
      'driverAcknowledged': true,
    });
    batch.update(_drivers.doc(chosen.id), {'isAvailable': false});
    await batch.commit();
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
    await ref.update({
      'driverAcknowledged': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
      batch.update(_drivers.doc(current.driverId!), {'isAvailable': true});
    }
    await batch.commit();

    final refreshedDoc = await ref.get();
    if (refreshedDoc.exists && refreshedDoc.data() != null) {
      final refreshedOrder = models.Order.fromMap(refreshedDoc.data()!, refreshedDoc.id);
      await autoAssignNearestDriver(refreshedOrder);
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

  /// إلغاء إداري — من لوحة التحكم، ومسموح في أي حالة نشطة.
  Future<void> cancelOrder(String orderId) =>
      updateOrderStatus(orderId, models.OrderStatus.cancelled);

  /// إلغاء العميل لطلبه — مسموح فقط قبل أن يبدأ المطعم التحضير
  /// ([models.Order.canCustomerCancel]). التحقق هنا وليس في الواجهة فقط، حتى
  /// لا يمرّ إلغاء متأخر لو استُدعيت الدالة من مسار آخر أو تغيّرت الحالة بين
  /// عرض الزر والضغط عليه.
  Future<void> cancelOrderByCustomer(String orderId) async {
    final doc = await _orders.doc(orderId).get();
    final data = doc.data();
    if (!doc.exists || data == null) {
      throw Exception('الطلب غير موجود');
    }
    final order = models.Order.fromMap(data, doc.id);
    if (!order.canCustomerCancel) {
      throw Exception('لا يمكن إلغاء الطلب بعد بدء التحضير، تواصل مع الإدارة');
    }
    await updateOrderStatus(orderId, models.OrderStatus.cancelled);
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
      if (review != null) 'review': review,
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

  Stream<List<models.Complaint>> streamComplaintsSubmittedBy(String uid) => _complaints
      .where('submittedByUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => models.Complaint.fromMap(d.data(), d.id)).toList());

  Stream<List<models.Complaint>> streamComplaintsAgainst(String uid) => _complaints
      .where('againstUid', isEqualTo: uid)
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
    if (refundPercentage != null && refundPercentage > 0) {
      final refundAmount = order.grandTotal * (refundPercentage / 100);
      await addWalletCredit(order.customerId, refundAmount);
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
          .orderBy('createdAt')
          .snapshots()
          .map((s) => s.docs.map((d) => models.ChatMessage.fromMap(d.data(), d.id)).toList());

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