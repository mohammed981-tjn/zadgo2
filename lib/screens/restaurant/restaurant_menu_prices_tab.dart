// lib/screens/restaurant/restaurant_menu_prices_tab.dart
//
// شاشة "أسعار القائمة" لمدير المطعم — تعرض أصناف القائمة مجمّعة حسب الفئة
// وتسمح بتعديل السعر فقط. إضافة/حذف الأصناف والفئات تبقى حصراً بيد إدارة
// المنصة (لوحة المدير العام)، فمدير المطعم لا يملك أي صلاحية لإنشاء صنف
// جديد أو حذف صنف قائم؛ صلاحيته الوحيدة هنا هي مراجعة وتحديث سعر البيع.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class RestaurantMenuPricesTab extends StatelessWidget {
  final String restaurantId;
  const RestaurantMenuPricesTab({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<List<MenuCategory>>(
      stream: () => service.streamCategories(restaurantId),
      builder: (ctx, cats) {
        return AppStreamBuilder<List<MenuItem>>(
          stream: () => service.streamMenuItems(restaurantId),
          builder: (ctx2, items) {
            if (items.isEmpty) {
              return const AppEmpty(
                emoji: '🍽️',
                title: 'لا يوجد أصناف في قائمة مطعمك بعد',
                subtitle: 'إضافة الأصناف من اختصاص إدارة المنصة.',
              );
            }
            final catIds = cats.map((c) => c.id).toSet();
            final unclassified = items.where((i) => !catIds.contains(i.categoryId)).toList();
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ...cats.map((cat) {
                  final catItems = items.where((i) => i.categoryId == cat.id).toList();
                  if (catItems.isEmpty) return const SizedBox.shrink();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ExpansionTile(
                      title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${catItems.length} صنف'),
                      children: catItems
                          .map((item) => _PriceTile(item: item, restaurantId: restaurantId))
                          .toList(),
                    ),
                  );
                }),
                if (unclassified.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: const Text('أصناف أخرى', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${unclassified.length} صنف'),
                      children: unclassified
                          .map((item) => _PriceTile(item: item, restaurantId: restaurantId))
                          .toList(),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PriceTile extends StatelessWidget {
  final MenuItem item;
  final String restaurantId;
  const _PriceTile({required this.item, required this.restaurantId});

  Future<void> _editPrice(BuildContext context) async {
    final ctrl = TextEditingController(text: item.price.toString());
    final form = GlobalKey<FormState>();
    final newPrice = await showDialog<double>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('سعر "${item.name}"'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'السعر الجديد'),
            validator: validatePrice,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogCtx, double.parse(ctrl.text));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (newPrice == null || !context.mounted) return;
    final service = context.read<FirebaseService>();
    await service.updateMenuItem(MenuItem(
      id: item.id,
      restaurantId: item.restaurantId,
      categoryId: item.categoryId,
      name: item.name,
      description: item.description,
      price: newPrice,
      emoji: item.emoji,
      isAvailable: item.isAvailable,
      stockQuantity: item.stockQuantity,
      trackStock: item.trackStock,
      totalSold: item.totalSold,
      imageUrl: item.imageUrl,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(item.emoji, style: const TextStyle(fontSize: 26)),
      title: Text(item.name.trim().isEmpty ? '(بلا اسم)' : item.name),
      subtitle: Text(formatCurrency(item.price),
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined),
        tooltip: 'تعديل السعر',
        onPressed: () => _editPrice(context),
      ),
    );
  }
}
