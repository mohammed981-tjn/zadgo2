import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../providers/cart_provider.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/food_visuals.dart';
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
                  child: Text(restaurant.address,
                      style: const TextStyle(color: AppColors.textGray, fontSize: 13)),
                ),
              ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            RestaurantAvatar(
                name: restaurant.name, imageUrl: restaurant.imageUrl, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(spacing: 12, runSpacing: 4, children: [
                _InfoChip(
                    icon: Icons.star_rounded,
                    label: restaurant.rating.toStringAsFixed(1),
                    color: AppColors.warning),
                _InfoChip(
                    icon: Icons.timer_outlined,
                    label: '${restaurant.estimatedTimeMin} دقيقة',
                    color: AppColors.textGray),
                _InfoChip(
                    icon: Icons.delivery_dining_outlined,
                    label: restaurant.deliveryFee > 0
                        ? formatCurrency(restaurant.deliveryFee)
                        : 'توصيل مجاني',
                    color: AppColors.textGray),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: StreamBuilder<List<MenuCategory>>(
            stream: service.streamCategories(restaurant.id),
            builder: (context, catSnap) {
              if (catSnap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(
                      'خطأ في تحميل الفئات:\n${catSnap.error}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }
              if (!catSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final cats = catSnap.data!;

              return StreamBuilder<List<MenuItem>>(
                stream: service.streamMenuItems(restaurant.id),
                builder: (context, itemSnap) {
                  if (itemSnap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SelectableText(
                          'خطأ في تحميل الأصناف:\n${itemSnap.error}',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }
                  if (!itemSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = itemSnap.data!;

                  final orderableItems = items.where((i) => i.canOrder).toList();
                  final catIds = cats.map((c) => c.id).toSet();

                  final unmatchedItems = orderableItems
                      .where((i) => !catIds.contains(i.categoryId))
                      .toList();
                  final visibleCats = cats
                      .where((cat) =>
                          orderableItems.any((i) => i.categoryId == cat.id))
                      .toList();

                  if (visibleCats.isEmpty && unmatchedItems.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('لا توجد أصناف متاحة حالياً',
                            style: TextStyle(fontSize: 16)),
                      ),
                    );
                  }

                  const otherCategory = MenuCategory(
                      id: '__other__', restaurantId: '', name: 'أصناف أخرى');

                  return ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      ...visibleCats.map((cat) {
                        final catItems = orderableItems
                            .where((i) => i.categoryId == cat.id)
                            .toList();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(cat.name,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark)),
                            ),
                            ...catItems.map((item) => _ItemTile(
                                item: item,
                                category: cat,
                                restaurant: restaurant)),
                          ],
                        );
                      }),
                      if (unmatchedItems.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(otherCategory.name,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark)),
                            ),
                            ...unmatchedItems.map((item) => _ItemTile(
                                item: item,
                                category: otherCategory,
                                restaurant: restaurant)),
                          ],
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ]),
      bottomNavigationBar: cart.itemCount > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CartScreen())),
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
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 13, color: color, fontWeight: FontWeight.w600)),
      ]);
}

class _ItemTile extends StatelessWidget {
  final MenuItem item;
  final MenuCategory category;
  final Restaurant restaurant;
  const _ItemTile(
      {required this.item, required this.category, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.quantityOf(item.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 1,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            item.name.trim().isEmpty ? '؟' : item.name.trim().substring(0, 1),
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary),
          ),
        ),
        title: Text(
          item.name.trim().isEmpty ? '(بلا اسم)' : item.name,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 15),
        ),
        subtitle: Text(
          '${item.price.toStringAsFixed(2)} ر.س',
          style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14),
        ),
        trailing: qty == 0
            ? SizedBox(
                width: 64,
                height: 36,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => context.read<CartProvider>().add(
                        item,
                        restaurant.id,
                        restaurant.name,
                        restaurant.emoji,
                        restaurant.driverShareFee,
                        restaurant.appShareFee,
                      ),
                  child: const Text('أضف', style: TextStyle(fontSize: 13)),
                ),
              )
            : SizedBox(
                width: 110,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32),
                    icon: const Icon(Icons.remove_circle_outline,
                        color: AppColors.primary, size: 22),
                    onPressed: () =>
                        context.read<CartProvider>().remove(item.id),
                  ),
                  Text('$qty',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87)),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32),
                    icon: const Icon(Icons.add_circle_outline,
                        color: AppColors.primary, size: 22),
                    onPressed: () => context.read<CartProvider>().add(
                          item,
                          restaurant.id,
                          restaurant.name,
                          restaurant.emoji,
                          restaurant.driverShareFee,
                          restaurant.appShareFee,
                        ),
                  ),
                ]),
              ),
      ),
    );
  }
}