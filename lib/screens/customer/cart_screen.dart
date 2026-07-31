// lib/screens/customer/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../utils/helpers.dart';
import '../../utils/payment_validator.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import '../admin/pick_location_screen.dart';
import 'my_orders_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('السلة')),
      body: cart.isEmpty
          ? const AppEmpty(emoji: '🛒', title: 'السلة فارغة')
          : Column(children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...cart.items.map((ci) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Text(ci.item.emoji, style: const TextStyle(fontSize: 26)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(ci.item.name)),
                            IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () => context.read<CartProvider>().remove(ci.item.id)),
                            Text('${ci.quantity}'),
                            IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => context.read<CartProvider>().add(
                                    ci.item,
                                    cart.restaurantId!,
                                    cart.restaurantName!,
                                    cart.restaurantEmoji ?? '🍽️',
                                    cart.deliveryFee,
                                    cart.restaurantLat,
                                    cart.restaurantLng)),
                            Text(formatCurrency(ci.subtotal),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ]),
                        )),
                    const Divider(),
                    PriceRow(label: 'المجموع', value: formatCurrency(cart.itemsTotal)),
                    PriceRow(label: 'التوصيل', value: formatCurrency(cart.deliveryFee)),
                    PriceRow(label: 'عمولة التطبيق 15%', value: formatCurrency(cart.platformCommission)),
                    const Divider(),
                    PriceRow(
                        label: 'الإجمالي',
                        value: formatCurrency(cart.grandTotalWithVat),
                        bold: true),
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
                      onPressed: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                      child: Text(
                          'المتابعة للدفع — ${formatCurrency(cart.grandTotalWithVat)}'),
                    ),
                  ),
                ),
              ),
            ]),
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
  final _cardHolderNameCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  PaymentMethod _payment = PaymentMethod.cash;
  bool _loading = false;
  double? _lat, _lng;

  double _getEffectiveDeliveryFee(CartProvider cart) {
    if (_lat == null || _lng == null || cart.restaurantLat == null || cart.restaurantLng == null) {
      return cart.deliveryFee;
    }
    final distance = calculateDistanceKm(_lat, _lng, cart.restaurantLat, cart.restaurantLng);
    return calculateDeliveryFee(distance);
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => PickLocationScreen(
          initialLocation: _lat != null && _lng != null ? LatLng(_lat!, _lng!) : null,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
      });
    }
  }

  Future<void> _openMapsNavigation() async {
    if (_lat == null || _lng == null) return;
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$_lat,$_lng&travelmode=driving');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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

    if (_payment == PaymentMethod.card) {
      final holderError = validateCreditCardHolderName(_cardHolderNameCtrl.text);
      if (holderError != null) {
        showError(context, holderError);
        return;
      }
      final numberError = validateCreditCardNumber(_cardNumberCtrl.text);
      if (numberError != null) {
        showError(context, numberError);
        return;
      }
      final expiryError = validateCreditCardExpiry(_expiryCtrl.text);
      if (expiryError != null) {
        showError(context, expiryError);
        return;
      }
      final cvvError = validateCreditCardCvv(_cvvCtrl.text);
      if (cvvError != null) {
        showError(context, cvvError);
        return;
      }
    }

    final cart = context.read<CartProvider>();
    final effectiveDeliveryFee = _getEffectiveDeliveryFee(cart);
    if (_payment != PaymentMethod.cash) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'تأكيد الدفع',
        content: _payment == PaymentMethod.card
            ? 'سيتم سحب مبلغ الطلب (${formatCurrency(cart.itemsTotal + effectiveDeliveryFee)}) من البطاقة. هل تريد المتابعة؟'
            : 'سيتم خصم مبلغ الطلب (${formatCurrency(cart.itemsTotal + effectiveDeliveryFee)}) من المحفظة الإلكترونية. هل تريد المتابعة؟',
        confirmLabel: 'متابعة',
      );
      if (confirmed != true) return;
    }

    setState(() => _loading = true);
    final auth = context.read<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();
    final user = auth.user!;
    const uuid = Uuid();
    final orderId = uuid.v4();

    final restaurant = await service.getRestaurantOnce(cart.restaurantId!);

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
      deliveryFee: _getEffectiveDeliveryFee(cart),
      orderNumber: orderId.substring(0, 6).toUpperCase(),
      platformCommission: cart.platformCommission,
      deliveryLat: _lat,
      deliveryLng: _lng,
      restaurantLat: cart.restaurantLat,
      restaurantLng: cart.restaurantLng,
    );
    try {
      await service.placeOrder(order);
      cart.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (_) => const MyOrdersScreen()), (r) => r.isFirst);
      showSuccess(
        context,
        _payment == PaymentMethod.card
            ? 'تم التحقق من البطاقة بنجاح وإرسال الطلب'
            : 'تم إرسال طلبك بنجاح!',
      );
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showError(context, 'فشل إرسال الطلب');
    }
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    _cardHolderNameCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('إتمام الطلب')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _addrCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
                hintText: 'عنوان التوصيل بالتفصيل',
                prefixIcon: Icon(Icons.location_on_outlined)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickLocation,
            icon: Icon(_lat != null ? Icons.check_circle : Icons.map_outlined,
                color: _lat != null ? AppColors.restaurantAccent : null),
            label: Text(_lat != null
                ? 'الموقع محدد ✓ (اضغط للتعديل)'
                : 'حدد موقعك على الخريطة'),
          ),
          if (_lat != null && _lng != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openMapsNavigation,
              icon: const Icon(Icons.navigation_outlined),
              label: const Text('فتح الاتجاهات في الخرائط'),
            ),
          ],
          const SizedBox(height: 20),
          const Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
          ...PaymentMethod.values.map((p) => RadioListTile<PaymentMethod>(
                value: p,
                groupValue: _payment,
                onChanged: (v) => setState(() => _payment = v!),
                title: Text(p.label),
              )),
          if (_payment == PaymentMethod.card) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('بيانات البطاقة', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cardHolderNameCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'اسم حامل البطاقة',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cardNumberCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CardNumberInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'رقم البطاقة',
                      prefixIcon: Icon(Icons.credit_card_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _expiryCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            ExpiryDateInputFormatter(),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'MM/YY',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _cvvCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'CVV',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ملخص الطلب', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(child: Text('المجموع')),
                  Text(formatCurrency(cart.itemsTotal)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Expanded(child: Text('التوصيل')),
                  Text(formatCurrency(_getEffectiveDeliveryFee(cart))),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Expanded(child: Text('عمولة التطبيق 15%')),
                  Text(formatCurrency(cart.platformCommission)),
                ]),
                const Divider(height: 20),
                Row(children: [
                  const Expanded(child: Text('الإجمالي المتوقع', style: TextStyle(fontWeight: FontWeight.bold))),
                  Text(formatCurrency(cart.itemsTotal + _getEffectiveDeliveryFee(cart)), style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _placeOrder,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('تأكيد الطلب'),
            ),
          ),
        ],
      ),
    );
  }
}
