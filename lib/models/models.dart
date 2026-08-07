// lib/models/models.dart
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';

enum UserRole { admin, customer, driver, restaurantManager }

enum OrderStatus {
  created,
  restaurantPending,
  restaurantAccepted,
  preparing,
  readyForPickup,
  searchingDriver,
  driverAssigned,
  pickedUp,
  onTheWay,
  delivered,
  restaurantRejected,
  noDriverFound,
  cancelled,
  refunded,
}

enum PaymentMethod { cash, card, wallet }

enum ComplaintStatus { open, inProgress, resolved, closed }

/// أنواع الشكاوى — موسَّعة لتغطي الأطراف الثلاثة (عميل/سائق/مطعم) معاً. القيم
/// القديمة (lateDelivery, wrongOrder, badQuality, driverBehavior, other) أُبقيت
/// كما هي بلا حذف، فأي شكوى قديمة محفوظة بها في Firestore تبقى صالحة تماماً؛
/// الأنواع الجديدة أُضيفت فقط بجانبها. أي دور يرى الأنواع الخاصة به عبر
/// [ComplaintTypeScope.typesForRole] لا القائمة كاملة.
enum ComplaintType {
  // أنواع العميل (ضد السائق أو المطعم)
  lateDelivery,
  wrongOrder,
  badQuality,
  driverBehavior,
  unclearFees,

  // أنواع السائق (ضد العميل أو المطعم)
  customerNotResponding,
  wrongAddress,
  restaurantDelay,
  customerBehavior,
  orderMismatch,

  // أنواع المطعم (ضد السائق أو العميل)
  driverNotPickedUp,
  driverLateForPickup,
  customerCancelledAfterPrep,
  driverBehaviorAtRestaurant,

  other,
}

T _enumValueFromString<T extends Enum>(
  String? raw,
  List<T> values,
  T fallback,
  String enumName, {
  Map<String, T>? legacyValues,
}) {
  if (raw != null) {
    final legacyMatch = legacyValues?[raw];
    if (legacyMatch != null) return legacyMatch;
    for (final value in values) {
      if (value.name == raw) return value;
    }
  }
  debugPrint('⚠️ قيمة غير معروفة لـ $enumName: "$raw"، سيتم استخدام ${fallback.name}');
  return fallback;
}

OrderStatus _orderStatusFromString(String? raw) => _enumValueFromString<OrderStatus>(
      raw,
      OrderStatus.values,
      OrderStatus.created,
      'OrderStatus',
      legacyValues: const {
        'pending': OrderStatus.restaurantPending,
        'confirmed': OrderStatus.restaurantAccepted,
        'preparing': OrderStatus.preparing,
        'readyForPickup': OrderStatus.readyForPickup,
        'outForDelivery': OrderStatus.onTheWay,
        'delivered': OrderStatus.delivered,
        'cancelled': OrderStatus.cancelled,
        'rejected': OrderStatus.restaurantRejected,
      },
    );

UserRole _userRoleFromString(String? raw, {UserRole fallback = UserRole.customer}) =>
    _enumValueFromString<UserRole>(raw, UserRole.values, fallback, 'UserRole');

PaymentMethod _paymentMethodFromString(String? raw) => _enumValueFromString<PaymentMethod>(
      raw,
      PaymentMethod.values,
      PaymentMethod.cash,
      'PaymentMethod',
    );

ComplaintType _complaintTypeFromString(String? raw) => _enumValueFromString<ComplaintType>(
      raw,
      ComplaintType.values,
      ComplaintType.other,
      'ComplaintType',
    );

ComplaintStatus _complaintStatusFromString(String? raw) => _enumValueFromString<ComplaintStatus>(
      raw,
      ComplaintStatus.values,
      ComplaintStatus.open,
      'ComplaintStatus',
    );

BroadcastAudience _broadcastAudienceFromString(String? raw) =>
    _enumValueFromString<BroadcastAudience>(
      raw,
      BroadcastAudience.values,
      BroadcastAudience.customers,
      'BroadcastAudience',
    );

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
      OrderStatus.created: 'تم الإنشاء',
      OrderStatus.restaurantPending: 'بانتظار موافقة المطعم',
      OrderStatus.restaurantAccepted: 'تم قبول الطلب',
      OrderStatus.preparing: 'جاري التحضير',
      OrderStatus.readyForPickup: 'جاهز للاستلام',
      OrderStatus.searchingDriver: 'جاري البحث عن سائق',
      OrderStatus.driverAssigned: 'تم تعيين سائق',
      OrderStatus.pickedUp: 'تم استلام الطلب من المطعم',
      OrderStatus.onTheWay: 'في الطريق إليك',
      OrderStatus.delivered: 'تم التوصيل',
      OrderStatus.restaurantRejected: 'رفض المطعم الطلب',
      OrderStatus.noDriverFound: 'تعذر إيجاد سائق',
      OrderStatus.cancelled: 'ملغى',
      OrderStatus.refunded: 'تم استرداد المبلغ',
    };
    return map[this] ?? '';
  }

  Color get color {
    const map = {
      OrderStatus.created: Color(0xFF607D8B),
      OrderStatus.restaurantPending: Color(0xFFFF9800),
      OrderStatus.restaurantAccepted: Color(0xFF2196F3),
      OrderStatus.preparing: Color(0xFF9C27B0),
      OrderStatus.readyForPickup: Color(0xFF00BCD4),
      OrderStatus.searchingDriver: Color(0xFFFFC107),
      OrderStatus.driverAssigned: Color(0xFF3F51B5),
      OrderStatus.pickedUp: Color(0xFF673AB7),
      OrderStatus.onTheWay: Color(0xFF303F9F),
      OrderStatus.delivered: Color(0xFF4CAF50),
      OrderStatus.restaurantRejected: Color(0xFF795548),
      OrderStatus.noDriverFound: Color(0xFF9E9E9E),
      OrderStatus.cancelled: Color(0xFFF44336),
      OrderStatus.refunded: Color(0xFF009688),
    };
    return map[this] ?? Colors.grey;
  }

  IconData get icon {
    const map = {
      OrderStatus.created: Icons.receipt_long_rounded,
      OrderStatus.restaurantPending: Icons.hourglass_empty_rounded,
      OrderStatus.restaurantAccepted: Icons.check_circle_rounded,
      OrderStatus.preparing: Icons.restaurant_rounded,
      OrderStatus.readyForPickup: Icons.shopping_bag_rounded,
      OrderStatus.searchingDriver: Icons.manage_search_rounded,
      OrderStatus.driverAssigned: Icons.person_pin_circle_rounded,
      OrderStatus.pickedUp: Icons.inventory_2_rounded,
      OrderStatus.onTheWay: Icons.delivery_dining_rounded,
      OrderStatus.delivered: Icons.done_all_rounded,
      OrderStatus.restaurantRejected: Icons.block_rounded,
      OrderStatus.noDriverFound: Icons.person_off_rounded,
      OrderStatus.cancelled: Icons.cancel_rounded,
      OrderStatus.refunded: Icons.replay_circle_filled_rounded,
    };
    return map[this] ?? Icons.info_outline;
  }

  bool get isActive =>
      this != OrderStatus.delivered &&
      this != OrderStatus.restaurantRejected &&
      this != OrderStatus.noDriverFound &&
      this != OrderStatus.cancelled &&
      this != OrderStatus.refunded;

  bool get isFinished => !isActive;

  bool get isRestaurantResponsibility =>
      this == OrderStatus.created ||
      this == OrderStatus.restaurantPending ||
      this == OrderStatus.restaurantAccepted ||
      this == OrderStatus.preparing ||
      this == OrderStatus.readyForPickup;
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
      // أنواع العميل
      ComplaintType.lateDelivery: 'تأخر التوصيل',
      ComplaintType.wrongOrder: 'طلب ناقص أو خاطئ',
      ComplaintType.badQuality: 'جودة الطعام',
      ComplaintType.driverBehavior: 'سلوك السائق',
      ComplaintType.unclearFees: 'رسوم/سعر غير واضح',
      // أنواع السائق
      ComplaintType.customerNotResponding: 'عميل لا يرد على الاتصال',
      ComplaintType.wrongAddress: 'عنوان خاطئ أو غير واضح',
      ComplaintType.restaurantDelay: 'تأخر المطعم في التحضير',
      ComplaintType.customerBehavior: 'سلوك العميل عند الاستلام',
      ComplaintType.orderMismatch: 'طلب غير مطابق لما استُلم',
      // أنواع المطعم
      ComplaintType.driverNotPickedUp: 'سائق لم يستلم الطلب في الوقت',
      ComplaintType.driverLateForPickup: 'سائق تأخر عن الاستلام رغم الجاهزية',
      ComplaintType.customerCancelledAfterPrep: 'عميل ألغى بعد التحضير',
      ComplaintType.driverBehaviorAtRestaurant: 'سلوك السائق داخل المطعم',
      ComplaintType.other: 'أخرى',
    };
    return map[this] ?? '';
  }
}

/// يربط كل دور بأنواع الشكاوى التي يحق له رفعها، ومصدرٌ واحدٌ للحقيقة تعتمده
/// شاشة تقديم الشكوى لبناء قائمة الأنواع ديناميكياً حسب دور المُقدِّم — بدل
/// تكرار القوائم في عدة شاشات. النوع [ComplaintType.other] متاح لكل الأدوار.
extension ComplaintTypeScope on ComplaintType {
  static const Map<UserRole, List<ComplaintType>> _byRole = {
    UserRole.customer: [
      ComplaintType.lateDelivery,
      ComplaintType.wrongOrder,
      ComplaintType.badQuality,
      ComplaintType.driverBehavior,
      ComplaintType.unclearFees,
      ComplaintType.other,
    ],
    UserRole.driver: [
      ComplaintType.customerNotResponding,
      ComplaintType.wrongAddress,
      ComplaintType.restaurantDelay,
      ComplaintType.customerBehavior,
      ComplaintType.orderMismatch,
      ComplaintType.other,
    ],
    UserRole.restaurantManager: [
      ComplaintType.driverNotPickedUp,
      ComplaintType.driverLateForPickup,
      ComplaintType.customerCancelledAfterPrep,
      ComplaintType.driverBehaviorAtRestaurant,
      ComplaintType.other,
    ],
  };

  /// أنواع الشكاوى المتاحة لدورٍ معيّن؛ المدير العام يرى كل الأنواع (لأنه قد
  /// يسجّل شكوى نيابةً عن أي طرف)، وأي دور غير مُعرَّف يسقط إلى [other] فقط.
  static List<ComplaintType> typesForRole(UserRole role) {
    if (role == UserRole.admin) return ComplaintType.values;
    return _byRole[role] ?? const [ComplaintType.other];
  }

  /// الطرف المنطقي الذي تُوجَّه ضده الشكوى افتراضياً حسب نوعها — تستخدمه شاشة
  /// تقديم الشكوى لاختيار «الشكوى ضد» تلقائياً بدل ترك المستخدم يخمّن. `null`
  /// يعني شكوى عامة عن الطلب (لا طرف محدد)، كما في [ComplaintType.other].
  UserRole? get suggestedAgainstRole {
    switch (this) {
      // شكاوى العميل
      case ComplaintType.driverBehavior:
      case ComplaintType.lateDelivery:
        return UserRole.driver;
      case ComplaintType.wrongOrder:
      case ComplaintType.badQuality:
      case ComplaintType.unclearFees:
        return UserRole.restaurantManager;
      // شكاوى السائق
      case ComplaintType.customerNotResponding:
      case ComplaintType.wrongAddress:
      case ComplaintType.customerBehavior:
        return UserRole.customer;
      case ComplaintType.restaurantDelay:
      case ComplaintType.orderMismatch:
        return UserRole.restaurantManager;
      // شكاوى المطعم
      case ComplaintType.driverNotPickedUp:
      case ComplaintType.driverLateForPickup:
      case ComplaintType.driverBehaviorAtRestaurant:
        return UserRole.driver;
      case ComplaintType.customerCancelledAfterPrep:
        return UserRole.customer;
      case ComplaintType.other:
        return null;
    }
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
  final String? nationalId;

  /// رصيد محفظة العميل الداخلي — يُضاف إليه أي استرداد جزئي يقرره المدير
  /// عند حل شكوى، ويُستخدَم تلقائياً كخصم في الطلب القادم. لا علاقة له
  /// بأي بوابة دفع خارجية؛ هو رصيد داخلي بسيط ضمن Firestore فقط.
  final double walletBalance;

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
    this.nationalId,
    this.walletBalance = 0.0,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) => AppUser(
        uid: uid,
        name: map['name'] as String? ?? '',
        email: map['email'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        role: _userRoleFromString(map['role'] as String?),
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        fcmToken: map['fcmToken'] as String?,
        restaurantId: map['restaurantId'] as String?,
        restaurantName: map['restaurantName'] as String?,
        isActive: map['isActive'] as bool? ?? true,
        nationalId: map['nationalId'] as String?,
        walletBalance: (map['walletBalance'] as num?)?.toDouble() ?? 0.0,
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
        if (nationalId != null) 'nationalId': nationalId,
        'isActive': isActive,
        'walletBalance': walletBalance,
      };

  AppUser copyWith({
    String? name,
    String? phone,
    UserRole? role,
    String? restaurantId,
    String? restaurantName,
    bool? isActive,
    String? nationalId,
    double? walletBalance,
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
        nationalId: nationalId ?? this.nationalId,
        walletBalance: walletBalance ?? this.walletBalance,
      );
}

class Restaurant {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final String phone;
  final bool isOpen;
  final double driverShareFee;
  final double appShareFee;
  final double perKmFee;
  final double freeKm;
  final double minOrder;
  final String address;
  final int estimatedTimeMin;
  final double rating;
  final int totalOrders;
  final double? lat;
  final double? lng;
  final String? imageUrl;

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
    this.imageUrl,
  });

  double get deliveryFee => driverShareFee + appShareFee;

  factory Restaurant.fromMap(Map<String, dynamic> map, String id) =>
      Restaurant(
        id: id,
        name: map['name'] as String? ?? '',
        description: map['description'] as String? ?? '',
        emoji: map['emoji'] as String? ?? '🍽️',
        phone: map['phone'] as String? ?? '',
        isOpen: map['isOpen'] as bool? ?? true,
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
        imageUrl: map['imageUrl'] as String?,
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
        'deliveryFee': deliveryFee,
        'minOrder': minOrder,
        'address': address,
        'estimatedTimeMin': estimatedTimeMin,
        'rating': rating,
        'totalOrders': totalOrders,
        'lat': lat,
        'lng': lng,
        'imageUrl': imageUrl,
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
  final String? imageUrl;

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
    this.imageUrl,
  });

  bool get canOrder =>
      isAvailable && (!trackStock || (stockQuantity != null && stockQuantity! > 0));

  factory MenuItem.fromMap(Map<String, dynamic> map, String id) {
    final rawPrice = map['price'];
    final price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '') ?? 0.0;
    final rawImageUrl = map['imageUrl'];
    final imageUrl = rawImageUrl is String && rawImageUrl.trim().isNotEmpty
        ? rawImageUrl
        : null;
    return MenuItem(
      id: id,
      restaurantId: map['restaurantId'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: price,
      emoji: map['emoji'] as String? ?? '🍽️',
      isAvailable: map['isAvailable'] as bool? ?? true,
      stockQuantity: (map['stockQuantity'] as num?)?.toInt(),
      trackStock: map['trackStock'] as bool? ?? false,
      totalSold: (map['totalSold'] as num?)?.toInt() ?? 0,
      imageUrl: imageUrl,
    );
  }

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
        'imageUrl': imageUrl,
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

  /// عدد الإنذارات التراكمية الناتجة عن حل شكاوى ضد هذا السائق. عند
  /// وصولها لحد معيّن (3 حالياً)، يُعلَّق السائق تلقائياً (isAvailable
  /// تتحول false بشكل دائم) حتى يتواصل معه المدير — بنفس منطق "مخالفات
  /// العقد" (contract violations) المعتمد في تطبيقات التوصيل الكبرى.
  final int warningCount;

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
    this.warningCount = 0,
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
        warningCount: (map['warningCount'] as num?)?.toInt() ?? 0,
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
        'warningCount': warningCount,
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
  final DateTime? statusChangedAt;
  final String? driverId;
  final String? driverName;
  /// هاتف السائق المُسنَد — يُنسخ في الطلب عند الإسناد ليتمكّن العميل من
  /// الاتصال به مباشرةً دون قراءة مستند السائق (لا يملك صلاحية ذلك).
  final String? driverPhone;
  final String? notes;
  final double driverShare;
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
  final String? rejectionReason;
  final bool driverAcknowledged;

  const Order({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.items,
    this.status = OrderStatus.restaurantPending,
    required this.paymentMethod,
    this.isPaid = false,
    required this.createdAt,
    this.updatedAt,
    this.statusChangedAt,
    this.driverId,
    this.driverName,
    this.driverPhone,
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
    this.rejectionReason,
    this.driverAcknowledged = true,
  });

  double get deliveryFee => driverShare + appShare;
  double get itemsTotal => items.fold(0.0, (s, i) => s + i.subtotal);
  double get grandTotal => itemsTotal + deliveryFee;
  double get calculatedCommission => itemsTotal * 0.15;

  /// صافي مستحقّات المطعم = قيمة الوجبات بعد خصم عمولة التطبيق (15%). قيمة
  /// الطلب للعميل تساوي قيمته للمطعم؛ العمولة تُخصم من المطعم في التقارير.
  double get restaurantNet => itemsTotal - platformCommission;

  /// مهلة تقديم الشكوى بعد انتهاء الطلب — 24 ساعة، وهي النافذة المعتمدة في
  /// تطبيقات التوصيل الكبرى: تكفي لاكتشاف النقص/الخطأ/الجودة بعد فتح الطلب،
  /// ثم يُغلق الملف تلقائياً فلا تبقى الطلبات القديمة مفتوحة للشكاوى للأبد.
  static const Duration complaintWindow = Duration(hours: 24);

  /// اللحظة التي انتهى فيها الطلب (تسليم/إلغاء/رفض)؛ [statusChangedAt] يُحدَّث
  /// عند كل تغيير حالة، فهو وقت الانتهاء للطلبات المنتهية.
  DateTime get _finishedAt => statusChangedAt ?? updatedAt ?? createdAt;

  /// ما تبقّى من مهلة الشكوى؛ `null` للطلبات الجارية (بلا مهلة بعد).
  Duration? get complaintTimeLeft {
    if (status.isActive) return null;
    final left = _finishedAt.add(complaintWindow).difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// هل يمكن تقديم شكوى على هذا الطلب الآن؟ الطلبات الجارية دائماً مفتوحة،
  /// والمنتهية مفتوحة خلال [complaintWindow] من لحظة انتهائها فقط.
  bool get canSubmitComplaint =>
      status.isActive || (complaintTimeLeft ?? Duration.zero) > Duration.zero;

  /// هل يحقّ للعميل إلغاء الطلب بنفسه؟ مسموح فقط قبل أن يبدأ المطعم التحضير
  /// فعلياً — أي قبل الإرسال، وأثناء انتظار موافقة المطعم، وبعد قبوله مباشرةً.
  /// بمجرّد الانتقال إلى [OrderStatus.preparing] يكون المطعم قد بدأ يتكبّد
  /// تكلفة الطعام، فيصبح الإلغاء قراراً إدارياً فقط (من لوحة التحكم).
  bool get canCustomerCancel =>
      status == OrderStatus.created ||
      status == OrderStatus.restaurantPending ||
      status == OrderStatus.restaurantAccepted;

  bool get needsDriverAcknowledgement =>
      driverId != null && driverId!.isNotEmpty && !driverAcknowledged;

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
        status: _orderStatusFromString(map['status'] as String?),
        paymentMethod: _paymentMethodFromString(map['paymentMethod'] as String?),
        isPaid: map['isPaid'] as bool? ?? false,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
        statusChangedAt: (map['statusChangedAt'] as Timestamp?)?.toDate(),
        driverId: map['driverId'] as String?,
        driverName: map['driverName'] as String?,
        driverPhone: map['driverPhone'] as String?,
        notes: map['notes'] as String?,
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
        rejectionReason: map['rejectionReason'] as String?,
        driverAcknowledged: map['driverAcknowledged'] as bool? ?? true,
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
        'statusChangedAt':
            statusChangedAt != null ? Timestamp.fromDate(statusChangedAt!) : null,
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'notes': notes,
        'driverShare': driverShare,
        'appShare': appShare,
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
        'rejectionReason': rejectionReason,
        'driverAcknowledged': driverAcknowledged,
      };

  Order copyWith({
    OrderStatus? status,
    DateTime? updatedAt,
    DateTime? statusChangedAt,
    String? driverId,
    String? driverName,
    String? driverPhone,
    bool? isPaid,
    double? platformCommission,
    double? customerRating,
    String? customerReview,
    double? driverRating,
    bool? isRated,
    String? rejectionReason,
    bool? driverAcknowledged,
  }) =>
      Order(
        id: id,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        deliveryAddress: deliveryAddress,
        items: items,
        status: status ?? this.status,
        paymentMethod: paymentMethod,
        isPaid: isPaid ?? this.isPaid,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        statusChangedAt: statusChangedAt ?? this.statusChangedAt,
        driverId: driverId ?? this.driverId,
        driverName: driverName ?? this.driverName,
        driverPhone: driverPhone ?? this.driverPhone,
        notes: notes,
        driverShare: driverShare,
        appShare: appShare,
        orderNumber: orderNumber,
        customerRating: customerRating ?? this.customerRating,
        customerReview: customerReview ?? this.customerReview,
        driverRating: driverRating ?? this.driverRating,
        isRated: isRated ?? this.isRated,
        platformCommission: platformCommission ?? this.platformCommission,
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
        restaurantLat: restaurantLat,
        restaurantLng: restaurantLng,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        driverAcknowledged: driverAcknowledged ?? this.driverAcknowledged,
      );
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

  final String submittedByUid;
  final String submittedByName;
  final UserRole submittedByRole;

  final String? againstUid;
  final UserRole? againstRole;

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
    String? submittedByUid,
    String? submittedByName,
    UserRole? submittedByRole,
    this.againstUid,
    this.againstRole,
  })  : submittedByUid = submittedByUid ?? customerId,
        submittedByName = submittedByName ?? customerName,
        submittedByRole = submittedByRole ?? UserRole.customer;

  factory Complaint.fromMap(Map<String, dynamic> map, String id) {
    final customerId = map['customerId'] as String? ?? '';
    final customerName = map['customerName'] as String? ?? '';
    return Complaint(
      id: id,
      orderId: map['orderId'] as String? ?? '',
      orderNumber: map['orderNumber'] as String? ?? '',
      customerId: customerId,
      customerName: customerName,
      restaurantId: map['restaurantId'] as String? ?? '',
      restaurantName: map['restaurantName'] as String? ?? '',
      type: _complaintTypeFromString(map['type'] as String?),
      description: map['description'] as String? ?? '',
      status: _complaintStatusFromString(map['status'] as String?),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      adminNote: map['adminNote'] as String?,
      submittedByUid: (map['submittedByUid'] as String?) ?? customerId,
      submittedByName: (map['submittedByName'] as String?) ?? customerName,
      submittedByRole: map['submittedByRole'] != null
          ? _userRoleFromString(map['submittedByRole'] as String?)
          : UserRole.customer,
      againstUid: map['againstUid'] as String?,
      againstRole: map['againstRole'] != null
          ? _userRoleFromString(map['againstRole'] as String?)
          : null,
    );
  }

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
        'submittedByUid': submittedByUid,
        'submittedByName': submittedByName,
        'submittedByRole': submittedByRole.name,
        if (againstUid != null) 'againstUid': againstUid,
        if (againstRole != null) 'againstRole': againstRole!.name,
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
        audience: _broadcastAudienceFromString(map['audience'] as String?),
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

class RegistrationCode {
  final String code;
  final UserRole role;
  final String restaurantId;
  final String restaurantName;
  final bool isUsed;
  final DateTime createdAt;
  final DateTime? usedAt;
  final String? usedByUid;
  final String? usedByName;

  const RegistrationCode({
    required this.code,
    required this.role,
    this.restaurantId = '',
    this.restaurantName = '',
    this.isUsed = false,
    required this.createdAt,
    this.usedAt,
    this.usedByUid,
    this.usedByName,
  });

  factory RegistrationCode.fromMap(Map<String, dynamic> map, String id) =>
      RegistrationCode(
        code: map['code'] as String? ?? id,
        role: _userRoleFromString(
          map['role'] as String?,
          fallback: UserRole.restaurantManager,
        ),
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
        'role': role.name,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'isUsed': isUsed,
        'createdAt': Timestamp.fromDate(createdAt),
        'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
        'usedByUid': usedByUid,
        'usedByName': usedByName,
      };
}