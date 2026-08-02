import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../providers/cart_provider.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/food_visuals.dart';
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
        // اسم الفرع/الحي يُميّز بين فرعين لنفس المطعم في حيَّين مختلفين.
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
            RestaurantAvatar(name: restaurant.name, imageUrl: restaurant.imageUrl, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(spacing: 12, runSpacing: 4, children: [
                _InfoChip(icon: Icons.star_rounded, label: restaurant.rating.toStringAsFixed(1), color: AppColors.warning),
                _InfoChip(icon: Icons.timer_outlined, label: '${restaurant.estimatedTimeMin} دقيقة', color: AppColors.textGray),
                _InfoChip(icon: Icons.delivery_dining_outlined,
                    label: restaurant.deliveryFee > 0 ? formatCurrency(restaurant.deliveryFee) : 'توصيل مجاني',
                    color: AppColors.textGray),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: AppStreamBuilder<List<MenuCategory>>(stream: () => service.streamCategories(restaurant.id), builder: (ctx, cats) {
            return AppStreamBuilder<List<MenuItem>>(stream: () => service.streamMenuItems(restaurant.id), builder: (ctx2, items) {
              final visibleCats = cats.where((cat) => items.any((i) => i.categoryId == cat.id && i.canOrder)).toList();
              if (visibleCats.isEmpty) return const AppEmpty(emoji: '🍽️', title: 'لا توجد أصناف متاحة حالياً');
              return ListView(children: visibleCats.map((cat) {
                final catItems = items.where((i) => i.categoryId == cat.id && i.canOrder).toList();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(cat.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark))),
                  ...catItems.map((item) => _ItemTile(item: item, category: cat, restaurant: restaurant)),
                ]);
              }).toList());
            });
          }),
        ),
      ]),
      bottomNavigationBar: cart.itemCount > 0 ? SafeArea(child: Padding(padding: const EdgeInsets.all(12),
        child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
            child: Text('عرض السلة (${cart.itemCount})')))) : null,
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
      ]);
}

class _ItemTile extends StatelessWidget {
  final MenuItem item; final MenuCategory category; final Restaurant restaurant;
  const _ItemTile({required this.item, required this.category, required this.restaurant});
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.quantityOf(item.id);
    return Container(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        MenuItemVisual(categoryName: category.name, itemName: item.name, imageUrl: item.imageUrl, size: 52),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
          if (item.description.trim().isNotEmpty)
            Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textGray, fontSize: 12)),
          Text(formatCurrency(item.price), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
        ])),
        if (qty == 0)
          ElevatedButton(
            onPressed: () => context.read<CartProvider>().add(item, restaurant.id, restaurant.name, restaurant.emoji, restaurant.driverShareFee, restaurant.appShareFee),
            child: const Text('أضف'),
          )
        else
          Row(children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary),
              onPressed: () => context.read<CartProvider>().remove(item.id),
            ),
            Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
              onPressed: () => context.read<CartProvider>().add(item, restaurant.id, restaurant.name, restaurant.emoji, restaurant.driverShareFee, restaurant.appShareFee),
            ),
          ]),
      ]));
  }
}
