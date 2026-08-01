// lib/models/models.dart
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';

enum UserRole { admin, customer, driver, restaurantManager }

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  readyForPickup,
  outForDelivery,
  delivered,
  cancelled,
  rejected,
}

enum PaymentMethod { cash, card, wallet }

enum ComplaintStatus { open, inProgress, resolved, closed }

enum ComplaintType { lateDelivery, wrongOrder, badQuality, driverBehavior, other }

extension UserRoleExt on UserRole {
  String get label {
    const map = {
      UserRole.admin: 'مدير عام',
      UserRole.customer: 'عميل',
      UserRole.driver: 'سائق',
      UserRole.restaurantManager: 'مدير مطعم',
    };
    return map[this] ?? '';
  }
}

extension OrderStatusExt on OrderStatus {
  String get label {
    const map = {
      OrderStatus.pending: 'قيد الانتظار',
      OrderStatus.confirmed: 'تم التأكيد',
      OrderStatus.preparing: 'جاري التحضير',
      OrderStatus.readyForPickup: 'جاهز للاستلام',
      OrderStatus.outForDelivery: 'في الطريق إليك',
      OrderStatus.delivered: 'تم التوصيل',
      OrderStatus.cancelled: 'ملغى',
      OrderStatus.rejected: 'مرفوض',
    };
    return map[this] ?? '';
  }

  Color get color {
    const map = {
      OrderStatus.pending: Color(0xFFFF9800),
      OrderStatus.confirmed: Color(0xFF2196F3),
      OrderStatus.preparing: Color(0xFF9C27B0),
      OrderStatus.readyForPickup: Color(0xFF00BCD4),
      OrderStatus.outForDelivery: Color(0xFF3F51B5),
      OrderStatus.delivered: Color(0xFF4CAF50),
      OrderStatus.cancelled: Color(0xFFF44336),
      OrderStatus.rejected: Color(0xFF795548),
    };
    return map[this] ?? Colors.grey;
  }

  IconData get icon {
    const map = {
      OrderStatus.pending: Icons.hourglass_empty_rounded,
      OrderStatus.confirmed: Icons.check_circle_outline,
      OrderStatus.preparing: Icons.restaurant_rounded,
      OrderStatus.readyForPickup: Icons.shopping_bag_outlined,
      OrderStatus.outForDelivery: Icons.delivery_dining_rounded,
      OrderStatus.delivered: Icons.done_all_rounded,
      OrderStatus.cancelled: Icons.cancel_outlined,
      OrderStatus.rejected: Icons.block_rounded,
    };
    return map[this] ?? Icons.info_outline;
  }

  bool get isActive =>
      this != OrderStatus.delivered &&
      this != OrderStatus.cancelled &&
      this != OrderStatus.rejected;
}

extension PaymentMethodExt on PaymentMethod {
  String get label {
    const map = {
      PaymentMethod.cash: 'نقداً عند الاستلام',
      PaymentMethod.card: 'بطاقة ائتمان',
      PaymentMethod.wallet: 'المحفظة الإلكترونية',
    };
    return map[this] ?? '';
  }

  IconData get icon {
    const map = {
      PaymentMethod.cash: Icons.money_rounded,
      PaymentMethod.card: Icons.credit_card_rounded,
      PaymentMethod.wallet: Icons.account_balance_wallet_rounded,
    };
    return map[this] ?? Icons.payment;
  }
}

extension ComplaintTypeExt on ComplaintType {
  String get label {
    const map = {
      ComplaintType.lateDelivery: 'تأخر التوصيل',
      ComplaintType.wrongOrder: 'طلب خاطئ',
      ComplaintType.badQuality: 'جودة رديئة',
      ComplaintType.driverBehavior: 'سلوك السائق',
      ComplaintType.other: 'أخرى',
    };
    return map[this] ?? '';
  }
}

extension ComplaintStatusExt on ComplaintStatus {
  String get label {
    const map = {
      ComplaintStatus.open: 'مفتوحة',
      ComplaintStatus.inProgress: 'قيد المعالجة',
      ComplaintStatus.resolved: 'تم الحل',
      ComplaintStatus.closed: 'مغلقة',
    };
    return map[this] ?? '';
  }

  Color get color {
    const map = {
      ComplaintStatus.open: Color(0xFFF44336),
      ComplaintStatus.inProgress: Color(0xFFFF9800),
      ComplaintStatus.resolved: Color(0xFF4CAF50),
      ComplaintStatus.closed: Color(0xFF9E9E9E),
    };
    return map[this] ?? Colors.grey;
  }
}

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final DateTime createdAt;
  final String? fcmToken;
  final String? restaurantId;
  final String? restaurantName;
  final bool isActive;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.createdAt,
    this.fcmToken,
    this.restaurantId,
    this.restaurantName,
    this.isActive = true,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) => AppUser(
        uid: uid,
        name: map['name'] as String? ?? '',
        email: map['email'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        role: UserRole.values.firstWhere(
          (r) => r.name == map['role'],
          orElse: () => UserRole.customer,
        ),
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        fcmToken: map['fcmToken'] as String?,
        restaurantId: map['restaurantId'] as String?,
        restaurantName: map['restaurantName'] as String?,
        isActive: map['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.name,
        'createdAt': Timestamp.fromDate(createdAt),
        if (fcmToken != null) 'fcmToken': fcmToken,
        if (restaurantId != null) 'restaurantId': restaurantId,
        if (restaurantName != null) 'restaurantName': restaurantName,
        'isActive': isActive,
      };

  AppUser copyWith({
    String? name,
    String? phone,
    UserRole? role,
    String? restaurantId,
    String? restaurantName,
    bool? isActive,
  }) =>
      AppUser(
        uid: uid,
        name: name ?? this.name,
        email: email,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        createdAt: createdAt,
        fcmToken: fcmToken,
        restaurantId: restaurantId ?? this.restaurantId,
        restaurantName: restaurantName ?? this.restaurantName,
        isActive: isActive ?? this.isActive,
      );
}

class Restaurant {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final String phone;
  final bool isOpen;
  /// نصيب السائق من أجرة التوصيل (بدلاً من رقم رسوم توصيل واحد).
  final double driverShareFee;
  /// نصيب التطبيق/المنصة من أجرة التوصيل.
  final double appShareFee;
  /// أجرة كل كيلومتر إضافي (تُضاف كاملة لنصيب السائق) بعد تجاوز [freeKm].
  final double perKmFee;
  /// عدد الكيلومترات المشمولة ضمن أجرة التوصيل الأساسية دون رسوم إضافية.
  final double freeKm;
  final double minOrder;
  final String address;
  final int estimatedTimeMin;
  final double rating;
  final int totalOrders;
  final double? lat;
  final double? lng;

  const Restaurant({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.phone,
    this.isOpen = true,
    this.driverShareFee = 5.0,
    this.appShareFee = 0.0,
    this.perKmFee = 0.0,
    this.freeKm = 3.0,
    this.minOrder = 20.0,
    required this.address,
    this.estimatedTimeMin = 30,
    this.rating = 5.0,
    this.totalOrders = 0,
    this.lat,
    this.lng,
  });

  /// إجمالي أجرة التوصيل (نصيب السائق + نصيب التطبيق) — للتوافق مع الأماكن
  /// التي كانت تعرض رقماً واحداً فقط.
  double get deliveryFee => driverShareFee + appShareFee;

  factory Restaurant.fromMap(Map<String, dynamic> map, String id) =>
      Restaurant(
        id: id,
        name: map['name'] as String? ?? '',
        description: map['description'] as String? ?? '',
        emoji: map['emoji'] as String? ?? '🍽️',
        phone: map['phone'] as String? ?? '',
        isOpen: map['isOpen'] as bool? ?? true,
        // توافق مع البيانات القديمة التي كانت تخزّن deliveryFee كرقم واحد فقط.
        driverShareFee: (map['driverShareFee'] as num?)?.toDouble() ??
            (map['deliveryFee'] as num?)?.toDouble() ??
            5.0,
        appShareFee: (map['appShareFee'] as num?)?.toDouble() ?? 0.0,
        perKmFee: (map['perKmFee'] as num?)?.toDouble() ?? 0.0,
        freeKm: (map['freeKm'] as num?)?.toDouble() ?? 3.0,
        minOrder: (map['minOrder'] as num?)?.toDouble() ?? 20.0,
        address: map['address'] as String? ?? '',
        estimatedTimeMin: (map['estimatedTimeMin'] as num?)?.toInt() ?? 30,
        rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
        totalOrders: (map['totalOrders'] as num?)?.toInt() ?? 0,
        lat: (map['lat'] as num?)?.toDouble(),
        lng: (map['lng'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'emoji': emoji,
        'phone': phone,
        'isOpen': isOpen,
        'driverShareFee': driverShareFee,
        'appShareFee': appShareFee,
        'perKmFee': perKmFee,
        'freeKm': freeKm,
        // نُبقي على الحقل القديم مؤقتاً لتوافق النسخ الأقدم من التطبيق.
        'deliveryFee': deliveryFee,
        'minOrder': minOrder,
        'address': address,
        'estimatedTimeMin': estimatedTimeMin,
        'rating': rating,
        'totalOrders': totalOrders,
        'lat': lat,
        'lng': lng,
      };
}

class MenuCategory {
  final String id;
  final String restaurantId;
  final String name;
  final int sortOrder;

  const MenuCategory({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.sortOrder = 0,
  });

  factory MenuCategory.fromMap(Map<String, dynamic> map, String id) =>
      MenuCategory(
        id: id,
        restaurantId: map['restaurantId'] as String? ?? '',
        name: map['name'] as String? ?? '',
        sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'restaurantId': restaurantId,
        'name': name,
        'sortOrder': sortOrder,
      };
}

class MenuItem {
  final String id;
  final String restaurantId;
  final String categoryId;
  final String name;
  final String description;
  final double price;
  final String emoji;
  final bool isAvailable;
  final int? stockQuantity;
  final bool trackStock;
  final int totalSold;

  const MenuItem({
    required this.id,
    required this.restaurantId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.emoji,
    this.isAvailable = true,
    this.stockQuantity,
    this.trackStock = false,
    this.totalSold = 0,
  });

  bool get canOrder =>
      isAvailable && (!trackStock || (stockQuantity != null && stockQuantity! > 0));

  factory MenuItem.fromMap(Map<String, dynamic> map, String id) => MenuItem(
        id: id,
        restaurantId: map['restaurantId'] as String? ?? '',
        categoryId: map['categoryId'] as String? ?? '',
        name: map['name'] as String? ?? '',
        description: map['description'] as String? ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        emoji: map['emoji'] as String? ?? '🍽️',
        isAvailable: map['isAvailable'] as bool? ?? true,
        stockQuantity: (map['stockQuantity'] as num?)?.toInt(),
        trackStock: map['trackStock'] as bool? ?? false,
        totalSold: (map['totalSold'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'restaurantId': restaurantId,
        'categoryId': categoryId,
        'name': name,
        'description': description,
        'price': price,
        'emoji': emoji,
        'isAvailable': isAvailable,
        'stockQuantity': stockQuantity,
        'trackStock': trackStock,
        'totalSold': totalSold,
      };
}

class Driver {
  final String id;
  final String name;
  final String phone;
  final String vehicleType;
  final String vehiclePlate;
  final bool isAvailable;
  final bool isOnline;
  final double totalEarnings;
  final double pendingPayout;
  final int totalDeliveries;
  final double rating;
  final int ratingCount;
  final double? lat;
  final double? lng;
  final DateTime? lastLocationUpdate;

  const Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicleType,
    this.vehiclePlate = '',
    this.isAvailable = true,
    this.isOnline = false,
    this.totalEarnings = 0,
    this.pendingPayout = 0,
    this.totalDeliveries = 0,
    this.rating = 5.0,
    this.ratingCount = 0,
    this.lat,
    this.lng,
    this.lastLocationUpdate,
  });

  factory Driver.fromMap(Map<String, dynamic> map, String id) => Driver(
        id: id,
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        vehicleType: map['vehicleType'] as String? ?? 'دراجة نارية',
        vehiclePlate: map['vehiclePlate'] as String? ?? '',
        isAvailable: map['isAvailable'] as bool? ?? true,
        isOnline: map['isOnline'] as bool? ?? false,
        totalEarnings: (map['totalEarnings'] as num?)?.toDouble() ?? 0,
        pendingPayout: (map['pendingPayout'] as num?)?.toDouble() ?? 0,
        totalDeliveries: (map['totalDeliveries'] as num?)?.toInt() ?? 0,
        rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
        ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
        lat: (map['lat'] as num?)?.toDouble(),
        lng: (map['lng'] as num?)?.toDouble(),
        lastLocationUpdate: (map['lastLocationUpdate'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'vehicleType': vehicleType,
        'vehiclePlate': vehiclePlate,
        'isAvailable': isAvailable,
        'isOnline': isOnline,
        'totalEarnings': totalEarnings,
        'pendingPayout': pendingPayout,
        'totalDeliveries': totalDeliveries,
        'rating': rating,
        'ratingCount': ratingCount,
        'lat': lat,
        'lng': lng,
        if (lastLocationUpdate != null)
          'lastLocationUpdate': Timestamp.fromDate(lastLocationUpdate!),
      };
}

class OrderItem {
  final String menuItemId;
  final String name;
  final double price;
  final String emoji;
  final int quantity;
  final String? extras;

  const OrderItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.emoji,
    this.quantity = 1,
    this.extras,
  });

  double get subtotal => price * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        menuItemId: map['menuItemId'] as String? ?? '',
        name: map['name'] as String? ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        emoji: map['emoji'] as String? ?? '🍽️',
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
        extras: map['extras'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'menuItemId': menuItemId,
        'name': name,
        'price': price,
        'emoji': emoji,
        'quantity': quantity,
        if (extras != null) 'extras': extras,
      };
}

class Order {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final List<OrderItem> items;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final bool isPaid;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? driverId;
  final String? driverName;
  final String? notes;
  /// نصيب السائق من أجرة التوصيل لهذا الطلب (بدلاً من رقم رسوم توصيل واحد).
  final double driverShare;
  /// نصيب التطبيق/المنصة من أجرة التوصيل لهذا الطلب.
  final double appShare;
  final String orderNumber;
  final double? customerRating;
  final String? customerReview;
  final double? driverRating;
  final bool isRated;
  final double platformCommission;
  final double? deliveryLat;
  final double? deliveryLng;
  final double? restaurantLat;
  final double? restaurantLng;

  const Order({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.items,
    this.status = OrderStatus.pending,
    required this.paymentMethod,
    this.isPaid = false,
    required this.createdAt,
    this.updatedAt,
    this.driverId,
    this.driverName,
    this.notes,
    this.driverShare = 5.0,
    this.appShare = 0.0,
    required this.orderNumber,
    this.customerRating,
    this.customerReview,
    this.driverRating,
    this.isRated = false,
    this.platformCommission = 0,
    this.deliveryLat,
    this.deliveryLng,
    this.restaurantLat,
    this.restaurantLng,
  });

  /// إجمالي أجرة التوصيل (نصيب السائق + نصيب التطبيق) — للتوافق مع الحسابات
  /// السابقة التي كانت تعتمد رقماً واحداً.
  double get deliveryFee => driverShare + appShare;
  double get itemsTotal => items.fold(0.0, (s, i) => s + i.subtotal);
  double get grandTotal => itemsTotal + deliveryFee;
  /// عمولة التطبيق من المطعم — ١٥٪ من قيمة الوجبة (لا تشمل أجرة التوصيل).
  double get calculatedCommission => itemsTotal * 0.15;

  factory Order.fromMap(Map<String, dynamic> map, String id) => Order(
        id: id,
        restaurantId: map['restaurantId'] as String? ?? '',
        restaurantName: map['restaurantName'] as String? ?? '',
        customerId: map['customerId'] as String? ?? '',
        customerName: map['customerName'] as String? ?? '',
        customerPhone: map['customerPhone'] as String? ?? '',
        deliveryAddress: map['deliveryAddress'] as String? ?? '',
        items: ((map['items'] as List?) ?? [])
            .map((i) => OrderItem.fromMap(i as Map<String, dynamic>))
            .toList(),
        status: OrderStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => OrderStatus.pending,
        ),
        paymentMethod: PaymentMethod.values.firstWhere(
          (p) => p.name == map['paymentMethod'],
          orElse: () => PaymentMethod.cash,
        ),
        isPaid: map['isPaid'] as bool? ?? false,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
        driverId: map['driverId'] as String?,
        driverName: map['driverName'] as String?,
        notes: map['notes'] as String?,
        // توافق مع الطلبات القديمة التي كانت تخزّن deliveryFee كرقم واحد فقط.
        driverShare: (map['driverShare'] as num?)?.toDouble() ??
            (map['deliveryFee'] as num?)?.toDouble() ??
            5.0,
        appShare: (map['appShare'] as num?)?.toDouble() ?? 0.0,
        orderNumber: (map['orderNumber'] as String?) ?? id.substring(0, 6).toUpperCase(),
        customerRating: (map['customerRating'] as num?)?.toDouble(),
        customerReview: map['customerReview'] as String?,
        driverRating: (map['driverRating'] as num?)?.toDouble(),
        isRated: map['isRated'] as bool? ?? false,
        platformCommission: (map['platformCommission'] as num?)?.toDouble() ?? 0,
        deliveryLat: (map['deliveryLat'] as num?)?.toDouble(),
        deliveryLng: (map['deliveryLng'] as num?)?.toDouble(),
        restaurantLat: (map['restaurantLat'] as num?)?.toDouble(),
        restaurantLng: (map['restaurantLng'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'deliveryAddress': deliveryAddress,
        'items': items.map((i) => i.toMap()).toList(),
        'status': status.name,
        'paymentMethod': paymentMethod.name,
        'isPaid': isPaid,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'driverId': driverId,
        'driverName': driverName,
        'notes': notes,
        'driverShare': driverShare,
        'appShare': appShare,
        // نُبقي على الحقل القديم مؤقتاً لتوافق النسخ الأقدم من التطبيق.
        'deliveryFee': deliveryFee,
        'orderNumber': orderNumber,
        'customerRating': customerRating,
        'customerReview': customerReview,
        'driverRating': driverRating,
        'isRated': isRated,
        'platformCommission': platformCommission,
        'deliveryLat': deliveryLat,
        'deliveryLng': deliveryLng,
        'restaurantLat': restaurantLat,
        'restaurantLng': restaurantLng,
      };
}

class Complaint {
  final String id;
  final String orderId;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String restaurantId;
  final String restaurantName;
  final ComplaintType type;
  final String description;
  final ComplaintStatus status;
  final DateTime createdAt;
  final String? adminNote;

  const Complaint({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    this.restaurantId = '',
    this.restaurantName = '',
    required this.type,
    required this.description,
    this.status = ComplaintStatus.open,
    required this.createdAt,
    this.adminNote,
  });

  factory Complaint.fromMap(Map<String, dynamic> map, String id) => Complaint(
        id: id,
        orderId: map['orderId'] as String? ?? '',
        orderNumber: map['orderNumber'] as String? ?? '',
        customerId: map['customerId'] as String? ?? '',
        customerName: map['customerName'] as String? ?? '',
        restaurantId: map['restaurantId'] as String? ?? '',
        restaurantName: map['restaurantName'] as String? ?? '',
        type: ComplaintType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => ComplaintType.other,
        ),
        description: map['description'] as String? ?? '',
        status: ComplaintStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => ComplaintStatus.open,
        ),
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        adminNote: map['adminNote'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'orderNumber': orderNumber,
        'customerId': customerId,
        'customerName': customerName,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'type': type.name,
        'description': description,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'adminNote': adminNote,
      };
}

class ChatMessage {
  final String id;
  final String orderId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String text;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) => ChatMessage(
        id: id,
        orderId: map['orderId'] as String? ?? '',
        senderId: map['senderId'] as String? ?? '',
        senderName: map['senderName'] as String? ?? '',
        senderRole: map['senderRole'] as String? ?? '',
        text: map['text'] as String? ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

class CartItem {
  final MenuItem item;
  int quantity;
  String? extras;
  CartItem({required this.item, this.quantity = 1, this.extras});
  double get subtotal => item.price * quantity;
}

class DriverReassignment {
  final String id;
  final String orderId;
  final String orderNumber;
  final String? oldDriverId;
  final String? oldDriverName;
  final String newDriverId;
  final String newDriverName;
  final String reason;
  final String performedBy;
  final DateTime createdAt;

  const DriverReassignment({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    this.oldDriverId,
    this.oldDriverName,
    required this.newDriverId,
    required this.newDriverName,
    required this.reason,
    required this.performedBy,
    required this.createdAt,
  });

  factory DriverReassignment.fromMap(Map<String, dynamic> map, String id) => DriverReassignment(
        id: id,
        orderId: map['orderId'] as String? ?? '',
        orderNumber: map['orderNumber'] as String? ?? '',
        oldDriverId: map['oldDriverId'] as String?,
        oldDriverName: map['oldDriverName'] as String?,
        newDriverId: map['newDriverId'] as String? ?? '',
        newDriverName: map['newDriverName'] as String? ?? '',
        reason: map['reason'] as String? ?? '',
        performedBy: map['performedBy'] as String? ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'orderNumber': orderNumber,
        if (oldDriverId != null) 'oldDriverId': oldDriverId,
        if (oldDriverName != null) 'oldDriverName': oldDriverName,
        'newDriverId': newDriverId,
        'newDriverName': newDriverName,
        'reason': reason,
        'performedBy': performedBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

/// جمهور الرسالة الجماعية (البث): كل السائقين أو كل العملاء، كل مجموعة منفصلة
/// تماماً عن الأخرى ولا علاقة لها بدردشة الطلب بين العميل والسائق.
enum BroadcastAudience { drivers, customers }

class BroadcastMessage {
  final String id;
  final BroadcastAudience audience;
  final String title;
  final String body;
  final String sentBy;
  final DateTime createdAt;

  const BroadcastMessage({
    required this.id,
    required this.audience,
    required this.title,
    required this.body,
    required this.sentBy,
    required this.createdAt,
  });

  factory BroadcastMessage.fromMap(Map<String, dynamic> map, String id) => BroadcastMessage(
        id: id,
        audience: BroadcastAudience.values.firstWhere(
          (a) => a.name == map['audience'],
          orElse: () => BroadcastAudience.customers,
        ),
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        sentBy: map['sentBy'] as String? ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'audience': audience.name,
        'title': title,
        'body': body,
        'sentBy': sentBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

/// رمز تسجيل يُصدره المدير العام ويرتبط بمطعم محدد — يُرسل يدوياً لمدير
/// المطعم المستهدف، ويُستخدم مرة واحدة فقط للتسجيل الذاتي عبر شاشة
/// "التسجيل بمدير مطعم" بدلاً من إنشاء المدير العام للحساب مباشرة.
class RestaurantRegistrationCode {
  final String code;
  final String restaurantId;
  final String restaurantName;
  final bool isUsed;
  final DateTime createdAt;
  final DateTime? usedAt;
  final String? usedByUid;
  final String? usedByName;

  const RestaurantRegistrationCode({
    required this.code,
    required this.restaurantId,
    required this.restaurantName,
    this.isUsed = false,
    required this.createdAt,
    this.usedAt,
    this.usedByUid,
    this.usedByName,
  });

  factory RestaurantRegistrationCode.fromMap(Map<String, dynamic> map, String id) =>
      RestaurantRegistrationCode(
        code: map['code'] as String? ?? id,
        restaurantId: map['restaurantId'] as String? ?? '',
        restaurantName: map['restaurantName'] as String? ?? '',
        isUsed: map['isUsed'] as bool? ?? false,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        usedAt: (map['usedAt'] as Timestamp?)?.toDate(),
        usedByUid: map['usedByUid'] as String?,
        usedByName: map['usedByName'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'code': code,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'isUsed': isUsed,
        'createdAt': Timestamp.fromDate(createdAt),
        'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
        'usedByUid': usedByUid,
        'usedByName': usedByName,
      };
}
