// lib/screens/customer/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';   // ← إضافة مهمة

import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

import '../auth/login_screen.dart';
import 'pick_location_screen.dart';
import 'my_orders_screen.dart';
import 'moyasar_payment_screen.dart';
import '../../utils/payment_config.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _proceedToCheckout(BuildContext context) async {
    final auth = context.read<app_auth.AuthProvider>();

    if (!auth.isLoggedIn) {
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen(fromCheckout: true)),
      );
      if (ok != true || !context.mounted) return;
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('السلة')),
      body: cart.isEmpty
          ? const AppEmpty(emoji: '🛒', title: 'السلة فارغة')
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // الأزرار تستهدف التشكيلة بعينها (مفتاح الصنف+خياراته)
                      // لا الصنف وحده — وإلا اختلطت «كبير» بـ«صغير».
                      ...cart.items.map(
                        (ci) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Text(ci.item.emoji, style: const TextStyle(fontSize: 26)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ci.item.name),
                                    if (ci.optionsLabel.isNotEmpty)
                                      Text(ci.optionsLabel,
                                          style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.textGray)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () => context.read<CartProvider>().remove(ci.variantKey),
                              ),
                              Text('${ci.quantity}'),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => context
                                    .read<CartProvider>()
                                    .incrementVariant(ci.variantKey),
                              ),
                              Text(
                                formatCurrency(ci.subtotal),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      PriceRow(
                        label: 'الوجبات',
                        value: formatCurrency(cart.itemsTotal),
                        bold: true,
                      ),
                      PriceRow(label: 'التوصيل', value: 'يُحسب عند تحديد الموقع'),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => _proceedToCheckout(context),
                        child: const Text('المتابعة للدفع'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addrCtrl = TextEditingController();
  PaymentMethod _payment = PaymentMethod.cash;

  /// موعد التوصيل المجدول (ح4) — فارغ = «في أقرب وقت» (السلوك القائم).
  DateTime? _scheduledFor;

  /// إكرامية الكابتن (ح3) — صفر افتراضاً، وخياراتها من إعدادات المدير.
  double _tip = 0;
  List<double> _tipOptions = const [2, 5, 10];
  // إعدادات المنصّة (أجرة التوصيل + الإكرامية) من اللوحة — الافتراضي مطابق
  // للقيم القديمة، فلا يتغيّر السلوك حتى يعدّلها المدير.
  IncentiveSettings _settings = const IncentiveSettings();
  bool _loading = false;
  /// هل يطبّق العميل رصيد محفظته على هذا الطلب؟
  bool _useWallet = true;

  double? _lat, _lng;

  // المطعم يُجلب مرة واحدة عند الفتح لنعرف موقعه ونحسب المسافة (ومنها أجرة
  // التوصيل) فور تحديد العميل لموقعه، فيظهر الإجمالي الحقيقي قبل التأكيد.
  Restaurant? _restaurant;
  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    // خيارات الإكرامية من لوحة المدير (ج١) — فشل الجلب يبقي الافتراضي.
    context.read<FirebaseService>().getIncentiveSettings().then((v) {
      if (mounted) setState(() {
        _settings = v;
        _tipOptions = v.tipOptions;
      });
    }).catchError((_) {});
    _loadRestaurant();
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    _couponCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurant() async {
    final cart = context.read<CartProvider>();
    final service = context.read<FirebaseService>();
    if (cart.restaurantId == null) return;
    final r = await service.getRestaurantOnce(cart.restaurantId!);
    if (!mounted) return;
    setState(() {
      _restaurant = r;
      _recomputeDistance();
    });
  }

  void _recomputeDistance() {
    if (_restaurant?.lat != null &&
        _restaurant?.lng != null &&
        _lat != null &&
        _lng != null) {
      _distanceKm = haversineDistanceKm(
        _restaurant!.lat!,
        _restaurant!.lng!,
        _lat!,
        _lng!,
      );
    } else {
      _distanceKm = null;
    }
  }

  /// أجرة التوصيل حسب المسافة المحسوبة؛ وإن تعذّر حساب المسافة (لا موقع للمطعم
  /// مثلاً) نكتفي بأجرة الأساس (أول 7 كم) بدل ترك التوصيل مجهولاً.
  double get _deliveryFee =>
      _settings.deliveryFeeFor(_distanceKm ?? 0);

  /// الكوبون المطبَّق (بعد تحقّق ناجح) وقيمة خصمه.
  Coupon? _coupon;
  final _couponCtrl = TextEditingController();
  bool _checkingCoupon = false;

  /// ملاحظة العميل على الطلب (لمسات العميل 2026-08-20): «بلا بصل»،
  /// «اتركه عند الباب»، «اتصل قبل الوصول» — تظهر للمطعم في بطاقة الطلب
  /// وللكابتن في مذكرة الاستلام. الحقل كان في النموذج ويُعرض لهما أصلاً
  /// لكن بلا مُدخلٍ يملؤه — فبقي فارغاً دائماً.
  final _noteCtrl = TextEditingController();

  /// قيمة خصم الكوبون على قيمة الوجبات (لا على التوصيل) — التوصيل حق
  /// السائق ولا يُخصم منه، والخصم تتحمّله المنصّة من حصّتها.
  double get _discount =>
      _coupon?.discountFor(context.read<CartProvider>().itemsTotal) ?? 0;

  /// إجمالي ما يدفعه العميل — مصدر واحد يستخدمه العرض وشحن البطاقة معاً، حتى
  /// لا يُشحن مبلغ يخالف ما رآه العميل على الشاشة.
  double _orderTotal() {
    final itemsTotal = context.read<CartProvider>().itemsTotal;
    final total =
        itemsTotal + _deliveryFee + _settings.deliveryAppCut - _discount;
    return total < 0 ? 0 : total;
  }

  Future<void> _applyCoupon() async {
    final auth = context.read<app_auth.AuthProvider>();
    final cart = context.read<CartProvider>();
    final service = context.read<FirebaseService>();
    if (!auth.isLoggedIn) {
      showError(context, 'سجّل الدخول أولاً لتطبيق كود الخصم');
      return;
    }
    setState(() => _checkingCoupon = true);
    try {
      final coupon = await service.validateCoupon(
        rawCode: _couponCtrl.text,
        userId: auth.user!.uid,
        itemsTotal: cart.itemsTotal,
        restaurantId: cart.restaurantId ?? '',
      );
      if (!mounted) return;
      setState(() {
        _coupon = coupon;
        _checkingCoupon = false;
      });
      showSuccess(context, 'طُبّق الخصم: ${formatCurrency(_discount)}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _coupon = null;
        _checkingCoupon = false;
      });
      showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// رصيد محفظة العميل المتاح.
  double get _walletBalance =>
      context.read<app_auth.AuthProvider>().user?.walletBalance ?? 0;

  /// المبلغ الذي سيُخصم من المحفظة: كامل الرصيد أو قيمة الطلب أيّهما أقل،
  /// فالرصيد يُطبَّق كخصم على الإجمالي لا كوسيلة دفع منفصلة — وهكذا يعمل
  /// الدفع الجزئي (رصيد 20 على طلب 54) بلا منطق إضافي.
  double _walletApplied() {
    if (!_useWallet) return 0;
    final balance = _walletBalance;
    if (balance <= 0) return 0;
    final total = _orderTotal();
    return balance >= total ? total : balance;
  }

  /// ما يتبقّى على العميل دفعه بعد خصم الرصيد — والإكرامية فوقه دائماً:
  /// لا تُدفع من المحفظة عمداً (رصيد المحفظة التزام داخلي على المنصّة،
  /// والإكرامية مالٌ يمر للكابتن مباشرة — نقداً بيده أو ببطاقة تُقيَّد له).
  double _amountDue() => _orderTotal() - _walletApplied() + _tip;

  // ← دالة تحويل الإحداثيات إلى عنوان
  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      final p = placemarks.first;

      return "${p.street}, ${p.locality}, ${p.administrativeArea}";
    } catch (e) {
      return "تعذر جلب العنوان";
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => PickLocationScreen(
          initialLocation: _lat != null && _lng != null
              ? LatLng(_lat!, _lng!)
              : null,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
        _recomputeDistance();
      });

      // ← جلب العنوان تلقائيًا ووضعه في خانة الإدخال
      final address = await _getAddressFromLatLng(_lat!, _lng!);
      setState(() {
        _addrCtrl.text = address;
      });
    }
  }

  Future<void> _placeOrder() async {
    if (_addrCtrl.text.trim().isEmpty) {
      showError(context, 'أدخل عنوان التوصيل');
      return;
    }

    if (_lat == null || _lng == null) {
      showError(context, 'حدد موقعك على الخريطة');
      return;
    }

    // منع الطلب خارج نطاق الخدمة: بدونه يُحتسب توصيل بمئات الريالات على طلب
    // لا يستطيع أي سائق تنفيذه.
    final distance = _distanceKm;
    if (distance != null && _settings.isOutOfRange(distance)) {
      showError(context,
          'الموقع خارج نطاق التوصيل (${distance.toStringAsFixed(0)} كم). '
          'الحد الأقصى ${_settings.maxDeliveryDistanceKm.toStringAsFixed(0)} كم');
      return;
    }

    // جلبٌ طازج لحظة التأكيد لا نسخة لحظة الفتح (مراجعة 2026-08-15): نسبة
    // العمولة وحالة الفتح وأجرة اللوحة قد تتغيّر بينما شاشة الدفع مفتوحة،
    // والقواعد تتحقق من **الطازج** — فختمٌ من نسخة مخبّأة يُرفض بعد شحن
    // البطاقة. الفشل هنا يوقف مبكراً قبل أي دفع.
    Restaurant? freshRestaurant;
    try {
      freshRestaurant =
          await context.read<FirebaseService>().getRestaurantOnce(
              context.read<CartProvider>().restaurantId!);
      if (!mounted) return;
      final freshSettings =
          await context.read<FirebaseService>().getIncentiveSettings();
      if (!mounted) return;
      setState(() {
        _restaurant = freshRestaurant;
        _settings = freshSettings;
      });
    } catch (_) {
      if (mounted) {
        showError(context, 'تعذّر تحديث بيانات المطعم — تحقق من الاتصال وحاول');
      }
      return;
    }
    // مطعم أُغلق والعميل ما زال في السلة: يُرفض قبل بوابة الدفع لا بعدها.
    // الطلب المجدول معفى — جدولته لموعدٍ قادم لا للحظة الإغلاق هذه.
    if (freshRestaurant != null &&
        !freshRestaurant.isOpenNow &&
        _scheduledFor == null) {
      showError(context,
          '${freshRestaurant.displayName} ${freshRestaurant.openStatusLabel} — '
          'جرّب الطلب المجدول أو عُد في وقت العمل');
      return;
    }

    // إعادة تحقق الكوبون لحظة الدفع لا لحظة اللصق فقط: بين الاثنتين قد
    // يعدّل العميل سلته تحت الحد الأدنى، أو توقف الإدارة الكود، أو ينتهي،
    // أو يستنفده الآخرون. النسخة المخبّأة في الشاشة لا تعرف شيئاً من ذلك.
    if (_coupon != null) {
      final cart0 = context.read<CartProvider>();
      try {
        final fresh = await context.read<FirebaseService>().validateCoupon(
              rawCode: _coupon!.code,
              userId: context.read<app_auth.AuthProvider>().user?.uid ?? '',
              itemsTotal: cart0.itemsTotal,
              restaurantId: cart0.restaurantId ?? '',
            );
        setState(() => _coupon = fresh);
      } catch (e) {
        setState(() => _coupon = null);
        if (mounted) {
          showError(context,
              'أُزيل الكوبون: ${e.toString().replaceFirst('Exception: ', '')}');
        }
        return;
      }
      if (!mounted) return;
    }

    // بوابة درع النقد (2026-08-20) — مرآةُ القاعدة برسالة مفهومة بدل
    // «رُفض الطلب» الغامضة، وحارسُ التزامن الذي لا تستطيعه القاعدة
    // (القواعد لا تعدّ). كل المقابض من لوحة المدير وصفرها يعطّلها.
    if (_payment == PaymentMethod.cash) {
      final me = context.read<app_auth.AuthProvider>().user;
      final s = _settings;
      if (me?.cashBlocked == true) {
        showError(context,
            'الدفع النقدي موقوف لحسابك بعد تكرار رفض الاستلام — يمكنك الدفع بالمحفظة أو البطاقة، أو تواصل مع الدعم');
        return;
      }
      if (s.firstCashOrderCap > 0 &&
          me?.cashTrusted != true &&
          _orderTotal() > s.firstCashOrderCap) {
        showError(context,
            'سقف أول طلب نقدي ${s.firstCashOrderCap.toStringAsFixed(0)} ر.س — قلّل السلة أو ادفع بالمحفظة/البطاقة، وبعد أول توصيلة يُرفع السقف');
        return;
      }
      if (s.maxConcurrentCashOrders > 0 && me != null) {
        try {
          final mine = await context
              .read<FirebaseService>()
              .streamCustomerOrders(me.uid)
              .first;
          final activeCash = mine
              .where((o) =>
                  o.status.isActive &&
                  o.paymentMethod == PaymentMethod.cash)
              .length;
          if (activeCash >= s.maxConcurrentCashOrders) {
            if (mounted) {
              showError(context,
                  'لديك $activeCash طلبات نقدية جارية — أكمل استلامها قبل طلبٍ نقدي جديد');
            }
            return;
          }
        } catch (_) {
          // تعذُّر العدّ لا يمنع الطلب — حارس تحسيني لا شرط.
        }
        if (!mounted) return;
      }
    }

    // الدفع بالبطاقة يسبق إنشاء الطلب: لا يُسجَّل طلب إلا بعد أن تؤكّد البوابة
    // شحن المبلغ فعلياً. العكس (إنشاء الطلب ثم محاولة الدفع) يُنتج طلبات
    // معلّقة بلا سداد يصعب تنظيفها لاحقاً.
    final walletApplied = _walletApplied();
    final amountDue = _amountDue();

    String? paymentId;
    // البطاقة تُشحن بالمتبقّي بعد خصم الرصيد فقط. وإن غطّى الرصيد كامل المبلغ
    // فلا حاجة لبوابة الدفع إطلاقاً.
    if (_payment == PaymentMethod.card && amountDue > 0) {
      final totalToCharge = amountDue;
      final result = await Navigator.push<MoyasarPaymentResult>(
        context,
        MaterialPageRoute(
          builder: (_) => MoyasarPaymentScreen(
            amountSar: totalToCharge,
            orderDescription: 'طلب ZadGo — ${_restaurant?.displayName ?? ''}',
          ),
        ),
      );
      // العميل خرج من شاشة الدفع دون إكمالها.
      if (result == null) return;
      if (!result.success) {
        if (mounted) {
          showError(context, result.errorMessage ?? 'فشلت عملية الدفع');
        }
        return;
      }
      paymentId = result.paymentId;

      // التحقق الخادمي قبل إنشاء الطلب: القواعد سترفض طلب بطاقة بلا ختم.
      // المبلغ محجوز فعلاً عند ميسر، فالفشل هنا لا يُلغي — يُعاد حتى ينجح
      // أو يقرر العميل التواصل مع الدعم (الدفعة تظهر عندنا بمعرّفها).
      var verified = false;
      while (!verified) {
        final service0 = context.read<FirebaseService>();
        verified = await service0.verifyCardPayment(paymentId ?? '');
        if (verified) break;
        if (!mounted) return;
        final retry = await showConfirmDialog(
          context,
          title: 'تعذّر توثيق الدفعة',
          content: 'دفعتك محجوزة برقم ($paymentId) لكن تعذّر توثيقها الآن '
              '(اتصال أو خادم). أعد المحاولة، أو احتفظ بالرقم وتواصل مع '
              'الدعم — لن يضيع مبلغك.',
          confirmLabel: 'إعادة المحاولة',
        );
        if (retry != true) return;
      }
    }

    if (!mounted) return;
    setState(() => _loading = true);

    final cart = context.read<CartProvider>();
    final auth = context.read<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();
    final user = auth.user!;
    const uuid = Uuid();
    final orderId = uuid.v4();

    // النسخة الطازجة المجلوبة أول الدالة — لا نسخة لحظة فتح الشاشة.
    final restaurant = freshRestaurant;

    // تسعير موحّد: التوصيل حسب المسافة (أجرة السائق)، ورسم المنصّة وأجرة
    // الكيلومترات من إعدادات اللوحة، والعمولة بالنسبة الفعّالة للمطعم.
    double? distanceKm;
    if (restaurant?.lat != null && restaurant?.lng != null) {
      distanceKm = haversineDistanceKm(restaurant!.lat!, restaurant.lng!, _lat!, _lng!);
    }
    final driverDeliveryFee = _settings.deliveryFeeFor(distanceKm ?? 0);

    final order = Order(
      id: orderId,
      restaurantId: cart.restaurantId!,
      restaurantName: cart.restaurantName!,
      customerId: user.uid,
      customerName: user.name,
      customerPhone: user.phone,
      deliveryAddress: _addrCtrl.text.trim(),
      // ملاحظة العميل تُختم على الطلب إن كتبها — null لا نص فارغ كي لا
      // يظهر سطر «ملاحظة:» خاوياً للمطعم والكابتن.
      notes: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      items: cart.toOrderItems(),
      paymentMethod: _payment,
      // السداد المسبق يثبت بمعرّف عملية حقيقي من البوابة فقط، لا بمجرّد اختيار
      // العميل «بطاقة» في القائمة.
      // الطلب مدفوع مسبقاً إن شُحنت البطاقة أو غطّى الرصيد كامل المبلغ.
      isPaid: paymentId != null || amountDue <= 0,
      paymentId: paymentId,
      walletUsed: walletApplied,
      // قيمة الخصم تُعاد كتابتها من الكوبون نفسه هنا (لا من نص على الشاشة)،
      // وتُحفظ محسوبةً فتبقى الفاتورة صحيحة لو عُدّل الكوبون أو حُذف.
      couponCode: _coupon?.code,
      discountAmount: _discount,
      scheduledFor: _scheduledFor,
      driverTip: _tip,
      // ختم نسبة عمولة المطعم لحظة الإنشاء (العمولة المرنة) — والقواعد
      // تتحقق أنها نسبة مستند المطعم نفسها لا رقماً يختلقه عميل معدَّل.
      // النسبة الفعّالة لا الاسمية: صفرٌ في فترة الإعفاء «مجاني حتى تاريخ»،
      // ثم المتفَّق عليها — تُختم على الطلب فينتهي الإعفاء تلقائياً في موعده.
      commissionPercent: restaurant?.effectiveCommissionPercent,
      createdAt: DateTime.now(),
      statusChangedAt: DateTime.now(),
      driverShare: driverDeliveryFee,
      appShare: _settings.deliveryAppCut,
      orderNumber: orderId.substring(0, 6).toUpperCase(),
      // بالنسبة الفعّالة لا 15% الثابتة: مطعم معفى («مجاني حتى») كان يُختم
      // طلبه بعمولة 15% هنا بينما commissionPercent صفر — تناقض تدقيق داخل
      // المستند نفسه (التسليم يعيد كتابتها لاحقاً فلا أثر مالياً، لكن
      // الصدق من الإنشاء أوجب).
      platformCommission: cart.itemsTotal *
          ((restaurant?.effectiveCommissionPercent ?? 15) / 100),
      deliveryLat: _lat,
      deliveryLng: _lng,
      restaurantLat: restaurant?.lat,
      restaurantLng: restaurant?.lng,
    );

    try {
      // خصم المحفظة وإنشاء الطلب معاً في معاملة ذرّية: لا يُخصم رصيدٌ إلا مع
      // ثبوت الطلب، فإن فشل الإنشاء رجع الرصيد تلقائياً (لا يقدر العميل ردّه
      // بنفسه — القواعد تمنع زيادة الرصيد). بلا محفظة يمرّ عبر placeOrder.
      await service.placeOrderWithWallet(order, walletApplied);
      cart.clear();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
        (r) => r.isFirst,
      );

      showSuccess(context, 'تم إرسال طلبك بنجاح!');
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      // فشل إنشاء الطلب: المحفظة رجعت ذرّياً. لكن إن كانت البطاقة قد شُحنت
      // فعلاً (paymentId موجود) فالمبلغ محجوز عند البوابة بلا طلب — لا نُخفي
      // ذلك برسالة عامة، بل نعطي العميل رقمه ليستردّه عبر الدعم (الاسترداد
      // الآلي يحتاج خادماً — مؤجَّل لـBlaze).
      if (paymentId != null) {
        await showConfirmDialog(
          context,
          title: 'تعذّر إنشاء الطلب بعد الدفع',
          content: 'خُصم مبلغ بطاقتك (رقم العملية: $paymentId) لكن تعذّر إنشاء '
              'الطلب. احتفظ بالرقم وتواصل مع الدعم — سيُستردّ مبلغك كاملاً.',
          confirmLabel: 'حسناً',
        );
      } else {
        showError(context, 'فشل إرسال الطلب، حاول مجدداً');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final itemsTotal = cart.itemsTotal;
    final locationSet = _lat != null && _lng != null;
    final delivery = _deliveryFee;
    final fixedFee = _settings.deliveryAppCut;
    // العميل يدفع الوجبات + التوصيل + الرسم الثابت، ناقصاً ما يُخصم من رصيد
    // محفظته (عمولة 15% تُخصم من المطعم ولا تظهر للعميل).
    final walletBalance = _walletBalance;
    final discount = _discount;
    final walletApplied = _walletApplied();
    final amountDue = _amountDue();
    final outOfRange = _distanceKm != null && _settings.isOutOfRange(_distanceKm!);

    return Scaffold(
      appBar: AppBar(title: const Text('إتمام الطلب')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // العناوين المحفوظة: أكثر خطوة متكرّرة إزعاجاً كانت تحديد الموقع على
          // الخريطة في كل طلب. اختيار عنوان محفوظ يملأ العنوان والإحداثيات
          // معاً بنقرة واحدة.
          Builder(builder: (context) {
            final saved = context
                    .watch<app_auth.AuthProvider>()
                    .user
                    ?.savedAddresses
                    .where((a) => a.hasLocation)
                    .toList() ??
                const <SavedAddress>[];
            if (saved.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('عناويني',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: saved.map((a) {
                      final selected = _lat == a.lat && _lng == a.lng;
                      return ChoiceChip(
                        label: Text(a.label),
                        selected: selected,
                        avatar: PhosphorIcon(PhosphorIcons.mapPin(), size: 16),
                        onSelected: (_) => setState(() {
                          _addrCtrl.text = a.address;
                          _lat = a.lat;
                          _lng = a.lng;
                          _recomputeDistance();
                        }),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
          TextField(
            controller: _addrCtrl,
            maxLines: 2,
            // أيقونة Phosphor ليست ثابتة تصريفياً — فك const عن الزخرفة.
            decoration: InputDecoration(
              hintText: 'عنوان التوصيل بالتفصيل',
              prefixIcon: PhosphorIcon(PhosphorIcons.mapPin(), size: 20),
            ),
          ),
          const SizedBox(height: 10),
          // ملاحظة الطلب (لمسات العميل): اختيارية، بحدّ ٢٠٠ حرف — تكفي
          // «بلا بصل» أو «اتركه عند الباب» ولا تتحوّل رسالةً.
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: 'ملاحظة للمطعم أو الكابتن (اختياري) — مثل: بلا بصل',
              prefixIcon: Icon(Icons.sticky_note_2_outlined, size: 20),
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          // وقت التوصيل (ح4): «في أقرب وقت» افتراضاً، أو موعدٌ يختاره —
          // بين ساعةٍ من الآن ويومين، فلا جدولة على مواعيد مضت ولا
          // التزامات بعيدة تُنسى.
          Row(children: [
            const Icon(Icons.schedule_rounded,
                size: 18, color: AppColors.textGray),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _scheduledFor == null
                    ? 'التوصيل: في أقرب وقت'
                    : 'مجدول: ${formatDateTime(_scheduledFor!)}',
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
            TextButton(
              onPressed: () async {
                final now = DateTime.now();
                final date = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 2)),
                );
                if (date == null || !context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime:
                      TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
                );
                if (time == null) return;
                final picked = DateTime(date.year, date.month, date.day,
                    time.hour, time.minute);
                if (picked.isBefore(now.add(const Duration(hours: 1)))) {
                  if (context.mounted) {
                    showError(context,
                        'أقرب موعد جدولة بعد ساعة من الآن — لما هو أعجل اختر «في أقرب وقت»');
                  }
                  return;
                }
                setState(() => _scheduledFor = picked);
              },
              child: Text(_scheduledFor == null ? 'جدولة' : 'تغيير'),
            ),
            if (_scheduledFor != null)
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'إلغاء الجدولة',
                onPressed: () => setState(() => _scheduledFor = null),
              ),
          ]),
          const SizedBox(height: 10),
          // إكرامية الكابتن (ح3): تصله كاملة بلا اقتطاع — والصياغة تقولها
          // صراحة لأنها سبب المنح أصلاً.
          Row(children: [
            const Text('🛵', style: TextStyle(fontSize: 17)),
            const SizedBox(width: 6),
            const Expanded(
              child: Text('إكرامية للكابتن؟ تصله كاملة',
                  style: TextStyle(fontSize: 13.5)),
            ),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            ChoiceChip(
              label: const Text('بلا'),
              selected: _tip == 0,
              onSelected: (_) => setState(() => _tip = 0),
            ),
            ..._tipOptions.map((v) => ChoiceChip(
                  label: Text('${v.toStringAsFixed(0)} ر.س'),
                  selected: _tip == v,
                  onSelected: (_) => setState(() => _tip = v),
                )),
          ]),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickLocation,
            icon: Icon(
              _lat != null ? Icons.check_circle : Icons.map_outlined,
              color: _lat != null ? AppColors.success : null,
            ),
            label: Text(
              _lat != null
                  ? 'الموقع محدد ✓ (اضغط للتعديل)'
                  : 'حدد موقعك على الخريطة',
            ),
          ),
          if (outOfRange)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.wrong_location_outlined,
                    color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الموقع يبعد ${_distanceKm!.toStringAsFixed(0)} كم عن المطعم — '
                    'خارج نطاق التوصيل (${_settings.maxDeliveryDistanceKm.toStringAsFixed(0)} كم). '
                    'اختر موقعاً أقرب.',
                    style: const TextStyle(color: AppColors.error, fontSize: 12.5),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 20),
          // رصيد المحفظة يُطبَّق كخصم على الإجمالي. يظهر فقط عند وجود رصيد،
          // فلا يزحم الشاشة لمن لا رصيد له.
          if (walletBalance > 0) ...[
            Card(
              color: AppColors.success.withOpacity(0.06),
              child: SwitchListTile(
                value: _useWallet,
                onChanged: (v) => setState(() => _useWallet = v),
                secondary: PhosphorIcon(PhosphorIcons.wallet(),
                    color: AppColors.success),
                title: Text('استخدام رصيد المحفظة (${formatCurrency(walletBalance)})',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  _useWallet && walletApplied > 0
                      ? 'سيُخصم ${formatCurrency(walletApplied)} من رصيدك'
                      : 'الرصيد لن يُستخدم في هذا الطلب',
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // إن غطّى الرصيد كامل المبلغ فلا حاجة لاختيار وسيلة دفع أصلاً.
          if (amountDue > 0)
            const Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
          // خيار البطاقة يظهر فقط عند تهيئة بوابة الدفع، فلا يصطدم العميل بخيار
          // لا يعمل. المحفظة مخفيّة حتى تُنفَّذ فعلياً.
          if (amountDue > 0)
            ...PaymentMethod.values
              .where((p) =>
                  p == PaymentMethod.cash ||
                  (p == PaymentMethod.card && PaymentConfig_.isConfigured))
              .map(
            (p) => RadioListTile<PaymentMethod>(
              value: p,
              groupValue: _payment,
              onChanged: (v) => setState(() => _payment = v!),
              title: Text(p.label),
              subtitle: p == PaymentMethod.card && PaymentConfig_.isTestKey
                  ? const Text('وضع الاختبار — لن يُسحب مبلغ حقيقي',
                      style: TextStyle(fontSize: 11.5, color: AppColors.warning))
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          // ملخّص المبلغ — يطمئن العميل لما سيدفعه قبل التأكيد. التوصيل يظهر
          // فعلياً بعد تحديد الموقع (لأنه يعتمد على المسافة).
          // كود الخصم — يُطبَّق قبل ملخص الدفع ليرى العميل أثره فوراً.
          Row(children: [
            Expanded(
              child: TextField(
                controller: _couponCtrl,
                textCapitalization: TextCapitalization.characters,
                enabled: _coupon == null,
                decoration: InputDecoration(
                  labelText: 'كود الخصم (اختياري)',
                  prefixIcon: PhosphorIcon(PhosphorIcons.ticket(), size: 20),
                  suffixIcon: _coupon == null
                      ? null
                      : IconButton(
                          tooltip: 'إزالة الكود',
                          icon: const Icon(Icons.close, color: AppColors.error),
                          onPressed: () => setState(() {
                            _coupon = null;
                            _couponCtrl.clear();
                          }),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed:
                    (_checkingCoupon || _coupon != null) ? null : _applyCoupon,
                child: Text(_checkingCoupon
                    ? '...'
                    : (_coupon == null ? 'تطبيق' : 'مُطبَّق ✓')),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                PriceRow(label: 'الوجبات', value: formatCurrency(itemsTotal)),
                // قاعدة المالك: «إجمالي التوصيل = التوصيل + العمولة الثابتة»
                // سطراً واحداً للعميل — الرسم الثابت (3 ر.س) حصّة المنصّة
                // تُضاف داخل التوصيل لا بنداً مستقلاً يستدعي التساؤل.
                // التقسيم الداخلي (أجرة السائق/حصّة المنصّة) باقٍ في الطلب
                // والتقارير كما هو.
                PriceRow(
                  label: 'التوصيل',
                  value: locationSet
                      ? formatCurrency(delivery + fixedFee)
                      : 'يُحسب بعد تحديد الموقع',
                ),
                if (discount > 0)
                  PriceRow(
                      label: 'خصم الكود ${_coupon!.code}',
                      value: '- ${formatCurrency(discount)}'),
                if (walletApplied > 0)
                  PriceRow(
                      label: 'خصم من المحفظة',
                      value: '- ${formatCurrency(walletApplied)}'),
                const Divider(),
                PriceRow(
                  label: walletApplied > 0 ? 'المتبقّي للدفع' : 'الإجمالي',
                  value: locationSet ? formatCurrency(amountDue) : '—',
                  bold: true,
                ),
                // سطر الضريبة المتضمَّنة — متطلب فوترة (ZATCA): الأسعار
                // شاملة الضريبة، وقيمتها تُستخرج بمعادلة المبلغ × 15 ÷ 115
                // (لا تُضاف فوق الإجمالي). إظهارها إفصاح لا رسوم جديدة.
                if (locationSet)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('شامل ضريبة القيمة المضافة (15٪)',
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.textGray)),
                        Text(
                          formatCurrency(Pricing.vatIncludedIn(
                              itemsTotal + delivery + fixedFee - discount)),
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.textGray),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed:
                  (_loading || !locationSet || outOfRange) ? null : _placeOrder,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(!locationSet
                      ? 'حدّد موقعك أولاً'
                      : outOfRange
                          ? 'الموقع خارج نطاق التوصيل'
                          : (amountDue <= 0
                              ? 'تأكيد الطلب • مدفوع من المحفظة'
                              : 'تأكيد الطلب • ${formatCurrency(amountDue)}')),
            ),
          ),
        ],
      ),
    );
  }
}