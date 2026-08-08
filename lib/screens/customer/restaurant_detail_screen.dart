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
        title: Text(restaurant.displayName),
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
                if (restaurant.isNewlyListed)
                  const _InfoChip(
                      icon: Icons.fiber_new_rounded,
                      label: 'جديد',
                      color: AppColors.secondary)
                else
                  _InfoChip(
                      icon: Icons.star_rounded,
                      label: '${restaurant.rating.toStringAsFixed(1)} (${restaurant.ratingCount})',
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
    final isIncomplete = item.name.trim().isEmpty || item.price <= 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MenuItemVisual(
                categoryName: category.name,
                itemName: item.name,
                imageUrl: item.imageUrl,
                size: 60,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name.trim().isEmpty ? '(بلا اسم)' : item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textDark),
                  ),
                  if (item.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textGray, fontSize: 12.5),
                    ),
                  ],
                  // السعرات الحرارية — تُعرض مستقلةً عن الوصف بأيقونة واضحة،
                  // كما في تطبيقات التوصيل الكبرى، لا مدسوسةً داخل نصّ الوصف.
                  if (item.kcal != null && item.kcal! > 0) ...[
                    const SizedBox(height: 3),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.local_fire_department_outlined,
                          size: 13, color: AppColors.textGray),
                      const SizedBox(width: 3),
                      Text('${item.kcal} سعرة حرارية',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.textGray)),
                    ]),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatCurrency(item.price),
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                      _AddOrCounter(item: item, restaurant: restaurant, qty: qty),
                    ],
                  ),
                  if (isIncomplete) ...[
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.info_outline,
                          size: 13, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text('بيانات الصنف غير مكتملة',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// زر "أضف" أو عداد الكمية — معزول في ودجت خاص بعرض ثابت لمنع أي مشكلة
/// تمدد غير محدود داخل Row الأب.
class _AddOrCounter extends StatelessWidget {
  final MenuItem item;
  final Restaurant restaurant;
  final int qty;
  const _AddOrCounter(
      {required this.item, required this.restaurant, required this.qty});

  @override
  Widget build(BuildContext context) {
    if (qty == 0) {
      return SizedBox(
        height: 32,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
      );
    }
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          iconSize: 18,
          icon: const Icon(Icons.remove, color: AppColors.primary),
          onPressed: () => context.read<CartProvider>().remove(item.id),
        ),
        SizedBox(
          width: 20,
          child: Text('$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textDark)),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          iconSize: 18,
          icon: const Icon(Icons.add, color: AppColors.primary),
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
    );
  }
}