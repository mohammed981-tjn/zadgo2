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

/// شاشة تفاصيل المطعم: تعرض أصنافه مقسّمة على فئاته، وتتيح الإضافة للسلة
/// مباشرة دون تسجيل دخول.
///
/// ============================================================================
/// ملاحظة تشخيصية مؤقتة (تُحذف بعد حل المشكلة):
/// _ItemTile في هذه النسخة تعرض مربعاً أصفر تشخيصياً بدل البطاقة الكاملة،
/// لتحديد هل الودجت نفسها تُبنى إطلاقاً أم لا:
///   • ظهور مربع أصفر فيه اسم الصنف → المشكلة في تصميم البطاقة الأصلية
///     (شيء داخلها يأخذ مساحة ولا يُرسم)
///   • عدم ظهور أي شيء (بياض كما كان) → المشكلة أعمق من _ItemTile، في
///     القائمة (ListView) أو الشرط الذي يستدعيها
/// ============================================================================
class RestaurantDetailScreen extends StatelessWidget {
  final Restaurant restaurant;
  const RestaurantDetailScreen({super.key, required this.restaurant});

  static bool _itemBelongsToCategory(MenuItem item, MenuCategory cat) {
    final id = item.categoryId.trim();
    if (id.isNotEmpty) return id == cat.id;
    return item.categoryId.trim().toLowerCase() == cat.name.trim().toLowerCase();
  }

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              RestaurantAvatar(name: restaurant.name, imageUrl: restaurant.imageUrl, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(spacing: 12, runSpacing: 4, children: [
                  _InfoChip(icon: Icons.star_rounded, label: restaurant.rating.toStringAsFixed(1), color: AppColors.warning),
                  _InfoChip(icon: Icons.timer_outlined, label: '${restaurant.estimatedTimeMin} دقيقة', color: AppColors.textGray),
                  _InfoChip(
                    icon: Icons.delivery_dining_outlined,
                    label: restaurant.deliveryFee > 0 ? formatCurrency(restaurant.deliveryFee) : 'توصيل مجاني',
                    color: AppColors.textGray,
                  ),
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
                if (catSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final cats = catSnap.data ?? [];
                // تشخيص مؤقت: اطبع عدد الفئات الواصلة فعلياً.
                debugPrint('🔍 [تشخيص] عدد الفئات الواصلة: ${cats.length}');
                for (final c in cats) {
                  debugPrint('🔍 [تشخيص] فئة: id=${c.id} name=${c.name} sortOrder=${c.sortOrder}');
                }

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
                    if (itemSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final items = itemSnap.data ?? [];
                    // تشخيص مؤقت: اطبع عدد كل الأصناف الواصلة فعلياً من Firestore،
                    // قبل أي فلترة بـ canOrder أو مطابقة فئة.
                    debugPrint('🔍 [تشخيص] عدد كل الأصناف الواصلة (قبل الفلترة): ${items.length}');
                    for (final i in items) {
                      debugPrint(
                          '🔍 [تشخيص] صنف: id=${i.id} name="${i.name}" categoryId="${i.categoryId}" '
                          'price=${i.price} isAvailable=${i.isAvailable} canOrder=${i.canOrder}');
                    }

                    final orderableItems = items.where((i) => i.canOrder).toList();
                    debugPrint('🔍 [تشخيص] عدد الأصناف القابلة للطلب (canOrder=true): ${orderableItems.length}');

                    final unmatchedItems = orderableItems
                        .where((i) => !cats.any((cat) => _itemBelongsToCategory(i, cat)))
                        .toList();

                    final visibleCats = cats
                        .where((cat) => orderableItems.any((i) => _itemBelongsToCategory(i, cat)))
                        .toList();

                    debugPrint('🔍 [تشخيص] فئات ظاهرة: ${visibleCats.length} | أصناف غير مطابقة: ${unmatchedItems.length}');

                    if (visibleCats.isEmpty && unmatchedItems.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('لا توجد أصناف متاحة حالياً', style: TextStyle(fontSize: 16)),
                        ),
                      );
                    }

                    const otherCategory = MenuCategory(id: '__other__', restaurantId: '', name: 'أصناف أخرى');

                    return ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        ...visibleCats.map((cat) {
                          final catItems = orderableItems.where((i) => _itemBelongsToCategory(i, cat)).toList();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: Text(
                                  cat.name,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                ),
                              ),
                              ...catItems.map((item) => _ItemTile(item: item, category: cat, restaurant: restaurant)),
                            ],
                          );
                        }),
                        if (unmatchedItems.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: Text(
                                  otherCategory.name,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                ),
                              ),
                              ...unmatchedItems.map((item) => _ItemTile(item: item, category: otherCategory, restaurant: restaurant)),
                            ],
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: cart.itemCount > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
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
          Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
        ],
      );
}

/// ============================================================================
/// نسخة تشخيصية مؤقتة من _ItemTile: مربع أصفر بسيط بدل البطاقة الكاملة.
/// هذا يعزل السؤال الحاسم: هل هذه الودجت تُبنى إطلاقاً أم لا؟
///
///   • ظهور مربع أصفر فيه اسم الصنف والسعر → الودجت تُبنى بنجاح، والمشكلة
///     كانت في تصميم البطاقة الأصلية (على الأرجح MenuItemVisual أو تخطيط
///     الـ Row/Column الداخلي). في هذه الحالة أعد لي هذا واستمر بالبناء
///     الأصلي مع تتبع أدق لعنصر الصورة.
///   • عدم ظهور أي شيء (بياض كما كان تماماً) → المشكلة ليست في _ItemTile
///     إطلاقاً، بل أعمق: في القائمة نفسها فوقها، أو في شرط لم نكتشفه بعد.
///     في هذه الحالة، انسخ لي كل أسطر "🔍 [تشخيص]" التي تظهر في الطرفية
///     (terminal) عند فتح هذا المطعم بالذات.
/// ============================================================================
class _ItemTile extends StatelessWidget {
  final MenuItem item;
  final MenuCategory category;
  final Restaurant restaurant;
  const _ItemTile({required this.item, required this.category, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 [تشخيص] _ItemTile.build() استُدعيت لـ: "${item.name}" (id: ${item.id})');

    // === نسخة تشخيصية مؤقتة — استبدال كامل بمربع أصفر بسيط ===
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      height: 70,
      width: double.infinity,
      color: Colors.yellow,
      alignment: Alignment.center,
      child: Text(
        'TEST: ${item.name.isEmpty ? "(بلا اسم)" : item.name} — ${item.price} ر.س',
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
    // === نهاية النسخة التشخيصية ===

    /* الكود الأصلي الكامل — مُعلَّق مؤقتاً، يُعاد بعد التشخيص:

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
          categoryName: category.name,
          itemName: item.name,
          imageUrl: item.imageUrl,
          size: 52,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
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
                        style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ],
          ),
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
            Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 16)),
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
    */
  }
}
