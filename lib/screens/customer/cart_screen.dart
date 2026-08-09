// lib/screens/customer/cart_screen.dart
import 'package:flutter/material.dart';
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
    _loadRestaurant();
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
      Pricing.deliveryFee(_distanceKm ?? 0);

  /// إجمالي ما يدفعه العميل — مصدر واحد يستخدمه العرض وشحن البطاقة معاً، حتى
  /// لا يُشحن مبلغ يخالف ما رآه العميل على الشاشة.
  double _orderTotal() {
    final itemsTotal = context.read<CartProvider>().itemsTotal;
    return itemsTotal + _deliveryFee + Pricing.fixedDeliveryCommission;
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

  /// ما يتبقّى على العميل دفعه بعد خصم الرصيد.
  double _amountDue() => _orderTotal() - _walletApplied();

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
    if (distance != null && Pricing.isOutOfRange(distance)) {
      showError(context,
          'الموقع خارج نطاق التوصيل (${distance.toStringAsFixed(0)} كم). '
          'الحد الأقصى ${Pricing.maxDeliveryDistanceKm.toStringAsFixed(0)} كم');
      return;
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
    }

    if (!mounted) return;
    setState(() => _loading = true);

    final cart = context.read<CartProvider>();
    final auth = context.read<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();
    final user = auth.user!;
    const uuid = Uuid();
    final orderId = uuid.v4();

    final restaurant = _restaurant ?? await service.getRestaurantOnce(cart.restaurantId!);

    // تسعير موحّد: التوصيل حسب المسافة (أجرة السائق)، ورسم ثابت للتطبيق (3 ر.س)
    // كحصّة التطبيق من التوصيل، وعمولة 15% على قيمة الوجبات.
    double? distanceKm;
    if (restaurant?.lat != null && restaurant?.lng != null) {
      distanceKm = haversineDistanceKm(restaurant!.lat!, restaurant.lng!, _lat!, _lng!);
    }
    final driverDeliveryFee = Pricing.deliveryFee(distanceKm ?? 0);

    // خصم الرصيد قبل إنشاء الطلب: لو فشل الخصم (رصيد غير كافٍ لتغيّره من جهاز
    // آخر) لا يُنشأ طلب يفترض خصماً لم يحدث.
    if (walletApplied > 0) {
      try {
        await service.spendFromWallet(
          userId: user.uid,
          amount: walletApplied,
          orderId: orderId,
          orderNumber: orderId.substring(0, 6).toUpperCase(),
        );
      } catch (_) {
        if (mounted) {
          setState(() => _loading = false);
          showError(context, 'تعذّر خصم رصيد المحفظة، حدّث الصفحة وحاول مجدداً');
        }
        return;
      }
    }

    final order = Order(
      id: orderId,
      restaurantId: cart.restaurantId!,
      restaurantName: cart.restaurantName!,
      customerId: user.uid,
      customerName: user.name,
      customerPhone: user.phone,
      deliveryAddress: _addrCtrl.text.trim(),
      items: cart.toOrderItems(),
      paymentMethod: _payment,
      // السداد المسبق يثبت بمعرّف عملية حقيقي من البوابة فقط، لا بمجرّد اختيار
      // العميل «بطاقة» في القائمة.
      // الطلب مدفوع مسبقاً إن شُحنت البطاقة أو غطّى الرصيد كامل المبلغ.
      isPaid: paymentId != null || amountDue <= 0,
      paymentId: paymentId,
      walletUsed: walletApplied,
      createdAt: DateTime.now(),
      statusChangedAt: DateTime.now(),
      driverShare: driverDeliveryFee,
      appShare: Pricing.fixedDeliveryCommission,
      orderNumber: orderId.substring(0, 6).toUpperCase(),
      platformCommission: Pricing.appCommission(cart.itemsTotal),
      deliveryLat: _lat,
      deliveryLng: _lng,
      restaurantLat: restaurant?.lat,
      restaurantLng: restaurant?.lng,
    );

    try {
      await service.placeOrder(order);
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
      if (mounted) showError(context, 'فشل إرسال الطلب');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final itemsTotal = cart.itemsTotal;
    final locationSet = _lat != null && _lng != null;
    final delivery = _deliveryFee;
    const fixedFee = Pricing.fixedDeliveryCommission;
    // العميل يدفع الوجبات + التوصيل + الرسم الثابت، ناقصاً ما يُخصم من رصيد
    // محفظته (عمولة 15% تُخصم من المطعم ولا تظهر للعميل).
    final walletBalance = _walletBalance;
    final walletApplied = _walletApplied();
    final amountDue = _amountDue();
    final outOfRange = _distanceKm != null && Pricing.isOutOfRange(_distanceKm!);

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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: saved.map((a) {
                      final selected = _lat == a.lat && _lng == a.lng;
                      return ChoiceChip(
                        label: Text(a.label),
                        selected: selected,
                        avatar: const Icon(Icons.place_outlined, size: 16),
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
            decoration: const InputDecoration(
              hintText: 'عنوان التوصيل بالتفصيل',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
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
                    'خارج نطاق التوصيل (${Pricing.maxDeliveryDistanceKm.toStringAsFixed(0)} كم). '
                    'اختر موقعاً أقرب.',
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
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
                secondary: const Icon(Icons.account_balance_wallet_rounded,
                    color: AppColors.success),
                title: Text('استخدام رصيد المحفظة (${formatCurrency(walletBalance)})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  _useWallet && walletApplied > 0
                      ? 'سيُخصم ${formatCurrency(walletApplied)} من رصيدك'
                      : 'الرصيد لن يُستخدم في هذا الطلب',
                  style: const TextStyle(fontSize: 11),
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
                      style: TextStyle(fontSize: 11, color: AppColors.warning))
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          // ملخّص المبلغ — يطمئن العميل لما سيدفعه قبل التأكيد. التوصيل يظهر
          // فعلياً بعد تحديد الموقع (لأنه يعتمد على المسافة).
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                PriceRow(label: 'الوجبات', value: formatCurrency(itemsTotal)),
                PriceRow(
                  label: 'التوصيل',
                  value: locationSet
                      ? formatCurrency(delivery)
                      : 'يُحسب بعد تحديد الموقع',
                ),
                PriceRow(label: 'رسوم توصيل ثابتة', value: formatCurrency(fixedFee)),
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
                          formatCurrency(
                              Pricing.vatIncludedIn(itemsTotal + delivery + fixedFee)),
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