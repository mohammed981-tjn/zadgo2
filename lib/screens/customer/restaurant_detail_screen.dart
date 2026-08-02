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
              final orderableItems = items.where((i) => i.canOrder).toList();
              final catIds = cats.map((c) => c.id).toSet();
              // أصناف قابلة للطلب لكن categoryId فيها فارغ أو يشير لفئة
              // محذوفة/غير موجودة: سابقاً كانت تختفي بصمت بدل الظهور تحت
              // فئتها؛ الآن تُجمع في قسم "أصناف أخرى" في نهاية القائمة بدلاً
              // من فقدانها كلياً من عرض العميل.
              final unmatchedItems =
                  orderableItems.where((i) => !catIds.contains(i.categoryId)).toList();
              final visibleCats = cats.where((cat) => orderableItems.any((i) => i.categoryId == cat.id)).toList();
              if (visibleCats.isEmpty && unmatchedItems.isEmpty) {
                return const AppEmpty(emoji: '🍽️', title: 'لا توجد أصناف متاحة حالياً');
              }
              const otherCategory = MenuCategory(id: '__other__', restaurantId: '', name: 'أصناف أخرى');
              return ListView(children: [
                ...visibleCats.map((cat) {
                  final catItems = orderableItems.where((i) => i.categoryId == cat.id).toList();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(cat.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark))),
                    ...catItems.map((item) => _ItemTile(item: item, category: cat, restaurant: restaurant)),
                  ]);
                }),
                if (unmatchedItems.isNotEmpty)
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(otherCategory.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark))),
                    ...unmatchedItems.map((item) => _ItemTile(item: item, category: otherCategory, restaurant: restaurant)),
                  ]),
              ]);
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
    final isIncomplete = item.name.trim().isEmpty || item.price <= 0;
    // حد أقصى صريح لارتفاع البطاقة: خط دفاع أخير يمنع أي بطاقة فارغة ضخمة
    // حتى لو فشلت كل عناصر السقوط الآمن الأخرى (صورة/نص) لأي سبب غير متوقع.
    // يُرفع الحد قليلاً عند وجود سطر تحذير بيانات ناقصة إضافي.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: isIncomplete ? 140 : 120),
      child: Container(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        MenuItemVisual(categoryName: category.name, itemName: item.name, imageUrl: item.imageUrl, size: 52),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name.trim().isEmpty ? '(بلا اسم)' : item.name,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
          if (item.description.trim().isNotEmpty)
            Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textGray, fontSize: 12)),
          Text(formatCurrency(item.price), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          // بدل بطاقة بيضاء فارغة/مضلِّلة لصنف بيانات ناقصة (اسم فارغ أو سعر
          // غير صالح)، تحذير صريح للعميل عوضاً عن السماح بطلب صنف مشكوك فيه.
          if (isIncomplete)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.info_outline, size: 13, color: AppColors.warning),
                SizedBox(width: 4),
                Text('بيانات الصنف غير مكتملة',
                    style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
              ]),
            ),
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
      ])));
  }
}
