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

  /// هل وافق السائق المُسند إليه هذا الطلب صراحةً؟
  ///
  /// عند الإسناد التلقائي (autoAssignNearestDriver) تكون دائماً true فوراً،
  /// لأن هذه الدالة لا تختار إلا سائقاً متصلاً (isOnline) أصلاً، فاتصاله
  /// نفسه يُعتبر موافقة ضمنية.
  ///
  /// عند الإسناد اليدوي من المدير (assignDriver): إن كان السائق متصلاً وقت
  /// الإسناد تكون true فوراً بنفس المنطق. إن كان غير متصل، تكون false —
  /// فيرى السائق لاحقاً (عند فتح التطبيق) بطاقة قبول/رفض صريحة لهذا الطلب
  /// تحديداً، قبل أن يصبح ملتزماً به.
  ///
  /// بمجرد أن يصبح الطلب في هذه الحالة (driverId موجود)، هذا الحقل هو من
  /// يحدد فقط هل يظهر للسائق زر قبول/رفض أم لا — لا علاقة له بإمكانية
  /// إلغاء الطلب بعد قبوله فعلياً (تلك حالة منفصلة تخص المدير وحده عبر
  /// reassignDriver عند تعطل/حادث السائق).
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

  /// هل ينتظر هذا الطلب قرار قبول/رفض صريح من السائق المُسند إليه؟
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