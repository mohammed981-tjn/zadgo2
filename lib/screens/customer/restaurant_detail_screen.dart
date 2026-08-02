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
              final availableItems = items.where((i) => i.canOrder).toList();
              
              // الدالة المساعدة: تطابق مزدوجة (معرّف ثم اسم)
              bool itemMatchesCategory(MenuItem item, MenuCategory cat) {
                // إن كان categoryId موجود وغير فارغ، طابق به
                if (item.categoryId.trim().isNotEmpty && item.categoryId == cat.id) {
                  return true;
                }
                // إن كان categoryId فارغاً، اسقط للمطابقة بالاسم النصي
                if (item.categoryId.trim().isEmpty && item.name.toLowerCase().contains(cat.name.toLowerCase())) {
                  return true;
                }
                return false;
              }
              
              // عدد الأصناف التي سقطت للمطابقة بالاسم (للتسجيل)
              int fallbackCount = 0;
              
              // الفئات المرئية فقط (التي تحتوي على أصناف)
              final List<MapEntry<MenuCategory, List<MenuItem>>> categorizedItems = [];
              
              for (final cat in cats) {
                final catItems = availableItems.where((item) => itemMatchesCategory(item, cat)).toList();
                if (catItems.isNotEmpty) {
                  categorizedItems.add(MapEntry(cat, catItems));
                  // عدّ الأصناف التي استخدمت المطابقة بالاسم
                  for (final item in catItems) {
                    if (item.categoryId.trim().isEmpty) {
                      fallbackCount++;
                    }
                  }
                }
              }
              
              // الأصناف التي لا تنتمي لأي فئة
              final unmatchedItems = availableItems.where((item) {
                return !cats.any((cat) => itemMatchesCategory(item, cat));
              }).toList();
              
              // تسجيل عدد الأصناف التي سقطت للمطابقة بالاسم
              if (fallbackCount > 0) {
                debugPrint('⚠️ RestaurantDetailScreen: $fallbackCount أصناف سقطت للمطابقة بالاسم بسبب categoryId فارغ');
              }
              
              // إذا لم توجد فئات أو أصناف بلا تصنيف
              if (categorizedItems.isEmpty && unmatchedItems.isEmpty) {
                return const AppEmpty(emoji: '🍽️', title: 'لا توجد أصناف متاحة حالياً');
              }
              
              return ListView(children: [
                // عرض الفئات والأصناف الخاصة بها
                ...categorizedItems.map((entry) {
                  final cat = entry.key;
                  final catItems = entry.value;
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(cat.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark))),
                    ...catItems.map((item) => _ItemTile(item: item, category: cat, restaurant: restaurant)),
                  ]);
                }).toList(),
                
                // عرض قسم "أصناف أخرى" إن وجدت أصناف بلا تصنيف
                if (unmatchedItems.isNotEmpty) ...[
                  Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('أصناف أخرى', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark))),
                  ...unmatchedItems.map((item) {
                    // إنشاء فئة وهمية للأصناف غير المصنفة
                    final dummyCategory = MenuCategory(
                      id: 'other',
                      restaurantId: restaurant.id,
                      name: 'أصناف أخرى',
                    );
                    return _ItemTile(item: item, category: dummyCategory, restaurant: restaurant);
                  }).toList(),
                ],
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
  
  /// تحقق من اكتمال بيانات الصنف
  bool _hasCompleteData() {
    return item.name.trim().isNotEmpty && item.price > 0;
  }
  
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.quantityOf(item.id);
    
    // إذا كانت البيانات ناقصة، اعرض رسالة تحذير
    if (!_hasCompleteData()) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 120),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.warning.withOpacity(0.3), width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outlined, color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'بيانات الصنف غير مكتملة',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // البطاقة العادية
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 120),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
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
        ])),
      ),
    );
  }
}
