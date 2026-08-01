// lib/screens/customer/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/payment_validator.dart';
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
                                    cart.deliveryFee)),
                            Text(formatCurrency(ci.subtotal),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ]),
                        )),
                    const Divider(),
                    PriceRow(label: 'المجموع', value: formatCurrency(cart.itemsTotal)),
                    PriceRow(label: 'التوصيل', value: formatCurrency(cart.deliveryFee)),
                    PriceRow(label: 'الضريبة 15%', value: formatCurrency(cart.vat)),
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
  PaymentMethod _payment = PaymentMethod.cash;
  bool _loading = false;
  double? _lat, _lng;

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

  Future<void> _placeOrder() async {
    if (_addrCtrl.text.trim().isEmpty) {
      showError(context, 'أدخل عنوان التوصيل');
      return;
    }

    if (_payment == PaymentMethod.card) {
      final confirmed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const CreditCardInputScreen()),
      );
      if (confirmed != true) return;
    }

    await _doPlaceOrder();
  }

  Future<void> _doPlaceOrder() async {
    setState(() => _loading = true);
    final cart = context.read<CartProvider>();
    final auth = context.read<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();
    final user = auth.user!;
    const uuid = Uuid();
    final orderId = uuid.v4();

    final restaurant = await service.getRestaurantOnce(cart.restaurantId!);

    double? distanceKm;
    double deliveryFee = cart.deliveryFee;
    double driverEarning = cart.deliveryFee;
    double platformDeliveryFee = 0;
    if (restaurant?.lat != null && restaurant?.lng != null && _lat != null && _lng != null) {
      distanceKm = distanceKmBetween(restaurant!.lat!, restaurant.lng!, _lat!, _lng!);
      final breakdown = calculateDeliveryFee(distanceKm);
      deliveryFee = breakdown.total;
      driverEarning = breakdown.driverEarning;
      platformDeliveryFee = breakdown.platformFee;
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
      isPaid: _payment != PaymentMethod.cash,
      createdAt: DateTime.now(),
      deliveryFee: deliveryFee,
      orderNumber: orderId.substring(0, 6).toUpperCase(),
      platformCommission: cart.platformCommission,
      deliveryLat: _lat,
      deliveryLng: _lng,
      restaurantLat: restaurant?.lat,
      restaurantLng: restaurant?.lng,
      distanceKm: distanceKm,
      driverEarning: driverEarning,
      platformDeliveryFee: platformDeliveryFee,
    );
    try {
      await service.placeOrder(order);
      cart.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (_) => const MyOrdersScreen()), (r) => r.isFirst);
      showSuccess(context, 'تم إرسال طلبك بنجاح!');
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) showError(context, 'فشل إرسال الطلب');
    }
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
                color: _lat != null ? AppColors.success : null),
            label: Text(_lat != null
                ? 'الموقع محدد ✓ (اضغط للتعديل)'
                : 'حدد موقعك على الخريطة'),
          ),
          const SizedBox(height: 20),
          const Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
          ...PaymentMethod.values.map((p) => RadioListTile<PaymentMethod>(
                value: p,
                groupValue: _payment,
                onChanged: (v) => setState(() => _payment = v!),
                title: Text(p.label),
              )),
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

// ---------------------------------------------------------------------------
// Credit-card input screen
// ---------------------------------------------------------------------------

/// Formats a card number string with a space every four digits.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Formats expiry as MM/YY.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
          text: '', selection: TextSelection.collapsed(offset: 0));
    }
    final month = digits.substring(0, digits.length > 2 ? 2 : digits.length);
    final year = digits.length > 2 ? digits.substring(2, digits.length > 4 ? 4 : digits.length) : '';
    final text = year.isEmpty ? month : '$month/$year';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class CreditCardInputScreen extends StatefulWidget {
  const CreditCardInputScreen({super.key});

  @override
  State<CreditCardInputScreen> createState() => _CreditCardInputScreenState();
}

class _CreditCardInputScreenState extends State<CreditCardInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _holderCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  bool _obscureCvv = true;

  @override
  void dispose() {
    _holderCtrl.dispose();
    _numberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final error = PaymentValidator.validate(
      holderName: _holderCtrl.text,
      cardNumber: _numberCtrl.text,
      expiry: _expiryCtrl.text,
      cvv: _cvvCtrl.text,
    );
    if (error != null) {
      showError(context, error);
      return;
    }
    showSuccess(context, 'تم التحقق من البطاقة بنجاح');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بيانات البطاقة الائتمانية')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.credit_card_rounded, size: 64, color: AppColors.primary),
            const SizedBox(height: 20),
            TextFormField(
              controller: _holderCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'اسم حامل البطاقة',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _numberCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [_CardNumberFormatter()],
              decoration: const InputDecoration(
                labelText: 'رقم البطاقة',
                hintText: 'XXXX XXXX XXXX XXXX',
                prefixIcon: Icon(Icons.credit_card_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiryCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_ExpiryFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'تاريخ الانتهاء',
                      hintText: 'MM/YY',
                      prefixIcon: Icon(Icons.date_range_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _cvvCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: _obscureCvv,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      labelText: 'CVV',
                      hintText: '•••',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureCvv ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureCvv = !_obscureCvv),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('تحقق وأتمم الطلب'),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                '🔒 بياناتك آمنة ومشفرة',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
