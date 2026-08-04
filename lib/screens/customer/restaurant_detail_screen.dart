import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../providers/cart_provider.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import 'cart_screen.dart';

class RestaurantDetailScreen extends StatelessWidget {
  final Restaurant restaurant;
  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(restaurant.name),
        bottom: restaurant.address.trim().isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    restaurant.address,
                    style: const TextStyle(color: AppColors.textGray, fontSize: 13),
                  ),
                ),
              ),
      ),
      body: StreamBuilder<List<MenuItem>>(
        stream: service.streamMenuItems(restaurant.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'خطأ في Firestore:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final items = snapshot.data ?? [];
          final orderableItems = items.where((i) => i.canOrder).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      RestaurantAvatar(
                        name: restaurant.name,
                        imageUrl: restaurant.imageUrl,
                        size: 56,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            _InfoChip(
                              icon: Icons.star_rounded,
                              label: restaurant.rating.toStringAsFixed(1),
                              color: AppColors.warning,
                            ),
                            _InfoChip(
                              icon: Icons.timer_outlined,
                              label: '${restaurant.estimatedTimeMin} دقيقة',
                              color: AppColors.textGray,
                            ),
                            _InfoChip(
                              icon: Icons.delivery_dining_outlined,
                              label: restaurant.deliveryFee > 0
                                  ? formatCurrency(restaurant.deliveryFee)
                                  : 'توصيل مجاني',
                              color: AppColors.textGray,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // شريط تشخيص — يؤكد وصول البيانات وتحديث الملف فعلياً.
                Container(
                  width: double.infinity,
                  color: Colors.yellow,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    '🔴 اختبار 777 — وصل ${items.length} صنف، ${orderableItems.length} قابل للطلب',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),

                if (orderableItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: AppEmpty(
                        emoji: '🍽️',
                        title: 'لا توجد أصناف متاحة',
                      ),
                    ),
                  ),

                ...orderableItems.map((item) => _BasicItemCard(item: item)),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: cart.itemCount > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  ),
                  child: Text('عرض السلة (${cart.itemCount})'),
                ),
              ),
            )
          : null,
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      );
}

/// بطاقة تشخيصية تتجاهل الثيم العام بالكامل:
/// خلفية صفراء صارخة (لتأكيد أن البطاقة تُبنى وتأخذ مساحتها فعلياً)،
/// وارتفاع ثابت 100 (يمنع أي انهيار تخطيط يجعلها بارتفاع صفر)،
/// و DefaultTextStyle يفرض لون وحجم النص صراحة (يتجاوز أي لون أو حجم
/// قد يفرضه الثيم العام ويجعل النص غير مرئي).
class _BasicItemCard extends StatelessWidget {
  final MenuItem item;
  const _BasicItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      color: Colors.yellow,
      child: DefaultTextStyle(
        style: const TextStyle(
          fontSize: 18,
          color: Colors.red,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(item.name.isEmpty ? '(بلا اسم)' : item.name),
            const SizedBox(height: 6),
            Text('${item.price} ر.س'),
          ],
        ),
      ),
    );
  }
}