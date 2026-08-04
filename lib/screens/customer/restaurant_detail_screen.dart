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

/// شاشة تفاصيل المطعم — نسخة مؤقتة بلا تصنيف فئات، لعزل مشكلة عدم ظهور
/// الأصناف عن أي احتمال خلل في مطابقة categoryId. تعرض كل صنف قابل
/// للطلب في قائمة واحدة مسطحة بصرف النظر عن فئته. تُستبدل بالنسخة
/// المصنَّفة بالفئات بعد التأكد من وصول بيانات الأصناف فعلياً.
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
          child: AppStreamBuilder<List<MenuItem>>(
            stream: () => service.streamMenuItems(restaurant.id),
            builder: (ctx, items) {
              // ===== شريط تشخيص مؤقت — يُحذف بعد التأكد من وصول البيانات =====
              // يعرض أرقاماً خام لا تعتمد على أي مطابقة فئة، لمعرفة هل
              // الأصناف تصل أصلاً من Firestore أم لا.
              final diagnosticBar = Container(
                width: double.infinity,
                color: Colors.amber.withOpacity(0.15),
                padding: const EdgeInsets.all(8),
                child: Text(
                  'تشخيص: وصل ${items.length} صنف كلي، '
                  '${items.where((i) => i.canOrder).length} منها قابل للطلب.'
                  '${items.isNotEmpty ? ' أول صنف: "${items.first.name}" '
                      '(categoryId="${items.first.categoryId}", السعر=${items.first.price}, '
                      'isAvailable=${items.first.isAvailable})' : ''}',
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                ),
              );
              // ===== نهاية شريط التشخيص =====

              final orderableItems = items.where((i) => i.canOrder).toList();

              if (orderableItems.isEmpty) {
                return Column(children: [
                  diagnosticBar,
                  const Expanded(
                    child: AppEmpty(emoji: '🍽️', title: 'لا توجد أصناف متاحة حالياً'),
                  ),
                ]);
              }

              return Column(children: [
                diagnosticBar,
                Expanded(
                  child: ListView(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('كل الأصناف',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark)),
                    ),
                    ...orderableItems.map((item) => _ItemTile(
                          item: item,
                          categoryName: item.categoryId.trim().isEmpty
                              ? 'بلا فئة'
                              : item.categoryId,
                          restaurant: restaurant,
                        )),
                  ]),
                ),
              ]);
            },
          ),
        ),
      ]),
      bottomNavigationBar: cart.itemCount > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const CartScreen())),
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
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
      ]);
}

/// بطاقة صنف واحد — النسخة المسطحة تستقبل اسم الفئة كنص مباشر بدل كائن
/// MenuCategory، لأنها لا تعتمد على أي مطابقة فئة فعلية.
class _ItemTile extends StatelessWidget {
  final MenuItem item;
  final String categoryName;
  final Restaurant restaurant;
  const _ItemTile({required this.item, required this.categoryName, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.quantityOf(item.id);
    final isIncomplete = item.name.trim().isEmpty || item.price <= 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        MenuItemVisual(
          categoryName: categoryName,
          itemName: item.name,
          imageUrl: item.imageUrl,
          size: 52,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(
              item.name.trim().isEmpty ? '(بلا اسم)' : item.name,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            if (item.description.trim().isNotEmpty)
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textGray, fontSize: 12),
              ),
            const SizedBox(height: 2),
            Text(
              formatCurrency(item.price),
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
            if (isIncomplete)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.info_outline, size: 13, color: AppColors.warning),
                  SizedBox(width: 4),
                  Text('بيانات الصنف غير مكتملة',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        if (qty == 0)
          ElevatedButton(
            onPressed: () => context.read<CartProvider>().add(
                  item,
                  restaurant.id,
                  restaurant.name,
                  restaurant.emoji,
                  restaurant.driverShareFee,
                  restaurant.appShareFee,
                ),
            child: const Text('أضف'),
          )
        else
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary),
              onPressed: () => context.read<CartProvider>().remove(item.id),
            ),
            Text('$qty',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
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
      ]),
    );
  }
}