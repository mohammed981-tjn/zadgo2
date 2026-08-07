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
                      ...cart.items.map(
                        (ci) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Text(ci.item.emoji, style: const TextStyle(fontSize: 26)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(ci.item.name)),
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () => context.read<CartProvider>().remove(ci.item.id),
                              ),
                              Text('${ci.quantity}'),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => context.read<CartProvider>().add(
                                  ci.item,
                                  cart.restaurantId!,
                                  cart.restaurantName!,
                                  cart.restaurantEmoji ?? '🍽️',
                                  cart.deliveryFee,
                                ),
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
      isPaid: _payment != PaymentMethod.cash,
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
    // العميل يدفع الوجبات + التوصيل + الرسم الثابت فقط (عمولة 15% تُخصم من
    // المطعم ولا تظهر للعميل).
    final total = itemsTotal + delivery + fixedFee;

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
          const SizedBox(height: 20),
          const Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
          ...PaymentMethod.values.map(
            (p) => RadioListTile<PaymentMethod>(
              value: p,
              groupValue: _payment,
              onChanged: (v) => setState(() => _payment = v!),
              title: Text(p.label),
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
                const Divider(),
                PriceRow(
                  label: 'الإجمالي',
                  value: locationSet ? formatCurrency(total) : '—',
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_loading || !locationSet) ? null : _placeOrder,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(locationSet
                      ? 'تأكيد الطلب • ${formatCurrency(total)}'
                      : 'حدّد موقعك أولاً'),
            ),
          ),
        ],
      ),
    );
  }
}