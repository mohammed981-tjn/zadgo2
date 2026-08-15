// lib/models/models.dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
// قواعد التسعير المعتمدة — يستعملها النموذج في المشتقّات المالية للتقارير.
// helpers لا يستورد models، فلا دورة استيراد.
import '../utils/helpers.dart' show Pricing;

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

  // أنواع التذاكر العامة (بلا ارتباط بطلب — لكل الأدوار)
  financial,
  dataUpdate,
  generalInquiry,

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
      // التذاكر العامة
      ComplaintType.financial: 'مالية — مستحقّات/محفظة',
      ComplaintType.dataUpdate: 'تحديث بيانات',
      ComplaintType.generalInquiry: 'استفسار عام',
      ComplaintType.other: 'أخرى',
    };
    return map[this] ?? '';
  }
}

/// أنواع التذاكر العامة — تُفتح بلا ارتباط بطلب، ومتاحة لكل الأدوار.
const List<ComplaintType> generalTicketTypes = [
  ComplaintType.financial,
  ComplaintType.dataUpdate,
  ComplaintType.generalInquiry,
  ComplaintType.other,
];

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
      // التذاكر العامة — موجّهة للإدارة نفسها، لا ضد طرف.
      case ComplaintType.financial:
      case ComplaintType.dataUpdate:
      case ComplaintType.generalInquiry:
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

/// عنوان محفوظ للعميل (منزل/عمل/مخصّص) — يُخزَّن ضمن مستند المستخدم نفسه لا
/// في مجموعة فرعية، فيُقرأ مع بيانات الحساب في نفس الطلب بلا استعلام إضافي،
/// ولا يحتاج قاعدة أمان جديدة (تحديثه جزء من تحديث المستخدم لبياناته).
class SavedAddress {
  final String label;
  final String address;
  final double? lat;
  final double? lng;

  const SavedAddress({
    required this.label,
    required this.address,
    this.lat,
    this.lng,
  });

  factory SavedAddress.fromMap(Map<String, dynamic> map) => SavedAddress(
        label: map['label'] as String? ?? '',
        address: map['address'] as String? ?? '',
        lat: (map['lat'] as num?)?.toDouble(),
        lng: (map['lng'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'label': label,
        'address': address,
        'lat': lat,
        'lng': lng,
      };

  /// عنوان بلا إحداثيات لا يصلح للطلب، لأن أجرة التوصيل تُحسب من المسافة.
  bool get hasLocation => lat != null && lng != null;
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
  final List<SavedAddress> savedAddresses;

  /// مطاعم العميل المفضلة (ح2) — معرّفات فقط في مستنده هو: قلبٌ يضغطه
  /// فيظهر مطعمه تحت شريحة «المفضلة». مصفوفة لا مجموعة منفصلة: بضع
  /// عشرات معرّفاً في أسوأ حال، وقاعدة المستخدم القائمة تحميها.
  final List<String> favoriteRestaurantIds;

  /// كود التسجيل الذي مُنح به هذا الدور — يُكتب لحظة الإنشاء ليتحقّق منه
  /// حارس القواعد. بدونه كان أي مستخدم يُنشئ مستنده بدور `admin` فيصير
  /// مديراً عاماً على كل شيء (القاعدة كانت تفحص الرصيد ولا تفحص الدور).
  /// فارغ لحسابات العملاء — دور العميل لا يحتاج كوداً.
  final String registrationCode;

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
    this.savedAddresses = const [],
    this.favoriteRestaurantIds = const [],
    this.registrationCode = '',
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
        savedAddresses: ((map['savedAddresses'] as List?) ?? [])
            .map((e) => SavedAddress.fromMap((e as Map).cast<String, dynamic>()))
            .toList(),
        favoriteRestaurantIds: ((map['favoriteRestaurantIds'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
        registrationCode: map['registrationCode'] as String? ?? '',
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
        'savedAddresses': savedAddresses.map((a) => a.toMap()).toList(),
        'favoriteRestaurantIds': favoriteRestaurantIds,
        'registrationCode': registrationCode,
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
    List<SavedAddress>? savedAddresses,
    List<String>? favoriteRestaurantIds,
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
        savedAddresses: savedAddresses ?? this.savedAddresses,
        favoriteRestaurantIds:
            favoriteRestaurantIds ?? this.favoriteRestaurantIds,
      );
}

/// قائمة المطابخ المعتمدة (ح8 — تصنيف كيتا): تُعرض للعميل في ورقة
/// «المطابخ» وللمدير في نموذج المطعم اختياراً متعدداً. قائمة واحدة
/// للطرفين كي لا يصنّف المديرُ بمسمى لا يراه العميل.
const kCuisines = [
  'سعودي', 'مشاوي', 'مندي وحنيذ', 'برجر', 'دجاج مقلي', 'شاورما',
  'ساندويتشات', 'بيتزا', 'إيطالي ومكرونة', 'لبناني', 'سوري', 'مصري',
  'هندي', 'فطائر ومعجنات', 'مخبوزات', 'فلافل', 'سلطات وصحي',
  'حلويات', 'عصائر', 'قهوة وشاي',
];

/// جدول عمل يومٍ واحد للمطعم (ساعات العمل المجدولة — أبرز فجوة قبل
/// الإطلاق: كان `isOpen` مفتاحاً يدوياً فقط، فيبقى المطعم «مفتوحاً» ليلاً
/// ما لم يُطفئه أحد، فيطلب العميل من مطعمٍ نائم). الوقت "HH:mm" بنظام ٢٤
/// ساعة. `closed=true` يعني اليوم مغلق كلياً. ويدعم ما بعد منتصف الليل:
/// إغلاقٌ أبكر من الفتح (16:00→02:00) يعني الامتداد لليوم التالي.
class DaySchedule {
  final bool closed;
  final String open;
  final String close;

  const DaySchedule({
    this.closed = false,
    this.open = '09:00',
    this.close = '23:00',
  });

  factory DaySchedule.fromMap(Map<String, dynamic> map) => DaySchedule(
        closed: map['closed'] as bool? ?? false,
        open: map['open'] as String? ?? '09:00',
        close: map['close'] as String? ?? '23:00',
      );

  Map<String, dynamic> toMap() =>
      {'closed': closed, 'open': open, 'close': close};

  DaySchedule copyWith({bool? closed, String? open, String? close}) =>
      DaySchedule(
        closed: closed ?? this.closed,
        open: open ?? this.open,
        close: close ?? this.close,
      );

  static int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final h = (int.tryParse(parts[0]) ?? 0).clamp(0, 23);
    final m = (int.tryParse(parts[1]) ?? 0).clamp(0, 59);
    return h * 60 + m;
  }

  /// هل هذا اليوم مفتوح عند [nowMinutes] (دقائق منذ منتصف الليل)؟
  bool isOpenAt(int nowMinutes) {
    if (closed) return false;
    final o = _toMinutes(open);
    final c = _toMinutes(close);
    if (o == c) return true; // فتح=إغلاق ⇒ ٢٤ ساعة
    if (o < c) return nowMinutes >= o && nowMinutes < c;
    // يمتد بعد منتصف الليل (16:00→02:00): مفتوحٌ من الفتح لآخر اليوم، ومن
    // بدايته حتى الإغلاق.
    return nowMinutes >= o || nowMinutes < c;
  }
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
  /// عدد التقييمات التي بُني عليها [rating]؛ صفر يعني مطعماً جديداً بلا
  /// تقييمات بعد، فيُعرض «جديد» بدل رقم موهم.
  final int ratingCount;
  final int totalOrders;
  /// اسم الفرع (مثل «العزيزية»)؛ يميّز فرعين لنفس العلامة التجارية بوضوح
  /// بدل الاعتماد على العنوان الصغير وحده.
  final String branchName;
  final double? lat;
  final double? lng;
  final String? imageUrl;

  /// مطابخ هذا المطعم من القائمة المعتمدة [kCuisines] — يضبطها المدير
  /// في نموذج المطعم. فارغة في المطاعم القديمة فتظهر تحت «الكل» وحدها
  /// (مع سقوطٍ على مطابقة النص القديمة كي لا تختفي فجأة من فلاتر كانت
  /// تجدها بالاسم).
  final List<String> cuisines;

  /// مستوى الأسعار (ح9 — تصفية كيتا): ١ = $ اقتصادي، ٢ = $$ متوسط،
  /// ٣ = $$$ مرتفع، ٠ = لم يصنَّف بعد (لا يظهر في فلتر السعر ولا
  /// يُستبعد منه). يضبطه المدير من نموذج المطعم بثلاث شرائح.
  final int priceLevel;

  /// نسبة عمولة المنصّة على وجبات هذا المطعم (العمولة المرنة — من خطة
  /// الإطلاق): كانت 15% مبرمجة في الكود، فاستحال عرضُ «صفر عمولة ٩٠
  /// يوماً» الذي تقوم عليه حملة التوقيع، وخالفت روح بند ج١. يضبطها
  /// المدير من نموذج المطعم، وتُختم على كل طلب لحظة إنشائه فلا يتغير
  /// تاريخ الدفاتر حين تتغير النسبة لاحقاً.
  final double commissionPercent;

  /// تاريخ انتهاء الإعفاء من العمولة (حملة «٣ شهور مجاناً»): ما دام في
  /// المستقبل تكون العمولة الفعّالة صفراً مهما كانت [commissionPercent]،
  /// ثم تعود النسبة المتفَّق عليها **تلقائياً** بلا تدخل المدير. null =
  /// لا إعفاء (النسبة تسري فوراً). يضبطه المدير مرة واحدة يوم التوقيع.
  final DateTime? commissionFreeUntil;

  /// ساعات العمل المجدولة لكل يوم أسبوع (مفتاح 1=الاثنين .. 7=الأحد،
  /// موافقٌ لـ DateTime.weekday). فارغة في المطاعم القديمة فيحكمها المفتاح
  /// اليدوي [isOpen] وحده (توافق خلفي: لا نغلق مطعماً فجأة بلا جدول).
  final Map<int, DaySchedule> openingHours;

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
    this.ratingCount = 0,
    this.totalOrders = 0,
    this.branchName = '',
    this.lat,
    this.lng,
    this.imageUrl,
    this.commissionPercent = 15,
    this.cuisines = const [],
    this.priceLevel = 0,
    this.openingHours = const {},
    this.commissionFreeUntil,
  });

  double get deliveryFee => driverShareFee + appShareFee;

  /// النسبة الفعّالة الآن: صفرٌ ما دام [commissionFreeUntil] في المستقبل
  /// (فترة الإعفاء)، ثم النسبة المتفَّق عليها. هذه هي التي تُختم على الطلب
  /// لحظة إنشائه، فينتهي الإعفاء تلقائياً في موعده بلا لمسِ المدير شيئاً.
  double get effectiveCommissionPercent {
    final until = commissionFreeUntil;
    if (until != null && DateTime.now().isBefore(until)) return 0;
    return commissionPercent;
  }

  /// هل المطعم مفتوح **الآن فعلاً**؟ يجمع المفتاح اليدوي (سيّدٌ: إطفاؤه
  /// يغلق فوراً مهما قال الجدول — «مشغول اليوم») مع ساعات العمل المجدولة.
  /// بلا جدول (مطاعم قديمة) يحكم المفتاح اليدوي وحده. يومٌ غير مضبوط في
  /// جدولٍ موجود = مغلق ذلك اليوم.
  ///
  /// فترة ما بعد منتصف الليل تُنسب **لوردية أمس** (مراجعة 2026-08-15):
  /// دوام الخميس 16:00→02:00 والجمعة إجازة — الجمعة 01:00 وردية الخميس
  /// ما زالت قائمة، فيُفحص جدول أمس أيضاً؛ قبلها كان جدول «اليوم الجديد»
  /// وحده يحكم فيُغلق المطعم قبل موعده بساعتين.
  bool get isOpenNow {
    if (!isOpen) return false;
    if (openingHours.isEmpty) return true;
    final now = DateTime.now();
    return scheduleOpenAt(openingHours, now.weekday, now.hour * 60 + now.minute);
  }

  /// منطق الجدول الخالص — الزمن يُمرَّر لا يُقرأ، فيُختبر حتمياً.
  static bool scheduleOpenAt(
      Map<int, DaySchedule> hours, int weekday, int minutes) {
    final today = hours[weekday];
    if (today != null && today.isOpenAt(minutes)) return true;
    // وردية أمس الممتدة: جدول أمس بنطاق عابر لمنتصف الليل (إغلاق أبكر من
    // فتح) ولم يبلغ إغلاقه بعد.
    final yesterday = hours[weekday == 1 ? 7 : weekday - 1];
    if (yesterday != null && !yesterday.closed) {
      final o = DaySchedule._toMinutes(yesterday.open);
      final c = DaySchedule._toMinutes(yesterday.close);
      if (c < o && minutes < c) return true;
    }
    return false;
  }

  /// نصّ حالة العمل للعميل: «مفتوح» أو «مغلق» أو «مغلق — يفتح 16:00» حين
  /// يكون اليوم له موعد فتحٍ قادم. رسالةٌ تطمئن المنتظِر بدل «مغلق» جافّة.
  String get openStatusLabel {
    if (isOpenNow) return 'مفتوح';
    if (!isOpen || openingHours.isEmpty) return 'مغلق';
    final now = DateTime.now();
    final today = openingHours[now.weekday];
    if (today == null || today.closed) return 'مغلق اليوم';
    // «يفتح 09:00» فقط ما دام الموعد أمامنا — بعد إغلاق اليوم كان يَعِد
    // بموعدٍ مضى (23:30 يقول «يفتح 09:00») فيبدو التطبيق مرتبكاً.
    final minutes = now.hour * 60 + now.minute;
    return minutes < DaySchedule._toMinutes(today.open)
        ? 'مغلق — يفتح ${today.open}'
        : 'مغلق';
  }

  static Map<int, DaySchedule> _parseHours(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <int, DaySchedule>{};
    raw.forEach((k, v) {
      final day = int.tryParse(k.toString());
      if (day != null && day >= 1 && day <= 7 && v is Map) {
        out[day] = DaySchedule.fromMap(v.cast<String, dynamic>());
      }
    });
    return out;
  }

  /// الاسم المعروض للعميل — يضمّ اسم الفرع إن وُجد، فيميّز فرعين لنفس
  /// العلامة التجارية بوضوح: «فطير ستيشن — العزيزية».
  String get displayName =>
      branchName.trim().isEmpty ? name : '$name — ${branchName.trim()}';

  /// هل المطعم بلا تقييمات بعد؟ عندها يُعرض «جديد» بدل 5.0 الافتراضية،
  /// لأن تقييماً كاملاً بلا مقيّمين يفقد ثقة المستخدم.
  bool get isNewlyListed => ratingCount <= 0;

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
        commissionPercent:
            (map['commissionPercent'] as num?)?.toDouble() ?? 15,
        cuisines: ((map['cuisines'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
        priceLevel: (map['priceLevel'] as num?)?.toInt() ?? 0,
        perKmFee: (map['perKmFee'] as num?)?.toDouble() ?? 0.0,
        freeKm: (map['freeKm'] as num?)?.toDouble() ?? 3.0,
        minOrder: (map['minOrder'] as num?)?.toDouble() ?? 20.0,
        address: map['address'] as String? ?? '',
        estimatedTimeMin: (map['estimatedTimeMin'] as num?)?.toInt() ?? 30,
        rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
        ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
        totalOrders: (map['totalOrders'] as num?)?.toInt() ?? 0,
        branchName: map['branchName'] as String? ?? '',
        lat: (map['lat'] as num?)?.toDouble(),
        lng: (map['lng'] as num?)?.toDouble(),
        imageUrl: map['imageUrl'] as String?,
        openingHours: _parseHours(map['openingHours']),
        commissionFreeUntil:
            (map['commissionFreeUntil'] as Timestamp?)?.toDate(),
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
        'ratingCount': ratingCount,
        'branchName': branchName,
        'totalOrders': totalOrders,
        'lat': lat,
        'lng': lng,
        'imageUrl': imageUrl,
        'commissionPercent': commissionPercent,
        'cuisines': cuisines,
        'priceLevel': priceLevel,
        'openingHours':
            openingHours.map((k, v) => MapEntry(k.toString(), v.toMap())),
        'commissionFreeUntil': commissionFreeUntil == null
            ? null
            : Timestamp.fromDate(commissionFreeUntil!),
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

/// خيار واحد داخل مجموعة خيارات صنف (مثال: «كبير» بفرق سعر +5).
class ItemOption {
  final String name;

  /// فرق السعر عن سعر الصنف الأساسي — صفر أو موجب غالباً، ويقبل السالب
  /// (حجم أصغر مثلاً).
  final double priceDelta;

  const ItemOption({required this.name, this.priceDelta = 0});

  factory ItemOption.fromMap(Map<String, dynamic> map) => ItemOption(
        name: map['name'] as String? ?? '',
        priceDelta: (map['priceDelta'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {'name': name, 'priceDelta': priceDelta};
}

/// مجموعة خيارات لصنف — نمط جاهز/كيتا المبسّط بنوعين يغطيان واقع المطاعم:
///   • اختيار واحد إلزامي (multiSelect=false): الحجم، نوع العجين... العميل
///     لا يضيف الصنف دون تحديده.
///   • إضافات اختيارية (multiSelect=true): جبن إضافي، عسل... صفر أو أكثر.
class ItemOptionGroup {
  final String name;
  final bool multiSelect;
  final List<ItemOption> options;

  const ItemOptionGroup({
    required this.name,
    this.multiSelect = false,
    this.options = const [],
  });

  factory ItemOptionGroup.fromMap(Map<String, dynamic> map) => ItemOptionGroup(
        name: map['name'] as String? ?? '',
        multiSelect: map['multiSelect'] as bool? ?? false,
        options: ((map['options'] as List?) ?? [])
            .whereType<Map>()
            .map((m) => ItemOption.fromMap(m.cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'multiSelect': multiSelect,
        'options': options.map((o) => o.toMap()).toList(),
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

  /// السعرات الحرارية للصنف — تكتبها أداة استيراد المنيو في لوحة الويب،
  /// ويعرضها التطبيق للعميل. حقل مستقل لا جزء من الوصف، حتى يمكن تنسيقه
  /// وترشيحه لاحقاً بدل أن يكون نصاً حرّاً داخل جملة.
  final int? kcal;

  /// مجموعات خيارات الصنف (حجم/إضافات...) — قائمة فارغة = صنف بسيط يُضاف
  /// مباشرة كما كان دائماً، فالحقل متوافق خلفياً مع كل الأصناف القائمة.
  final List<ItemOptionGroup> optionGroups;

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
    this.kcal,
    this.optionGroups = const [],
  });

  bool get hasOptions => optionGroups.isNotEmpty;

  /// نسخة معدَّلة مع الإبقاء على بقية الحقول كما هي. تُستخدم في كل موضع يعدّل
  /// حقلاً واحداً (السعر مثلاً)؛ بدونها كان كل موضع يعيد بناء الكائن كاملاً،
  /// فيكفي أن يُضاف حقل جديد للنموذج حتى يُمحى صامتاً عند أول تعديل سعر.
  MenuItem copyWith({
    String? categoryId,
    String? name,
    String? description,
    double? price,
    String? emoji,
    bool? isAvailable,
    int? stockQuantity,
    bool? trackStock,
    int? totalSold,
    String? imageUrl,
    int? kcal,
    List<ItemOptionGroup>? optionGroups,
  }) =>
      MenuItem(
        id: id,
        restaurantId: restaurantId,
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        emoji: emoji ?? this.emoji,
        isAvailable: isAvailable ?? this.isAvailable,
        stockQuantity: stockQuantity ?? this.stockQuantity,
        trackStock: trackStock ?? this.trackStock,
        totalSold: totalSold ?? this.totalSold,
        imageUrl: imageUrl ?? this.imageUrl,
        kcal: kcal ?? this.kcal,
        optionGroups: optionGroups ?? this.optionGroups,
      );

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
      kcal: (map['kcal'] as num?)?.toInt(),
      optionGroups: ((map['optionGroups'] as List?) ?? [])
          .whereType<Map>()
          .map((m) => ItemOptionGroup.fromMap(m.cast<String, dynamic>()))
          .toList(),
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
        'kcal': kcal,
        'optionGroups': optionGroups.map((g) => g.toMap()).toList(),
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

  /// رصيد السائق **بإشارة** — أساس دفتر الحساب:
  ///   • موجب (+) = التطبيق مدين للسائق (من الطلبات المدفوعة إلكترونياً).
  ///   • سالب (−) = السائق مدين للتطبيق (من الطلبات النقدية، إذ يقبض كامل
  ///     المبلغ من العميل فيبقى بيده مالُ المطعم ورسمُ التطبيق).
  ///
  /// يحلّ محلّ [pendingPayout] الذي كان يفترض دائماً أن التطبيق هو المدين،
  /// وهو افتراض صحيح للدفع الإلكتروني ومقلوب تماماً للدفع النقدي.
  final double balance;
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

  /// عدّادا معدل القبول (نمط تويو/جاهز): مجموع العروض التي وصلته وما قبله
  /// منها. يُخزَّنان في المستند لا في ذاكرة الجلسة كي لا يُصفَّر المعدل مع
  /// كل إعادة تشغيل.
  final int offersTotal;
  final int offersAccepted;

  /// كود الداعي الذي أدخله هذا السائق عند تسجيله — أساس برنامج الإحالة.
  /// كان البرنامج نصَّ مشاركة بلا أي حقل يسجّل «من دعا من»، فالتتبّع في
  /// ذاكرة المدير وحدها: لا منع ازدواج ولا تحقّق من الشرط.
  final String referredByCode;

  /// هل صُرفت مكافأة إحالة هذا السائق (للداعي وله)؟ يمنع الصرف مرتين.
  final bool referralRewarded;

  /// مفتاح آخر نافذة تحدٍّ صُرفت له (yyyy-MM-dd لأول أيامها). حارسُ التكرار:
  /// بدونه كان الصرف اليدوي يعتمد على انتباه المدير، وأي أتمتة كانت
  /// ستدفع المكافأة مع كل تحديث للشاشة.
  final String lastChallengeWindow;

  /// تاريخ الانضمام — تُحسب منه نافذة شرط الإحالة (٣٠ يوماً افتراضياً).
  final DateTime? createdAt;

  /// عدد الطلبات الجارية بيده الآن، و«مرساة العنقود»: نقطة مطعم أول طلب في
  /// حمولته الحالية (طلب المالك ٢٠٢٦-٠٨-١١: «ثلاث طلبات في نطاق مطاعم
  /// قريبة وليست بعيدة»).
  ///
  /// **يكتبها تطبيق الكابتن على مستنده هو** لا تطبيق المطعم: القواعد
  /// المنشورة تسمح لغير العميل بتعديل حقل `isAvailable` وحده على مستند
  /// سائق آخر، فلو كتبها المطعم لرُفضت الدفعة كلها وسقط الإسناد. وجهاز
  /// الكابتن يعرف حمولته من تدفّق طلباته أصلاً، فهو مصدرها الطبيعي —
  /// ومصالحة الإدارة تصحّحها إن بات جهازه مغلقاً وتقادمت.
  final int activeOrders;
  final double? clusterLat;
  final double? clusterLng;

  /// كود إحالة السائق الذي يشاركه مع من يدعوهم. مشتقّ من معرّفه لا مخزَّن:
  /// لا مجموعة جديدة ولا خطر تعارض، وثابت مدى الحياة.
  String get referralCode =>
      id.length >= 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase();

  /// معدل القبول 0..1 — null قبل أول عرض حتى لا يُعرض «0٪» ظلماً.
  double? get acceptanceRate =>
      offersTotal > 0 ? offersAccepted / offersTotal : null;

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
    this.balance = 0,
    this.totalDeliveries = 0,
    this.rating = 5.0,
    this.ratingCount = 0,
    this.lat,
    this.lng,
    this.lastLocationUpdate,
    this.warningCount = 0,
    this.offersTotal = 0,
    this.offersAccepted = 0,
    this.referredByCode = '',
    this.referralRewarded = false,
    this.lastChallengeWindow = '',
    this.createdAt,
    this.activeOrders = 0,
    this.clusterLat,
    this.clusterLng,
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
        balance: (map['balance'] as num?)?.toDouble() ?? 0,
        totalDeliveries: (map['totalDeliveries'] as num?)?.toInt() ?? 0,
        rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
        ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
        lat: (map['lat'] as num?)?.toDouble(),
        lng: (map['lng'] as num?)?.toDouble(),
        lastLocationUpdate: (map['lastLocationUpdate'] as Timestamp?)?.toDate(),
        warningCount: (map['warningCount'] as num?)?.toInt() ?? 0,
        offersTotal: (map['offersTotal'] as num?)?.toInt() ?? 0,
        offersAccepted: (map['offersAccepted'] as num?)?.toInt() ?? 0,
        referredByCode: map['referredByCode'] as String? ?? '',
        referralRewarded: map['referralRewarded'] as bool? ?? false,
        lastChallengeWindow: map['lastChallengeWindow'] as String? ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
        activeOrders: (map['activeOrders'] as num?)?.toInt() ?? 0,
        clusterLat: (map['clusterLat'] as num?)?.toDouble(),
        clusterLng: (map['clusterLng'] as num?)?.toDouble(),
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
        'balance': balance,
        'totalDeliveries': totalDeliveries,
        'rating': rating,
        'ratingCount': ratingCount,
        'lat': lat,
        'lng': lng,
        if (lastLocationUpdate != null)
          'lastLocationUpdate': Timestamp.fromDate(lastLocationUpdate!),
        'warningCount': warningCount,
        'offersTotal': offersTotal,
        'offersAccepted': offersAccepted,
        'referredByCode': referredByCode,
        'referralRewarded': referralRewarded,
        'lastChallengeWindow': lastChallengeWindow,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        'activeOrders': activeOrders,
        if (clusterLat != null) 'clusterLat': clusterLat,
        if (clusterLng != null) 'clusterLng': clusterLng,
      };
}

/// مستوى واحد في تحدي نهاية الأسبوع: عدد توصيلات ومكافأتها.
class ChallengeTier {
  final int deliveries;
  final double bonus;

  const ChallengeTier({required this.deliveries, required this.bonus});

  factory ChallengeTier.fromMap(Map<String, dynamic> m) => ChallengeTier(
        deliveries: (m['deliveries'] as num?)?.toInt() ?? 0,
        bonus: (m['bonus'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() =>
      {'deliveries': deliveries, 'bonus': bonus};
}

/// إعدادات الحوافز — كل مبلغ وكل شرط يضبطه المدير من لوحته، فلا رقم
/// مبرمَج في الكود يحتاج إصداراً جديداً لتغييره. الافتراضيات هنا هي
/// المعتمدة عند أول تشغيل (قبل أن يحفظ المدير إعداداته).
///
/// المبالغ الافتراضية محسوبة على اقتصاد ZadGo: كل توصيلة تُدخل للمنصّة
/// رسمها الثابت (3 ر.س)، فشرط 30 توصيلة يعني 90 ر.س دخلاً قبل صرف 80 ر.س
/// مكافآت — أي أن الإحالة مربحة من أول سائق.
/// طلب عميلٍ إضافةَ مطعم غير موجود (ح5 — خطة الإطلاق). معرّف المستند
/// هو الاسم مطبَّعاً (فرغات موحّدة) فتتجمع طلبات نفس المطعم في عدّاد
/// واحد بلا استعلام تجميع.
class RestaurantRequest {
  final String id;
  final String name;
  final int count;
  final DateTime lastRequestedAt;

  const RestaurantRequest({
    required this.id,
    required this.name,
    required this.count,
    required this.lastRequestedAt,
  });

  factory RestaurantRequest.fromMap(Map<String, dynamic> map, String id) =>
      RestaurantRequest(
        id: id,
        name: map['name'] as String? ?? id,
        count: (map['count'] as num?)?.toInt() ?? 0,
        lastRequestedAt:
            (map['lastRequestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}

class IncentiveSettings {
  // ————— برنامج الإحالة —————
  final bool referralEnabled;

  /// مكافأة الداعي، وتُصرف بعد أن يُكمل المدعوّ شرط التوصيلات.
  final double referrerBonus;

  /// مكافأة ترحيب للمدعوّ نفسه بنفس الشرط.
  final double refereeBonus;

  /// عدد التوصيلات المطلوب من المدعوّ خلال [referralWindowDays] يوماً.
  /// الشرط جوهر البرنامج: الدفع على سائق يعمل فعلاً لا على تسجيل.
  final int referralDeliveries;
  final int referralWindowDays;

  /// سقف الإحالات المدفوعة للداعي الواحد شهرياً — يمنع تحوّل البرنامج
  /// إلى مهنة قائمة بذاتها.
  final int referralMonthlyCap;

  // ————— سقف الإسناد المتزامن —————
  //
  // ليسا حافزين، لكن مكانهما هنا بقرار هندسي: قواعد Firestore المنشورة
  // تقصر قراءة `delivery_settings/config` على المدير وحده، بينما مستند
  // `incentives` يقرؤه **أي مسجَّل** — وهذان الرقمان يقرؤهما تطبيقا المطعم
  // (وهو من يُسند) والكابتن. وضعهما في `config` كان يعني أن يقرأهما أحد
  // إطلاقاً فيعملان بالافتراضي أبداً، ويصيران رقمين مبرمَجين تحايلاً على
  // بند ج١ لا التزاماً به.
  //
  /// أقصى عدد طلبات متزامنة للكابتن الواحد — حدٌّ صارم لا يُخترق.
  final int maxOrdersPerDriver;

  /// نطاق «العنقود»: أقصى مسافة بين مطعم الطلب الجديد ومطعم أول طلب في
  /// حمولة الكابتن حتى يُضمّ إليها — «مطاعم قريبة وليست بعيدة».
  final double stackRadiusKm;

  /// نسبة تعويض المطعم عن طلبٍ أُلغي بعد بدء تحضيره (١٠٠٪ افتراضاً —
  /// المعيار العالمي). صفر يعني «لا تعويض».
  final double restaurantCancelCompensationPercent;

  // ————— أجرة التوصيل (موحّدة للجميع، من اللوحة لا من الكود) —————
  //
  // كانت في class Pricing أرقاماً مبرمَجة صلباً (٩/٧/١/٣/٢٥) — نقلها المالك
  // إلى اللوحة (2026-08-15). موحّدة لكل السائقين بقرار المالك: أجورٌ مختلفة
  // لعملٍ متطابق ظلمٌ ونزاع؛ وتمييز سائقٍ مميّز يكون بمكافأة من الحوافز لا
  // بأجرة أساس مختلفة. مكانها هنا (لا في config) لأن **تطبيق العميل** يقرؤها
  // ليحسب أجرة الطلب، ومستند incentives وحده يقرؤه أي مسجَّل.
  //
  /// أجرة توصيل أول [deliveryBaseKm] كيلومتراً (ثابتة).
  final double deliveryBaseFee;
  final double deliveryBaseKm;

  /// أجرة كل كيلومتر إضافي فوق المدى الأساسي.
  final double deliveryPerKmFee;

  /// رسم التوصيل الثابت للمنصّة (حصّتها من كل طلب، يتحمّله العميل).
  final double deliveryAppCut;

  /// أقصى مسافة توصيل مقبولة — بلا هذا الحدّ تُحتسب أجرةٌ خيالية على طلبٍ
  /// لا يُنفَّذ (موقعٌ في مدينة أخرى).
  final double maxDeliveryDistanceKm;

  /// أجرة التوصيل حسب المسافة: أساسٌ لأول [deliveryBaseKm]، ثم لكل كم زائد
  /// (بكسورٍ مجبورةٍ للأعلى: 9.8كم → 10). موحّدة لكل السائقين.
  double deliveryFeeFor(double distanceKm) {
    final extra = distanceKm - deliveryBaseKm;
    final extraKm = extra <= 0 ? 0 : extra.ceil();
    return deliveryBaseFee + extraKm * deliveryPerKmFee;
  }

  /// هل الموقع خارج نطاق التوصيل؟
  bool isOutOfRange(double distanceKm) => distanceKm > maxDeliveryDistanceKm;

  // ————— تحدي نهاية الأسبوع —————
  final bool challengeEnabled;

  /// أيام التحدي بترقيم DateTime (الاثنين 1 … الأحد 7)؛ الافتراضي
  /// الخميس (4) والجمعة (5) — نهاية الأسبوع السعودية وذروة الطلب.
  final List<int> challengeWeekdays;

  /// مستويات تصاعدية؛ يُصرف للسائق **أعلى** مستوى بلغه لا مجموعها.
  final List<ChallengeTier> tiers;

  /// الصرف التلقائي فور تحقّق الشرط — بلا ضغطة المدير على كل مستحقّ.
  ///
  /// حدوده يجب أن تكون معلومة: التطبيق بلا Cloud Functions، فالمسح يجري
  /// من **تطبيق الإدارة وهو مفتوح على شاشة الحوافز**. أي أن الصرف يقع
  /// خلال دقائق من فتحك الشاشة لا في اللحظة نفسها. الأتمتة الكاملة على
  /// الخادم تنتظر ترقية Blaze (المسار د).
  ///
  /// الصرف المزدوج ممتنع في الحالتين: الإحالة تُختم بـ referralRewarded،
  /// والتحدي بـ lastChallengeWindow على مستند السائق.
  final bool autoPay;

  /// رابط صفحة التسجيل التي يفتحها كود الدعوة — يُلحَق به `?ref=CODE`.
  /// صفحة ويب لا شاشة في التطبيق: المدعوّ يرفع فيها مستنداته (الإقامة
  /// ورخصة القيادة والاستمارة والتأمين وصور المركبة)، ورفعُ الملفات من
  /// التطبيق يتطلّب Firebase Storage الموقوف على ترقية Blaze.
  final String joinUrl;

  const IncentiveSettings({
    this.referralEnabled = true,
    this.referrerBonus = 50,
    this.refereeBonus = 30,
    this.referralDeliveries = 30,
    this.referralWindowDays = 30,
    this.referralMonthlyCap = 3,
    this.maxOrdersPerDriver = 3,
    this.stackRadiusKm = 2.0,
    this.restaurantCancelCompensationPercent = 100,
    this.deliveryBaseFee = 9.0,
    this.deliveryBaseKm = 7.0,
    this.deliveryPerKmFee = 1.0,
    this.deliveryAppCut = 3.0,
    this.maxDeliveryDistanceKm = 25.0,
    this.challengeEnabled = true,
    this.challengeWeekdays = const [DateTime.thursday, DateTime.friday],
    this.tiers = const [
      ChallengeTier(deliveries: 10, bonus: 20),
      ChallengeTier(deliveries: 20, bonus: 50),
    ],
    this.autoPay = false,
    this.tipOptions = const [2, 5, 10],
    this.joinUrl = 'https://zadgo.co/join',
  });

  /// خيارات الإكرامية المعروضة للعميل (ح3) — بالريال، من لوحة المدير
  /// لا من الكود (ج١): تُرفع في المواسم وتُخفض بلا إصدار.
  final List<double> tipOptions;

  factory IncentiveSettings.fromMap(Map<String, dynamic> map) {
    const d = IncentiveSettings();
    final rawTiers = map['tiers'];
    final rawDays = map['challengeWeekdays'];
    return IncentiveSettings(
      referralEnabled: map['referralEnabled'] as bool? ?? d.referralEnabled,
      referrerBonus:
          (map['referrerBonus'] as num?)?.toDouble() ?? d.referrerBonus,
      refereeBonus:
          (map['refereeBonus'] as num?)?.toDouble() ?? d.refereeBonus,
      referralDeliveries:
          (map['referralDeliveries'] as num?)?.toInt() ?? d.referralDeliveries,
      referralWindowDays: (map['referralWindowDays'] as num?)?.toInt() ??
          d.referralWindowDays,
      referralMonthlyCap: (map['referralMonthlyCap'] as num?)?.toInt() ??
          d.referralMonthlyCap,
      maxOrdersPerDriver:
          (map['maxOrdersPerDriver'] as num?)?.toInt() ?? d.maxOrdersPerDriver,
      stackRadiusKm:
          (map['stackRadiusKm'] as num?)?.toDouble() ?? d.stackRadiusKm,
      restaurantCancelCompensationPercent:
          (map['restaurantCancelCompensationPercent'] as num?)?.toDouble() ??
              d.restaurantCancelCompensationPercent,
      deliveryBaseFee:
          (map['deliveryBaseFee'] as num?)?.toDouble() ?? d.deliveryBaseFee,
      deliveryBaseKm:
          (map['deliveryBaseKm'] as num?)?.toDouble() ?? d.deliveryBaseKm,
      deliveryPerKmFee:
          (map['deliveryPerKmFee'] as num?)?.toDouble() ?? d.deliveryPerKmFee,
      deliveryAppCut:
          (map['deliveryAppCut'] as num?)?.toDouble() ?? d.deliveryAppCut,
      maxDeliveryDistanceKm: (map['maxDeliveryDistanceKm'] as num?)?.toDouble() ??
          d.maxDeliveryDistanceKm,
      challengeEnabled: map['challengeEnabled'] as bool? ?? d.challengeEnabled,
      challengeWeekdays: rawDays is List && rawDays.isNotEmpty
          ? rawDays.map((e) => (e as num).toInt()).toList()
          : d.challengeWeekdays,
      tiers: rawTiers is List && rawTiers.isNotEmpty
          ? (rawTiers
              .whereType<Map>()
              .map((e) => ChallengeTier.fromMap(e.cast<String, dynamic>()))
              .where((t) => t.deliveries > 0)
              .toList()
            ..sort((a, b) => a.deliveries.compareTo(b.deliveries)))
          : d.tiers,
      autoPay: map['autoPay'] as bool? ?? d.autoPay,
      tipOptions: (map['tipOptions'] is List &&
              (map['tipOptions'] as List).isNotEmpty)
          ? (map['tipOptions'] as List)
              .map((e) => (e as num).toDouble())
              .where((v) => v > 0)
              .toList()
          : d.tipOptions,
      joinUrl: (map['joinUrl'] as String?)?.trim().isNotEmpty == true
          ? (map['joinUrl'] as String).trim()
          : d.joinUrl,
    );
  }

  Map<String, dynamic> toMap() => {
        'referralEnabled': referralEnabled,
        'referrerBonus': referrerBonus,
        'refereeBonus': refereeBonus,
        'referralDeliveries': referralDeliveries,
        'referralWindowDays': referralWindowDays,
        'referralMonthlyCap': referralMonthlyCap,
        'maxOrdersPerDriver': maxOrdersPerDriver,
        'stackRadiusKm': stackRadiusKm,
        'restaurantCancelCompensationPercent':
            restaurantCancelCompensationPercent,
        'deliveryBaseFee': deliveryBaseFee,
        'deliveryBaseKm': deliveryBaseKm,
        'deliveryPerKmFee': deliveryPerKmFee,
        'deliveryAppCut': deliveryAppCut,
        'maxDeliveryDistanceKm': maxDeliveryDistanceKm,
        'challengeEnabled': challengeEnabled,
        'challengeWeekdays': challengeWeekdays,
        'tiers': tiers.map((t) => t.toMap()).toList(),
        'autoPay': autoPay,
        'tipOptions': tipOptions,
        'joinUrl': joinUrl,
      };

  IncentiveSettings copyWith({
    bool? referralEnabled,
    double? referrerBonus,
    double? refereeBonus,
    int? referralDeliveries,
    int? referralWindowDays,
    int? referralMonthlyCap,
    int? maxOrdersPerDriver,
    double? stackRadiusKm,
    double? restaurantCancelCompensationPercent,
    double? deliveryBaseFee,
    double? deliveryBaseKm,
    double? deliveryPerKmFee,
    double? deliveryAppCut,
    double? maxDeliveryDistanceKm,
    bool? challengeEnabled,
    List<int>? challengeWeekdays,
    List<ChallengeTier>? tiers,
    bool? autoPay,
    List<double>? tipOptions,
    String? joinUrl,
  }) =>
      IncentiveSettings(
        referralEnabled: referralEnabled ?? this.referralEnabled,
        referrerBonus: referrerBonus ?? this.referrerBonus,
        refereeBonus: refereeBonus ?? this.refereeBonus,
        referralDeliveries: referralDeliveries ?? this.referralDeliveries,
        referralWindowDays: referralWindowDays ?? this.referralWindowDays,
        referralMonthlyCap: referralMonthlyCap ?? this.referralMonthlyCap,
        maxOrdersPerDriver: maxOrdersPerDriver ?? this.maxOrdersPerDriver,
        stackRadiusKm: stackRadiusKm ?? this.stackRadiusKm,
        restaurantCancelCompensationPercent:
            restaurantCancelCompensationPercent ??
                this.restaurantCancelCompensationPercent,
        deliveryBaseFee: deliveryBaseFee ?? this.deliveryBaseFee,
        deliveryBaseKm: deliveryBaseKm ?? this.deliveryBaseKm,
        deliveryPerKmFee: deliveryPerKmFee ?? this.deliveryPerKmFee,
        deliveryAppCut: deliveryAppCut ?? this.deliveryAppCut,
        maxDeliveryDistanceKm:
            maxDeliveryDistanceKm ?? this.maxDeliveryDistanceKm,
        challengeEnabled: challengeEnabled ?? this.challengeEnabled,
        challengeWeekdays: challengeWeekdays ?? this.challengeWeekdays,
        tiers: tiers ?? this.tiers,
        autoPay: autoPay ?? this.autoPay,
        tipOptions: tipOptions ?? this.tipOptions,
        joinUrl: joinUrl ?? this.joinUrl,
      );

  /// أعلى مستوى بلغه سائق أنجز [count] توصيلة — `null` إن لم يبلغ أدناها.
  ChallengeTier? tierFor(int count) {
    ChallengeTier? reached;
    for (final t in tiers) {
      if (count >= t.deliveries) reached = t;
    }
    return reached;
  }

  /// المستوى التالي الذي يسعى إليه — `null` إن بلغ أعلاها.
  ChallengeTier? nextTierFor(int count) {
    for (final t in tiers) {
      if (count < t.deliveries) return t;
    }
    return null;
  }

  /// نافذة التحدي الحالية (بدايتها ونهايتها) المحيطة بـ [now]، أو `null`
  /// حين لا تكون أيام التحدي جارية. الأيام المتتالية تُعدّ نافذة واحدة
  /// (الخميس والجمعة معاً)، فيُحسب التقدّم عبر اليومين لا لكل يوم وحده.
  (DateTime, DateTime)? currentWindow(DateTime now) {
    if (!challengeEnabled || challengeWeekdays.isEmpty || tiers.isEmpty) {
      return null;
    }
    if (!challengeWeekdays.contains(now.weekday)) return null;
    var start = DateTime(now.year, now.month, now.day);
    // التراجع لأول يوم متصل بأيام التحدي حتى تُحسب نافذة واحدة ممتدة.
    while (challengeWeekdays
        .contains(start.subtract(const Duration(days: 1)).weekday)) {
      start = start.subtract(const Duration(days: 1));
    }
    var end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    while (challengeWeekdays.contains(end.add(const Duration(days: 1)).weekday)) {
      end = end.add(const Duration(days: 1));
    }
    return (start, end);
  }

  /// مفتاح النافذة المخزَّن على مستند السائق لمنع تكرار الصرف.
  static String windowKey(DateTime start) =>
      '${start.year}-${start.month.toString().padLeft(2, '0')}-'
      '${start.day.toString().padLeft(2, '0')}';

  /// رابط دعوة يحمل كود الداعي — يفتحه المدعوّ فيسجّل ويرفق مستنداته،
  /// فيصل الكود مع البيانات بلا اعتماد على تذكّره كتابته يدوياً.
  String inviteLinkFor(String referralCode) {
    final base = joinUrl.trim();
    if (base.isEmpty) return '';
    return base.contains('?')
        ? '$base&ref=$referralCode'
        : '$base?ref=$referralCode';
  }

  /// أسماء أيام التحدي للعرض.
  String get weekdaysLabel {
    const names = {
      DateTime.monday: 'الاثنين',
      DateTime.tuesday: 'الثلاثاء',
      DateTime.wednesday: 'الأربعاء',
      DateTime.thursday: 'الخميس',
      DateTime.friday: 'الجمعة',
      DateTime.saturday: 'السبت',
      DateTime.sunday: 'الأحد',
    };
    return challengeWeekdays.map((d) => names[d] ?? '').join(' و');
  }
}

/// دفعة تسوية سُلّمت لمطعم مقابل مستحقّاته.
///
/// دفتر المطعم يُبنى بالطرح لا بالقيد المزدوج: المستحق = صافي طلباته
/// المكتملة، والمدفوع = مجموع هذه الدفعات، والفرق هو رصيده. هذا يتجنّب
/// كتابة قيد مع كل توصيل (ومخاطر ازدواجه)، ويبقى قابلاً للمراجعة لأن
/// طرفَي المعادلة مستندات محفوظة.
class RestaurantSettlement {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final double amount;

  /// طريقة السداد: تحويل بنكي، نقداً، شيك...
  final String method;
  final String? note;
  final String performedBy;
  final DateTime createdAt;

  const RestaurantSettlement({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.amount,
    this.method = '',
    this.note,
    required this.performedBy,
    required this.createdAt,
  });

  factory RestaurantSettlement.fromMap(Map<String, dynamic> map, String id) =>
      RestaurantSettlement(
        id: id,
        restaurantId: map['restaurantId'] as String? ?? '',
        restaurantName: map['restaurantName'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        method: map['method'] as String? ?? '',
        note: map['note'] as String?,
        performedBy: map['performedBy'] as String? ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'amount': amount,
        'method': method,
        if (note != null) 'note': note,
        'performedBy': performedBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

/// نوع خصم الكوبون.
enum CouponType { percentage, fixed }

CouponType _couponTypeFromString(String? raw) => _enumValueFromString<CouponType>(
      raw,
      CouponType.values,
      CouponType.percentage,
      'CouponType',
    );

/// كود خصم ترويجي. الخصم **تسويقٌ تموّله المنصّة من حصّتها** — لا يُنقص
/// مستحق المطعم ولا أجرة السائق، وهو ما يجعله آمناً تشغيلياً بلا تفاوض.
///
/// معرّف المستند هو الكود نفسه (بحروف كبيرة)، فالتحقق قراءةُ مستند واحد
/// لا استعلام — أسرع، وقواعده أبسط.
class Coupon {
  final String code;
  final CouponType type;

  /// نسبة مئوية (10 = 10%) أو مبلغ ثابت بالريال حسب [type].
  final double value;

  /// حد أدنى لقيمة الوجبات لتفعيل الكوبون (0 = بلا حد).
  final double minOrderTotal;

  /// سقف الخصم بالريال للنوع النسبي (0 = بلا سقف) — يمنع «20% على طلب
  /// 500 ريال» من ابتلاع دخل المنصّة.
  final double maxDiscount;

  /// حد الاستخدام الكلي (0 = بلا حد) وعدد ما استُخدم فعلاً.
  final int usageLimit;
  final int usedCount;

  /// كم مرة يحق للمستخدم الواحد استخدامه (افتراضياً مرة واحدة).
  final int perUserLimit;

  /// مقصور على مطعم بعينه؟ (فارغ = كل المطاعم)
  final String restaurantId;

  final DateTime? expiresAt;
  final bool isActive;
  final DateTime createdAt;

  const Coupon({
    required this.code,
    this.type = CouponType.percentage,
    required this.value,
    this.minOrderTotal = 0,
    this.maxDiscount = 0,
    this.usageLimit = 0,
    this.usedCount = 0,
    this.perUserLimit = 1,
    this.restaurantId = '',
    this.expiresAt,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get isExhausted => usageLimit > 0 && usedCount >= usageLimit;

  /// وصف مختصر للعرض: «20% حتى 15 ر.س» أو «10 ر.س».
  String get label => type == CouponType.percentage
      ? '${value.toStringAsFixed(0)}%${maxDiscount > 0 ? ' حتى ${maxDiscount.toStringAsFixed(0)} ر.س' : ''}'
      : '${value.toStringAsFixed(0)} ر.س';

  /// قيمة الخصم على مبلغ معيّن — لا تتجاوز المبلغ نفسه أبداً (فلا يصير
  /// الإجمالي سالباً ولا تدفع المنصّة للعميل).
  double discountFor(double amount) {
    final raw = type == CouponType.percentage
        ? amount * (value / 100)
        : value;
    final capped = (maxDiscount > 0 && raw > maxDiscount) ? maxDiscount : raw;
    return capped > amount ? amount : capped;
  }

  factory Coupon.fromMap(Map<String, dynamic> map, String id) => Coupon(
        code: id,
        type: _couponTypeFromString(map['type'] as String?),
        value: (map['value'] as num?)?.toDouble() ?? 0,
        minOrderTotal: (map['minOrderTotal'] as num?)?.toDouble() ?? 0,
        maxDiscount: (map['maxDiscount'] as num?)?.toDouble() ?? 0,
        usageLimit: (map['usageLimit'] as num?)?.toInt() ?? 0,
        usedCount: (map['usedCount'] as num?)?.toInt() ?? 0,
        perUserLimit: (map['perUserLimit'] as num?)?.toInt() ?? 1,
        restaurantId: map['restaurantId'] as String? ?? '',
        expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
        isActive: map['isActive'] as bool? ?? true,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'value': value,
        'minOrderTotal': minOrderTotal,
        'maxDiscount': maxDiscount,
        'usageLimit': usageLimit,
        'usedCount': usedCount,
        'perUserLimit': perUserLimit,
        'restaurantId': restaurantId,
        if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

/// حالة طلب سحب مستحقّات السائق.
enum PayoutRequestStatus { pending, paid, rejected }

PayoutRequestStatus _payoutRequestStatusFromString(String? raw) =>
    _enumValueFromString<PayoutRequestStatus>(
      raw,
      PayoutRequestStatus.values,
      PayoutRequestStatus.pending,
      'PayoutRequestStatus',
    );

extension PayoutRequestStatusExt on PayoutRequestStatus {
  String get label => switch (this) {
        PayoutRequestStatus.pending => 'قيد المعالجة',
        PayoutRequestStatus.paid => 'مصروف',
        PayoutRequestStatus.rejected => 'مرفوض',
      };
}

/// طلب سحب مستحقّات يقدّمه السائق بنفسه (نمط نينجا/تويو: زر «اسحب أموالي»)
/// بدل انتظار مبادرة الإدارة — الإدارة تصرفه فيتقيّد في دفتر الحركات
/// بحركة payout كالمعتاد، أو ترفضه بسبب مكتوب يراه السائق.
class PayoutRequest {
  final String id;
  final String driverId;
  final String driverName;
  final double amount;

  /// طريقة الاستلام التي يكتبها السائق: آيبان للتحويل أو «نقداً من الإدارة».
  final String method;
  final PayoutRequestStatus status;

  /// ردّ الإدارة — سبب الرفض أو ملاحظة الصرف.
  final String? adminNote;
  final DateTime createdAt;
  final DateTime? processedAt;

  const PayoutRequest({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.amount,
    required this.method,
    this.status = PayoutRequestStatus.pending,
    this.adminNote,
    required this.createdAt,
    this.processedAt,
  });

  factory PayoutRequest.fromMap(Map<String, dynamic> map, String id) =>
      PayoutRequest(
        id: id,
        driverId: map['driverId'] as String? ?? '',
        driverName: map['driverName'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        method: map['method'] as String? ?? '',
        status: _payoutRequestStatusFromString(map['status'] as String?),
        adminNote: map['adminNote'] as String?,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        processedAt: (map['processedAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'driverId': driverId,
        'driverName': driverName,
        'amount': amount,
        'method': method,
        'status': status.name,
        if (adminNote != null) 'adminNote': adminNote,
        'createdAt': Timestamp.fromDate(createdAt),
        if (processedAt != null) 'processedAt': Timestamp.fromDate(processedAt!),
      };
}

/// نوع حركة محفظة العميل.
enum WalletTransactionType {
  /// استرداد من الإدارة عند حلّ شكوى.
  refund,

  /// خصم عند استخدام الرصيد في دفع طلب.
  orderPayment,

  /// إعادة الرصيد المستخدَم عند إلغاء الطلب.
  orderReversal,

  /// تسوية يدوية من الإدارة.
  adjustment,
}

WalletTransactionType _walletTxTypeFromString(String? raw) =>
    _enumValueFromString<WalletTransactionType>(
      raw,
      WalletTransactionType.values,
      WalletTransactionType.adjustment,
      'WalletTransactionType',
    );

extension WalletTransactionTypeExt on WalletTransactionType {
  String get label {
    const map = {
      WalletTransactionType.refund: 'استرداد',
      WalletTransactionType.orderPayment: 'دفع طلب',
      WalletTransactionType.orderReversal: 'إعادة رصيد طلب ملغى',
      WalletTransactionType.adjustment: 'تسوية',
    };
    return map[this] ?? '';
  }

  IconData get icon {
    const map = {
      WalletTransactionType.refund: Icons.replay_circle_filled_rounded,
      WalletTransactionType.orderPayment: Icons.shopping_bag_outlined,
      WalletTransactionType.orderReversal: Icons.undo_rounded,
      WalletTransactionType.adjustment: Icons.tune_rounded,
    };
    return map[this] ?? Icons.account_balance_wallet_outlined;
  }
}

/// حركة واحدة في محفظة العميل — بنفس فلسفة دفتر السائق: تُكتب مع تغيّر
/// الرصيد في دفعة واحدة، فيعرف العميل سبب كل تغيّر بدل رقم يتبدّل بلا تفسير.
class WalletTransaction {
  final String id;
  final String userId;
  final WalletTransactionType type;

  /// المبلغ بإشارة: موجب يزيد الرصيد، سالب ينقصه.
  final double amount;
  final double balanceAfter;
  final String? orderId;
  final String? orderNumber;
  final String? note;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.orderId,
    this.orderNumber,
    this.note,
    required this.createdAt,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map, String id) =>
      WalletTransaction(
        id: id,
        userId: map['userId'] as String? ?? '',
        type: _walletTxTypeFromString(map['type'] as String?),
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        balanceAfter: (map['balanceAfter'] as num?)?.toDouble() ?? 0,
        orderId: map['orderId'] as String?,
        orderNumber: map['orderNumber'] as String?,
        note: map['note'] as String?,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'type': type.name,
        'amount': amount,
        'balanceAfter': balanceAfter,
        if (orderId != null) 'orderId': orderId,
        if (orderNumber != null) 'orderNumber': orderNumber,
        if (note != null) 'note': note,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

/// نوع حركة دفتر السائق — يحدّد اتجاه أثرها على الرصيد ومصدرها.
enum DriverTransactionType {
  /// عُهدة استلام طلب نقدي: قيمة الطلب تُقيَّد على السائق لحظة استلامه من
  /// المطعم — البضاعة صارت بيده، وذمّته مشغولة بقيمتها حتى يحصّلها من
  /// العميل (نموذج كيتا/مرسول).
  orderCustody,

  /// عكس عُهدة: أُلغي الطلب أو أُعيد إسناده بعد الاستلام، فتُردّ قيمته
  /// لرصيد السائق.
  custodyReversal,

  /// توصيل طلب نقدي: السائق قبض كامل المبلغ، فيُقيَّد عليه ما ليس له.
  /// (النمط القديم — القيد عند التسليم؛ أبقي لقراءة الحركات المحفوظة به،
  /// وللطلبات التي استُلمت بنسخة سابقة لا تعرف قيد العهدة.)
  deliveryCash,

  /// توصيل طلب مدفوع إلكترونياً: التطبيق قبض المبلغ، فتُقيَّد أجرة السائق له.
  deliveryOnline,

  /// مكافأة تمنحها الإدارة (تحدٍّ، إحالة سائق جديد، تميّز...) — أقوى أداة
  /// استبقاء سائقين في تطبيقات التوصيل (توصية تقريرَي تويو ونينجا).
  bonus,

  /// إيداع: السائق سلّم نقداً للإدارة.
  deposit,

  /// صرف: الإدارة دفعت للسائق مستحقّاته.
  payout,

  /// تسوية يدوية من الإدارة (تصحيح خطأ، مكافأة، خصم...).
  adjustment,
}

DriverTransactionType _driverTxTypeFromString(String? raw) =>
    _enumValueFromString<DriverTransactionType>(
      raw,
      DriverTransactionType.values,
      DriverTransactionType.adjustment,
      'DriverTransactionType',
    );

extension DriverTransactionTypeExt on DriverTransactionType {
  String get label {
    const map = {
      DriverTransactionType.orderCustody: 'عُهدة استلام طلب',
      DriverTransactionType.custodyReversal: 'ردّ عُهدة (إلغاء)',
      DriverTransactionType.deliveryCash: 'توصيل نقدي',
      DriverTransactionType.deliveryOnline: 'توصيل إلكتروني',
      DriverTransactionType.bonus: 'مكافأة 🎉',
      DriverTransactionType.deposit: 'شحن / إيداع',
      DriverTransactionType.payout: 'صرف مستحقّات',
      DriverTransactionType.adjustment: 'تسوية يدوية',
    };
    return map[this] ?? '';
  }

  IconData get icon {
    const map = {
      DriverTransactionType.orderCustody: Icons.shopping_bag_outlined,
      DriverTransactionType.custodyReversal: Icons.replay_rounded,
      DriverTransactionType.deliveryCash: Icons.payments_outlined,
      DriverTransactionType.deliveryOnline: Icons.credit_card,
      DriverTransactionType.bonus: Icons.emoji_events_outlined,
      DriverTransactionType.deposit: Icons.south_west_rounded,
      DriverTransactionType.payout: Icons.north_east_rounded,
      DriverTransactionType.adjustment: Icons.tune_rounded,
    };
    return map[this] ?? Icons.receipt_long_outlined;
  }
}

/// حركة واحدة في دفتر حساب السائق. تُكتب مع كل تغيير على الرصيد في نفس
/// الدفعة (batch)، فلا يتغيّر رصيد دون حركة تفسّره — وهو ما يجعل أي نزاع
/// قابلاً للمراجعة بدل الاعتماد على رقم مجرّد.
class DriverTransaction {
  final String id;
  final String driverId;
  final DriverTransactionType type;

  /// المبلغ **بإشارة**: موجب يزيد الرصيد، سالب ينقصه.
  final double amount;

  /// الرصيد بعد تطبيق هذه الحركة — يُحفظ وقت الكتابة ليبقى السجلّ مقروءاً
  /// دون إعادة حساب التسلسل كاملاً.
  final double balanceAfter;

  final String? orderId;
  final String? orderNumber;
  final String? note;

  /// مَن نفّذ الحركة (uid) — السائق نفسه عند التوصيل، أو المدير عند الإيداع
  /// والصرف والتسوية.
  final String performedBy;
  final DateTime createdAt;

  const DriverTransaction({
    required this.id,
    required this.driverId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.orderId,
    this.orderNumber,
    this.note,
    required this.performedBy,
    required this.createdAt,
  });

  factory DriverTransaction.fromMap(Map<String, dynamic> map, String id) =>
      DriverTransaction(
        id: id,
        driverId: map['driverId'] as String? ?? '',
        type: _driverTxTypeFromString(map['type'] as String?),
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        balanceAfter: (map['balanceAfter'] as num?)?.toDouble() ?? 0,
        orderId: map['orderId'] as String?,
        orderNumber: map['orderNumber'] as String?,
        note: map['note'] as String?,
        performedBy: map['performedBy'] as String? ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'driverId': driverId,
        'type': type.name,
        'amount': amount,
        'balanceAfter': balanceAfter,
        if (orderId != null) 'orderId': orderId,
        if (orderNumber != null) 'orderNumber': orderNumber,
        if (note != null) 'note': note,
        'performedBy': performedBy,
        'createdAt': Timestamp.fromDate(createdAt),
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
  /// معرّف عملية الدفع لدى بوابة الدفع (Moyasar) — يُملأ فقط عند نجاح شحن
  /// البطاقة فعلياً، ووجوده هو الدليل الوحيد على أن الطلب مدفوع مسبقاً.
  final String? paymentId;
  /// المبلغ المخصوم من رصيد محفظة العميل لهذا الطلب. الباقي يُدفع بالوسيلة
  /// المختارة، فالمحفظة تُطبَّق كخصم على الإجمالي لا كوسيلة دفع منفصلة.
  final double walletUsed;
  final bool driverAcknowledged;

  /// هل قُيّدت عُهدة هذا الطلب النقدي على محفظة السائق لحظة استلامه من
  /// المطعم؟ (نموذج كيتا/مرسول: البضاعة بيد السائق = قيمتها عليه فوراً،
  /// لا عند التسليم.) تمنع القيد المزدوج بين الاستلام والتسليم، وتحدّد
  /// وجوب العكس عند الإلغاء أو إعادة الإسناد بعد الاستلام.
  final bool custodyDebited;

  /// لحظة تسجيل السائق وصوله إلى المطعم (زر «وصلت المطعم» ضمن النطاق
  /// الجغرافي). حجر الأساس في حسم نزاع «مَن أخّر الطلب؟»: وصل ٧:١٠ واستلم
  /// ٧:٣٥ = التأخير من المطعم لا من السائق.
  final DateTime? arrivedAtRestaurantAt;

  /// تعويض المطعم عن طلبٍ أُلغي **بعد أن بدأ تحضيره** — صفرٌ في كل ما
  /// عداه. المعيار العالمي (يوبر إيتس ودور داش): المطعم يُدفع له كاملاً
  /// متى قبل الطلب وطبخه ولم يكن الإلغاء بسببه، فتكلفة الطعام وقعت فعلاً
  /// ولا ذنب له فيها. النسبة يضبطها المدير (`restaurantCancelCompensationPercent`،
  /// ١٠٠٪ افتراضاً) — لا رقم مبرمَج (بند ج١).
  final double restaurantCompensation;

  /// خصمٌ على المطعم لصالح العميل (سياسة المالك 2026-08-13): شكوى جودة
  /// مقبولة (طعام رديء/بارد/ناقص) يتحمّل المطعمُ استردادَها لا المنصّة —
  /// فمن أفسد الطلبَ يدفع ثمنه، والمنصّة وسيطٌ لا صندوق تعويضات.
  /// مرآة restaurantCompensation بإشارة معاكسة: ذاك يضيف للمستحق وهذا
  /// يطرح منه، وكلاهما مختوم على مستند الطلب فيقرؤه الدفتران مباشرة.
  final double restaurantChargeback;

  /// موعد التوصيل المطلوب (ح4) — فارغ يعني «في أقرب وقت» (السلوك القائم
  /// حرفياً). طلبٌ مجدول يمرّ بنفس الدورة تماماً إلا أن الإسناد التلقائي
  /// يمتنع عنه ما دام موعده بعيداً — وإلا استُدعي كابتنٌ ظهراً لطلبِ
  /// الثامنة مساءً فوقف ينتظر أو هجر العرض.
  final DateTime? scheduledFor;

  /// إكرامية الكابتن (ح3) — يختارها العميل عند الدفع وتصل الكابتن
  /// **كاملة بلا اقتطاع**: ليست جزءاً من grandTotal ولا payableTotal
  /// عمداً، فلا تدخل العمولة ولا العُهدة ولا حساب الاسترداد — ممرٌّ
  /// محايد من جيب العميل ليد الكابتن والمنصّة مجرد ناقل.
  final double driverTip;

  /// نسبة العمولة المختومة لحظة إنشاء الطلب من مستند المطعم (العمولة
  /// المرنة): فارغة في الطلبات القديمة فتُقرأ 15 — تاريخ الدفاتر لا
  /// يتحرك حين يغيّر المدير نسبة مطعمٍ لاحقاً.
  final double? commissionPercent;

  bool get isScheduled => scheduledFor != null;

  /// هل ما يزال مبكراً على تحريك هذا الطلب المجدول؟ نافذة ٤٥ دقيقة قبل
  /// الموعد: تكفي تحضيراً وتوصيلاً داخل المدينة، وتفتح باب الإسناد قبل
  /// الموعد لا عنده — فالكابتن يحتاج وقت وصولٍ للمطعم.
  bool get scheduledStillEarly =>
      scheduledFor != null &&
      scheduledFor!.difference(DateTime.now()).inMinutes > 45;

  /// لحظة تأكيد **المطعم** تسليمَ الطلب للكابتن — الوجه الثاني للاستلام
  /// (طلب المالك ٢٠٢٦-٠٨-١١): ضغطة الكابتن وحدها إقرارُ طرفٍ واحد، فإن
  /// أنكر المطعم التسليم أو ادّعى تأخّر الكابتن لم يكن في السجل ما يفصل.
  /// الحالة لا تتغيّر بهذه الضغطة — الانتقال يبقى بيد الكابتن كما هو —
  /// وإنما تُختم لحظةُ التسليم من طرف المطعم لتظهر في الفاتورة كإثبات.
  final DateTime? restaurantHandoverAt;

  /// كود الخصم المطبَّق على الطلب (إن وُجد) وقيمة خصمه بالريال. القيمة
  /// تُحفظ محسوبةً لا كنسبة، فتبقى الفاتورة صحيحة حتى لو عُدّل الكوبون
  /// أو حُذف لاحقاً.
  final String? couponCode;
  final double discountAmount;

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
    this.paymentId,
    this.walletUsed = 0,
    this.driverAcknowledged = true,
    this.custodyDebited = false,
    this.arrivedAtRestaurantAt,
    this.restaurantHandoverAt,
    this.restaurantCompensation = 0,
    this.restaurantChargeback = 0,
    this.scheduledFor,
    this.driverTip = 0,
    this.commissionPercent,
    this.couponCode,
    this.discountAmount = 0,
  });

  /// عُهدة الطلب النقدي على السائق لحظة استلامه: قيمة الوجبات (للمطعم)
  /// + الرسم الثابت (للمنصّة) — ناقصاً ما دفعه العميل من رصيد محفظته،
  /// فذلك الجزء قبضته المنصّة أصلاً ولن يحصّله السائق نقداً. بدون خصمه
  /// كان السائق يُقيَّد عليه مالٌ لن يقبضه (عميل دفع 20 من محفظته على
  /// طلب 112 = يحصّل السائق 92 وتُقيَّد عليه 103 فيُظلم بـ20).
  ///
  /// أجرة توصيله ليست ضمن العُهدة — يستوفيها من النقد الذي يحصّله؛ وإن
  /// غطّت المحفظة أكثر من حصّتَي المطعم والمنصّة صارت القيمة سالبة =
  /// مستحق للسائق تقيّده المنصّة له (كالطلب الإلكتروني تماماً).
  /// وخصم الكوبون كذلك: تسويقٌ تتحمّله المنصّة من حصّتها، فلا يُنقص مستحق
  /// المطعم ولا أجرة السائق — والسائق لن يحصّله نقداً فلا يُقيَّد عليه.
  double get custodyAmount =>
      itemsTotal + appShare - walletUsed - discountAmount;

  double get deliveryFee => driverShare + appShare;
  double get itemsTotal => items.fold(0.0, (s, i) => s + i.subtotal);

  /// إجمالي الطلب قبل أي خصم — الأساس المحاسبي الثابت (وعليه تُبنى
  /// حصص المطعم والسائق والمنصّة).
  double get grandTotal => itemsTotal + deliveryFee;

  /// ما يدفعه العميل فعلاً بعد خصم الكوبون (لا يشمل خصم المحفظة، فذاك
  /// دفعٌ من رصيده لا تخفيض للقيمة).
  double get payableTotal => grandTotal - discountAmount;

  double get calculatedCommission =>
      itemsTotal * ((commissionPercent ?? 15) / 100);

  /// عمولة الوجبات **للتقارير**: تُحسب دائماً بالقاعدة المعتمدة (15% من
  /// قيمة الوجبات) وتتجاهل المخزَّن كلياً. كانت تفضّل المخزَّن إن كان
  /// موجباً، لكن الطلبات المنشأة من لوحة الويب أو قبل تثبيت قاعدة التسعير
  /// تحمل قيماً صغيرة موجبة خاطئة، فظهر لمطعمٍ «عمولة (15%) = 2.82» على
  /// مبيعات 114 — والقاعدة ثابتة لا مخصصة لكل طلب، فالحساب المباشر هو
  /// الصحيح دوماً. platformCommission يبقى مخزَّناً كأثر تدقيق فقط.
  double get effectiveCommission => calculatedCommission;

  /// رسم التوصيل الثابت **للتقارير**: المخزَّن إن وُجد، وإلا القيمة المعتمدة
  /// حالياً — لنفس سبب [effectiveCommission] (طلبات قديمة بـ appShare = 0
  /// كانت تُظهر «عمولة التوصيل: 0.00»).
  ///
  /// السقوط على 3 يقتصر على **القديم قبل 2026-08-15** (مراجعة اليوم نفسه):
  /// بعدها صار الرسم يُضبط من اللوحة وقد يكون **صفراً مقصوداً** (عرض
  /// «توصيل بلا رسوم») — سقوطٌ أعمى كان سيُظهر في التقارير رسماً لم
  /// يُحصَّل ويضخّم دخل المنصّة.
  double get effectiveAppShare =>
      appShare > 0 || createdAt.isAfter(DateTime(2026, 8, 15))
          ? appShare
          : Pricing.fixedDeliveryCommission;

  /// صافي مستحقّات المطعم = قيمة الوجبات بعد خصم عمولة التطبيق (15%). قيمة
  /// الطلب للعميل تساوي قيمته للمطعم؛ العمولة تُخصم من المطعم في التقارير.
  /// خصم الكوبون لا يمسّه — تتحمّله المنصّة وحدها.
  double get restaurantNet => itemsTotal - effectiveCommission;

  /// دخل المنصّة من هذا الطلب: عمولة الوجبات + رسم التوصيل الثابت، ناقصاً
  /// خصم الكوبون الذي موّلته.
  double get platformNet =>
      effectiveCommission + effectiveAppShare - discountAmount;

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
        paymentId: map['paymentId'] as String?,
        walletUsed: (map['walletUsed'] as num?)?.toDouble() ?? 0,
        driverAcknowledged: map['driverAcknowledged'] as bool? ?? true,
        custodyDebited: map['custodyDebited'] as bool? ?? false,
        arrivedAtRestaurantAt:
            (map['arrivedAtRestaurantAt'] as Timestamp?)?.toDate(),
        restaurantHandoverAt:
            (map['restaurantHandoverAt'] as Timestamp?)?.toDate(),
        restaurantCompensation:
            (map['restaurantCompensation'] as num?)?.toDouble() ?? 0,
        restaurantChargeback:
            (map['restaurantChargeback'] as num?)?.toDouble() ?? 0,
        scheduledFor: (map['scheduledFor'] as Timestamp?)?.toDate(),
        driverTip: (map['driverTip'] as num?)?.toDouble() ?? 0,
        commissionPercent:
            (map['commissionPercent'] as num?)?.toDouble(),
        couponCode: map['couponCode'] as String?,
        discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0,
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
        if (paymentId != null) 'paymentId': paymentId,
        'walletUsed': walletUsed,
        'driverAcknowledged': driverAcknowledged,
        'custodyDebited': custodyDebited,
        if (arrivedAtRestaurantAt != null)
          'arrivedAtRestaurantAt': Timestamp.fromDate(arrivedAtRestaurantAt!),
        if (restaurantHandoverAt != null)
          'restaurantHandoverAt': Timestamp.fromDate(restaurantHandoverAt!),
        'restaurantCompensation': restaurantCompensation,
        'restaurantChargeback': restaurantChargeback,
        if (scheduledFor != null)
          'scheduledFor': Timestamp.fromDate(scheduledFor!),
        'driverTip': driverTip,
        if (commissionPercent != null)
          'commissionPercent': commissionPercent,
        if (couponCode != null) 'couponCode': couponCode,
        'discountAmount': discountAmount,
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
    double? restaurantLat,
    double? restaurantLng,
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
        restaurantLat: restaurantLat ?? this.restaurantLat,
        restaurantLng: restaurantLng ?? this.restaurantLng,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        paymentId: paymentId,
        walletUsed: walletUsed,
        driverAcknowledged: driverAcknowledged ?? this.driverAcknowledged,
        custodyDebited: custodyDebited,
        arrivedAtRestaurantAt: arrivedAtRestaurantAt,
        restaurantHandoverAt: restaurantHandoverAt,
        restaurantCompensation: restaurantCompensation,
        restaurantChargeback: restaurantChargeback,
        scheduledFor: scheduledFor,
        driverTip: driverTip,
        commissionPercent: commissionPercent,
        couponCode: couponCode,
        discountAmount: discountAmount,
      );
}

/// وثيقة إثبات طلب واحد — مستند `order_proofs/{orderId}`: أزمنة وإحداثيات
/// المحطات الثلاث (وصول المطعم / الاستلام / التسليم) مع صورتَي الاستلام
/// والتسليم مضغوطتين داخل المستند نفسه (Blob).
///
/// لماذا داخل Firestore لا في Storage؟ تخزين الملفات ينتظر خطة Blaze؛
/// صورة مضغوطة (~٦٠ كيلوبايت) داخل مستند مستقل عن مستند الطلب تعمل اليوم
/// مجاناً، ولا تُبطئ قوائم الطلبات لأن أحداً لا يقرأ هذا المستند إلا شاشة
/// النزاع. عند الترقية يتحوّل التخزين إلى روابط Storage بلا تغيير في البنية.
class OrderProof {
  final String orderId;
  final String driverId;

  final DateTime? arrivedAt;
  final double? arrivedLat;
  final double? arrivedLng;

  final Uint8List? pickupPhoto;
  final DateTime? pickupAt;
  final double? pickupLat;
  final double? pickupLng;

  final Uint8List? deliveryPhoto;
  final DateTime? deliveryAt;
  final double? deliveryLat;
  final double? deliveryLng;

  /// بُعد السائق عن موقع العميل المسجّل لحظة التسليم (بالأمتار) — يُسجَّل
  /// دائماً، وقيمته الكبيرة بيّنة «سلّم في مكان آخر» عند النزاع.
  final int? deliveryDistanceMeters;

  const OrderProof({
    required this.orderId,
    required this.driverId,
    this.arrivedAt,
    this.arrivedLat,
    this.arrivedLng,
    this.pickupPhoto,
    this.pickupAt,
    this.pickupLat,
    this.pickupLng,
    this.deliveryPhoto,
    this.deliveryAt,
    this.deliveryLat,
    this.deliveryLng,
    this.deliveryDistanceMeters,
  });

  factory OrderProof.fromMap(Map<String, dynamic> map, String id) => OrderProof(
        orderId: id,
        driverId: map['driverId'] as String? ?? '',
        arrivedAt: (map['arrivedAt'] as Timestamp?)?.toDate(),
        arrivedLat: (map['arrivedLat'] as num?)?.toDouble(),
        arrivedLng: (map['arrivedLng'] as num?)?.toDouble(),
        pickupPhoto: (map['pickupPhoto'] as Blob?)?.bytes,
        pickupAt: (map['pickupAt'] as Timestamp?)?.toDate(),
        pickupLat: (map['pickupLat'] as num?)?.toDouble(),
        pickupLng: (map['pickupLng'] as num?)?.toDouble(),
        deliveryPhoto: (map['deliveryPhoto'] as Blob?)?.bytes,
        deliveryAt: (map['deliveryAt'] as Timestamp?)?.toDate(),
        deliveryLat: (map['deliveryLat'] as num?)?.toDouble(),
        deliveryLng: (map['deliveryLng'] as num?)?.toDouble(),
        deliveryDistanceMeters: (map['deliveryDistanceMeters'] as num?)?.toInt(),
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

  /// نص القرار الذي يكتبه المدير عند حلّ الشكوى. كان يُكتب في المستند ولا
  /// يقرؤه النموذج، فلا يراه مقدّم الشكوى أبداً — مع أنه جواب شكواه.
  final String? resolution;

  final String submittedByUid;
  final String submittedByName;
  final UserRole submittedByRole;

  final String? againstUid;
  final UserRole? againstRole;

  /// مهلة الرد المعلنة لمقدّم الشكوى — تُعرض «نردّ خلال 24 ساعة» ويُحسب
  /// منها الموعد المتوقع. التزام خدمة لا قيد تقني.
  static const Duration responseSla = Duration(hours: 24);

  /// الموعد الذي وعدنا بالرد قبله.
  DateTime get expectedResponseBy => createdAt.add(responseSla);

  /// رقم الشكوى المعروض للمستخدم وللإدارة في التواصل — مشتق ثابت من
  /// المعرّف، قصير يُقرأ ويُملى هاتفياً بسهولة.
  String get displayNumber {
    final clean = id.replaceAll('-', '').toUpperCase();
    return clean.length <= 6 ? clean : clean.substring(0, 6);
  }

  /// هل الشكوى ما تزال بانتظار معالجة الإدارة؟
  bool get isAwaitingAction =>
      status == ComplaintStatus.open || status == ComplaintStatus.inProgress;

  /// تذكرة عامة: فُتحت بلا ارتباط بطلب (مالية/تحديث بيانات/استفسار...) —
  /// تُعرض وتُحل بلا حقول الطلب (لا استرداد نسبة، لا خط إثبات).
  bool get isGeneralTicket => orderId.trim().isEmpty;

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
    this.resolution,
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
      resolution: map['resolution'] as String?,
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
        if (resolution != null) 'resolution': resolution,
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

  /// الخيارات المنتقاة لهذه التشكيلة (حجم/إضافات) — القائمة الفارغة تعني
  /// الصنف البسيط، وكل تشكيلة مختلفة سطرٌ مستقل في السلة.
  final List<ItemOption> selectedOptions;

  CartItem({
    required this.item,
    this.quantity = 1,
    this.extras,
    this.selectedOptions = const [],
  });

  /// سعر الوحدة بعد فروق الخيارات.
  double get unitPrice =>
      item.price + selectedOptions.fold(0.0, (s, o) => s + o.priceDelta);

  /// نص الخيارات للعرض والمفتاح: «كبير • جبن إضافي».
  String get optionsLabel => selectedOptions.map((o) => o.name).join(' • ');

  /// مفتاح التشكيلة: الصنف نفسه بخيارات مختلفة = سطران مستقلان.
  String get variantKey => '${item.id}|$optionsLabel';

  double get subtotal => unitPrice * quantity;
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

  /// انتهاء صلاحية الكود — null = بلا انتهاء (توافق خلفي مع الأكواد
  /// المولّدة قبل هذه الميزة).
  final DateTime? expiresAt;

  /// كود الكابتن الداعي، يُحمَّل على كود التسجيل حين يُولَّد من طلب انضمام
  /// جاء عبر رابط إحالة. يلتقطه التطبيق تلقائياً عند التسجيل، فلا تضيع
  /// الإحالة لأن المتقدّم نسي نقل كود الداعي بيده.
  final String referredByCode;

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
    this.expiresAt,
    this.referredByCode = '',
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

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
        expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
        referredByCode: map['referredByCode'] as String? ?? '',
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
        if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
        'referredByCode': referredByCode,
      };
}

/// طلب انضمام كابتن — يُملأ في صفحة التسجيل على الويب (zadgo.co/join)
/// وتُرفع فيه المستندات، ويراجعه المدير من تطبيقه قبل إصدار كود التسجيل.
///
/// لماذا مجموعة مستقلة لا حساب مباشر: القبول قرار إداري بعد فحص مستندات
/// نظامية (هيئة النقل)، لا تسجيل ذاتي. ولماذا الرفع على الويب: رفع
/// الملفات يتطلّب Firebase Storage الموقوف على ترقية Blaze، بينما
/// الاستضافة على zadgo.co تقبله اليوم — والتطبيق يعرض الصور بروابطها.
class DriverApplication {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String nationalId;
  final String vehicleType;
  final String vehiclePlate;
  final String referredByCode;

  /// المستندات: المفتاح اسمه المعياري أدناه، والقيمة إما رابط صورة (http)
  /// أو معرّف مستند Blob في `driver_application_docs` — التطبيق يفرّق
  /// بينهما بـstartsWith('http')، فانتقال /join إلى Storage بعد Blaze لا
  /// يغيّر هذا النموذج بحرف.
  final Map<String, String> documents;

  /// صور المركبة (أربع جهات) — قائمة مستقلة لأنها متعددة.
  final List<String> vehiclePhotos;

  final DriverApplicationStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String reviewNote;

  /// كود التسجيل الصادر عند القبول — يبقى ظاهراً للمدير ليعيد إرساله.
  final String issuedCode;

  const DriverApplication({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.nationalId = '',
    this.vehicleType = '',
    this.vehiclePlate = '',
    this.referredByCode = '',
    this.documents = const {},
    this.vehiclePhotos = const [],
    this.status = DriverApplicationStatus.pending,
    required this.createdAt,
    this.reviewedAt,
    this.reviewNote = '',
    this.issuedCode = '',
  });

  /// المستندات المطلوبة نظاميّاً بأسمائها المعروضة — الترتيب هو ترتيب
  /// المراجعة. وثيقة العمل الحر للسعوديين، وتفويض القيادة لمن ليست
  /// المركبة باسمه، فقد يغيبان بلا خلل.
  static const docLabels = <String, String>{
    'id': 'الهوية / الإقامة',
    'license': 'رخصة القيادة',
    'registration': 'الاستمارة (رخصة السير)',
    'insurance': 'وثيقة التأمين',
    'freelanceDoc': 'وثيقة العمل الحر',
    'criminalRecord': 'شهادة خلو السوابق',
    'drivingAuth': 'تفويض القيادة',
  };

  /// المستندات الإلزامية على الجميع — نقصها يُعرض تحذيراً للمدير قبل
  /// القبول، ولا يمنعه (قد يقبل بمستند وصل عبر واتساب).
  static const requiredDocs = ['id', 'license', 'registration', 'insurance'];

  List<String> get missingRequired => requiredDocs
      .where((k) => (documents[k] ?? '').trim().isEmpty)
      .toList();

  factory DriverApplication.fromMap(Map<String, dynamic> map, String id) {
    final rawDocs = map['documents'];
    final rawPhotos = map['vehiclePhotos'];
    return DriverApplication(
      id: id,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      nationalId: map['nationalId'] as String? ?? '',
      vehicleType: map['vehicleType'] as String? ?? '',
      vehiclePlate: map['vehiclePlate'] as String? ?? '',
      referredByCode:
          (map['referredByCode'] as String? ?? '').trim().toUpperCase(),
      documents: rawDocs is Map
          ? {
              for (final e in rawDocs.entries)
                if (e.value is String && (e.value as String).trim().isNotEmpty)
                  e.key.toString(): (e.value as String).trim(),
            }
          : const {},
      vehiclePhotos: rawPhotos is List
          ? rawPhotos
              .whereType<String>()
              .where((u) => u.trim().isNotEmpty)
              .toList()
          : const [],
      status: _applicationStatusFromString(map['status'] as String?),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
      reviewNote: map['reviewNote'] as String? ?? '',
      issuedCode: map['issuedCode'] as String? ?? '',
    );
  }
}

enum DriverApplicationStatus { pending, approved, rejected }

extension DriverApplicationStatusX on DriverApplicationStatus {
  String get label => switch (this) {
        DriverApplicationStatus.pending => 'بانتظار المراجعة',
        DriverApplicationStatus.approved => 'مقبول',
        DriverApplicationStatus.rejected => 'مرفوض',
      };

  Color get color => switch (this) {
        DriverApplicationStatus.pending => const Color(0xFFFF9800),
        DriverApplicationStatus.approved => const Color(0xFF4CAF50),
        DriverApplicationStatus.rejected => const Color(0xFFE53935),
      };
}

DriverApplicationStatus _applicationStatusFromString(String? raw) =>
    _enumValueFromString<DriverApplicationStatus>(
      raw,
      DriverApplicationStatus.values,
      DriverApplicationStatus.pending,
      'DriverApplicationStatus',
    );
/// بنر ترويجي أعلى شاشة مطاعم العميل — عروض، مطاعم جديدة، إعلانات موسمية.
///
/// الصورة رابط خارجي (المكان الطبيعي: zadgo.co/images — استبدال الملف
/// بنفس الاسم هناك يحدّث البنر عند الجميع بلا لمس للتطبيق). البنر يظهر
/// فقط حين [isActive]، فتتحكم الإدارة بالحملة تشغيلاً وإيقافاً بضغطة.
class PromoBanner {
  final String id;
  final String imageUrl;

  /// عنوان اختياري يظهر شريطاً أسفل الصورة (يُترك فارغاً لو كان النص
  /// مرسوماً داخل الصورة نفسها).
  final String title;

  /// معرّف مطعم اختياري: ضغطة البنر تفتح صفحته مباشرة.
  final String? restaurantId;

  final bool isActive;

  /// ترتيب العرض — الأصغر أولاً.
  final int sortOrder;
  final DateTime createdAt;

  const PromoBanner({
    required this.id,
    required this.imageUrl,
    this.title = '',
    this.restaurantId,
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory PromoBanner.fromMap(Map<String, dynamic> map, String id) => PromoBanner(
        id: id,
        imageUrl: map['imageUrl'] as String? ?? '',
        title: map['title'] as String? ?? '',
        restaurantId: map['restaurantId'] as String?,
        isActive: map['isActive'] as bool? ?? true,
        sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'imageUrl': imageUrl,
        'title': title,
        if (restaurantId != null) 'restaurantId': restaurantId,
        'isActive': isActive,
        'sortOrder': sortOrder,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
