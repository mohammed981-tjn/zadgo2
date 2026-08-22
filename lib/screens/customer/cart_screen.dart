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
import '../../utils/app_lang.dart';
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
      appBar: AppBar(title: Text(tr('السلة', 'Cart'))),
      body: cart.isEmpty
          ? AppEmpty(emoji: '🛒', title: tr('السلة فارغة', 'Your cart is empty'))
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
                        label: tr('الوجبات', 'Food'),
                        value: formatCurrency(cart.itemsTotal),
                        bold: true,
                      ),
                      PriceRow(
                          label: tr('التوصيل', 'Delivery'),
                          value: tr('يُحسب عند تحديد الموقع',
                              'Calculated after setting your location')),
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
                        child: Text(tr('المتابعة للدفع', 'Continue to checkout')),
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
      showError(
          context,
          tr('سجّل الدخول أولاً لتطبيق كود الخصم',
              'Sign in first to apply a promo code'));
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
      showSuccess(
          context,
          tr('طُبّق الخصم: ${formatCurrency(_discount)}',
              'Discount applied: ${formatCurrency(_discount)}'));
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
      return tr('تعذر جلب العنوان', 'Couldn\'t fetch the address');
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
      showError(context, tr('أدخل عنوان التوصيل', 'Enter the delivery address'));
      return;
    }

    if (_lat == null || _lng == null) {
      showError(context,
          tr('حدد موقعك على الخريطة', 'Set your location on the map'));
      return;
    }

    // منع الطلب خارج نطاق الخدمة: بدونه يُحتسب توصيل بمئات الريالات على طلب
    // لا يستطيع أي سائق تنفيذه.
    final distance = _distanceKm;
    if (distance != null && _settings.isOutOfRange(distance)) {
      showError(
          context,
          tr(
              'الموقع خارج نطاق التوصيل (${distance.toStringAsFixed(0)} كم). '
                  'الحد الأقصى ${_settings.maxDeliveryDistanceKm.toStringAsFixed(0)} كم',
              'Location is outside the delivery area (${distance.toStringAsFixed(0)} km). '
                  'Maximum is ${_settings.maxDeliveryDistanceKm.toStringAsFixed(0)} km'));
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
        showError(
            context,
            tr('تعذّر تحديث بيانات المطعم — تحقق من الاتصال وحاول',
                'Couldn\'t refresh restaurant details — check your connection and try again'));
      }
      return;
    }
    // مطعم أُغلق والعميل ما زال في السلة: يُرفض قبل بوابة الدفع لا بعدها.
    // الطلب المجدول معفى — جدولته لموعدٍ قادم لا للحظة الإغلاق هذه.
    if (freshRestaurant != null &&
        !freshRestaurant.isOpenNow &&
        _scheduledFor == null) {
      showError(
          context,
          tr(
              '${freshRestaurant.displayName} ${freshRestaurant.openStatusLabel} — '
                  'جرّب الطلب المجدول أو عُد في وقت العمل',
              '${freshRestaurant.displayName} ${freshRestaurant.openStatusLabel} — '
                  'try scheduling the order or come back during opening hours'));
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
          showError(
              context,
              tr('أُزيل الكوبون: ${e.toString().replaceFirst('Exception: ', '')}',
                  'Coupon removed: ${e.toString().replaceFirst('Exception: ', '')}'));
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
        showError(
            context,
            tr('الدفع النقدي موقوف لحسابك بعد تكرار رفض الاستلام — يمكنك الدفع بالمحفظة أو البطاقة، أو تواصل مع الدعم',
                'Cash payment is suspended on your account after repeated refused deliveries — pay by wallet or card, or contact support'));
        return;
      }
      if (s.firstCashOrderCap > 0 &&
          me?.cashTrusted != true &&
          _orderTotal() > s.firstCashOrderCap) {
        showError(
            context,
            tr('سقف أول طلب نقدي ${s.firstCashOrderCap.toStringAsFixed(0)} ر.س — قلّل السلة أو ادفع بالمحفظة/البطاقة، وبعد أول توصيلة يُرفع السقف',
                'First cash order is capped at ${s.firstCashOrderCap.toStringAsFixed(0)} SAR — trim your cart or pay by wallet/card; the cap lifts after your first delivery'));
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
              showError(
                  context,
                  tr('لديك $activeCash طلبات نقدية جارية — أكمل استلامها قبل طلبٍ نقدي جديد',
                      'You have $activeCash active cash orders — receive them before placing a new cash order'));
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
            orderDescription: tr('طلب ZadGo — ${_restaurant?.displayName ?? ''}',
                'ZadGo order — ${_restaurant?.displayName ?? ''}'),
          ),
        ),
      );
      // العميل خرج من شاشة الدفع دون إكمالها.
      if (result == null) return;
      if (!result.success) {
        if (mounted) {
          showError(context,
              result.errorMessage ?? tr('فشلت عملية الدفع', 'Payment failed'));
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
          title: tr('تعذّر توثيق الدفعة', 'Couldn\'t verify the payment'),
          content: tr(
              'دفعتك محجوزة برقم ($paymentId) لكن تعذّر توثيقها الآن '
                  '(اتصال أو خادم). أعد المحاولة، أو احتفظ بالرقم وتواصل مع '
                  'الدعم — لن يضيع مبلغك.',
              'Your payment is held under reference ($paymentId) but couldn\'t '
                  'be verified right now (connection or server). Retry, or keep '
                  'the reference and contact support — your money won\'t be lost.'),
          confirmLabel: tr('إعادة المحاولة', 'Retry'),
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
      // المبلغ المشحون على البطاقة بالهللات (دفعة ٠-ب، C3): تطابقه القاعدة
      // مع ختم verify.php فلا يمرّ طلبٌ بقيمة كبيرة خلف دفعةٍ صغيرة. يُكتب
      // للطلبات المدفوعة بالبطاقة فقط (amountDue هو ما شُحن فعلاً).
      cardAmountHalalas:
          paymentId != null ? (amountDue * 100).round() : null,
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

      showSuccess(context, tr('تم إرسال طلبك بنجاح!', 'Your order is in!'));
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
          title: tr('تعذّر إنشاء الطلب بعد الدفع',
              'Couldn\'t create the order after payment'),
          content: tr(
              'خُصم مبلغ بطاقتك (رقم العملية: $paymentId) لكن تعذّر إنشاء '
                  'الطلب. احتفظ بالرقم وتواصل مع الدعم — سيُستردّ مبلغك كاملاً.',
              'Your card was charged (reference: $paymentId) but the order '
                  'couldn\'t be created. Keep the reference and contact support '
                  '— you\'ll be refunded in full.'),
          confirmLabel: tr('حسناً', 'OK'),
        );
      } else {
        showError(context,
            tr('فشل إرسال الطلب، حاول مجدداً', 'Couldn\'t place the order, please try again'));
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
      appBar: AppBar(title: Text(tr('إتمام الطلب', 'Checkout'))),
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
                  Text(tr('عناويني', 'My addresses'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14.5)),
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
              hintText: tr('عنوان التوصيل بالتفصيل', 'Full delivery address'),
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
            decoration: InputDecoration(
              hintText: tr('ملاحظة للمطعم أو الكابتن (اختياري) — مثل: بلا بصل',
                  'Note for the restaurant or captain (optional) — e.g. no onions'),
              prefixIcon: const Icon(Icons.sticky_note_2_outlined, size: 20),
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
                    ? tr('التوصيل: في أقرب وقت', 'Delivery: as soon as possible')
                    : tr('مجدول: ${formatDateTime(_scheduledFor!)}',
                        'Scheduled: ${formatDateTime(_scheduledFor!)}'),
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
                    showError(
                        context,
                        tr('أقرب موعد جدولة بعد ساعة من الآن — لما هو أعجل اختر «في أقرب وقت»',
                            'Earliest scheduling is one hour from now — for anything sooner choose "as soon as possible"'));
                  }
                  return;
                }
                setState(() => _scheduledFor = picked);
              },
              child: Text(_scheduledFor == null
                  ? tr('جدولة', 'Schedule')
                  : tr('تغيير', 'Change')),
            ),
            if (_scheduledFor != null)
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                tooltip: tr('إلغاء الجدولة', 'Remove schedule'),
                onPressed: () => setState(() => _scheduledFor = null),
              ),
          ]),
          const SizedBox(height: 10),
          // إكرامية الكابتن (ح3): تصله كاملة بلا اقتطاع — والصياغة تقولها
          // صراحة لأنها سبب المنح أصلاً.
          Row(children: [
            const Text('🛵', style: TextStyle(fontSize: 17)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  tr('إكرامية للكابتن؟ تصله كاملة',
                      'Tip the captain? They keep 100%'),
                  style: const TextStyle(fontSize: 13.5)),
            ),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            ChoiceChip(
              label: Text(tr('بلا', 'No tip')),
              selected: _tip == 0,
              onSelected: (_) => setState(() => _tip = 0),
            ),
            ..._tipOptions.map((v) => ChoiceChip(
                  label: Text(tr('${v.toStringAsFixed(0)} ر.س',
                      '${v.toStringAsFixed(0)} SAR')),
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
                  ? tr('الموقع محدد ✓ (اضغط للتعديل)', 'Location set ✓ (tap to change)')
                  : tr('حدد موقعك على الخريطة', 'Set your location on the map'),
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
                    tr(
                        'الموقع يبعد ${_distanceKm!.toStringAsFixed(0)} كم عن المطعم — '
                            'خارج نطاق التوصيل (${_settings.maxDeliveryDistanceKm.toStringAsFixed(0)} كم). '
                            'اختر موقعاً أقرب.',
                        'This location is ${_distanceKm!.toStringAsFixed(0)} km from the restaurant — '
                            'outside the delivery area (${_settings.maxDeliveryDistanceKm.toStringAsFixed(0)} km). '
                            'Pick somewhere closer.'),
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
                title: Text(
                    tr('استخدام رصيد المحفظة (${formatCurrency(walletBalance)})',
                        'Use wallet balance (${formatCurrency(walletBalance)})'),
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  _useWallet && walletApplied > 0
                      ? tr('سيُخصم ${formatCurrency(walletApplied)} من رصيدك',
                          '${formatCurrency(walletApplied)} will be deducted from your balance')
                      : tr('الرصيد لن يُستخدم في هذا الطلب',
                          'Your balance won\'t be used on this order'),
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // إن غطّى الرصيد كامل المبلغ فلا حاجة لاختيار وسيلة دفع أصلاً.
          if (amountDue > 0)
            Text(tr('طريقة الدفع', 'Payment method'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  ? Text(
                      tr('وضع الاختبار — لن يُسحب مبلغ حقيقي',
                          'Test mode — no real money will be charged'),
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.warning))
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
                  labelText: tr('كود الخصم (اختياري)', 'Promo code (optional)'),
                  prefixIcon: PhosphorIcon(PhosphorIcons.ticket(), size: 20),
                  suffixIcon: _coupon == null
                      ? null
                      : IconButton(
                          tooltip: tr('إزالة الكود', 'Remove code'),
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
                    : (_coupon == null
                        ? tr('تطبيق', 'Apply')
                        : tr('مُطبَّق ✓', 'Applied ✓'))),
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
                PriceRow(
                    label: tr('الوجبات', 'Food'),
                    value: formatCurrency(itemsTotal)),
                // قاعدة المالك: «إجمالي التوصيل = التوصيل + العمولة الثابتة»
                // سطراً واحداً للعميل — الرسم الثابت (3 ر.س) حصّة المنصّة
                // تُضاف داخل التوصيل لا بنداً مستقلاً يستدعي التساؤل.
                // التقسيم الداخلي (أجرة السائق/حصّة المنصّة) باقٍ في الطلب
                // والتقارير كما هو.
                PriceRow(
                  label: tr('التوصيل', 'Delivery'),
                  value: locationSet
                      ? formatCurrency(delivery + fixedFee)
                      : tr('يُحسب بعد تحديد الموقع',
                          'Calculated after setting your location'),
                ),
                if (discount > 0)
                  PriceRow(
                      label: tr('خصم الكود ${_coupon!.code}',
                          'Promo code ${_coupon!.code}'),
                      value: '- ${formatCurrency(discount)}'),
                if (walletApplied > 0)
                  PriceRow(
                      label: tr('خصم من المحفظة', 'Wallet credit'),
                      value: '- ${formatCurrency(walletApplied)}'),
                const Divider(),
                PriceRow(
                  label: walletApplied > 0
                      ? tr('المتبقّي للدفع', 'Remaining to pay')
                      : tr('الإجمالي', 'Total'),
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
                        Text(tr('شامل ضريبة القيمة المضافة (15٪)', 'Includes 15% VAT'),
                            style: const TextStyle(
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
                  // كحليّ لا أبيض: خلفية الزر ذهبية ومقدّمتها كحلية عبر الثيم.
                  ? const CircularProgressIndicator(color: AppColors.dark)
                  : Text(!locationSet
                      ? tr('حدّد موقعك أولاً', 'Set your location first')
                      : outOfRange
                          ? tr('الموقع خارج نطاق التوصيل',
                              'Location outside the delivery area')
                          : (amountDue <= 0
                              ? tr('تأكيد الطلب • مدفوع من المحفظة',
                                  'Place order • paid from wallet')
                              : tr('تأكيد الطلب • ${formatCurrency(amountDue)}',
                                  'Place order • ${formatCurrency(amountDue)}'))),
            ),
          ),
        ],
      ),
    );
  }
}