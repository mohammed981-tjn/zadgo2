import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../providers/cart_provider.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/food_visuals.dart';
import '../../widgets/common_widgets.dart';
import 'cart_screen.dart';

/// هل عُرض تلقين «الدفع مرة واحدة» في هذه الجلسة؟ على مستوى الملف لا
/// الشاشة: فتح مطعم ثانٍ لا يعيد الدرس المحفوظ.
bool _addHintShown = false;

class RestaurantDetailScreen extends StatefulWidget {
  final Restaurant restaurant;
  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  State<RestaurantDetailScreen> createState() =>
      _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  Restaurant get restaurant => widget.restaurant;

  /// نصّ بحث المنيو (ح1) — فلترة محلية صرفة على الأصناف المحمَّلة أصلاً:
  /// لا استعلام جديد ولا قاعدة، فالمنيو كله بين يدينا لحظتها.
  final _menuSearchCtrl = TextEditingController();
  String _menuQuery = '';

  @override
  void dispose() {
    _menuSearchCtrl.dispose();
    super.dispose();
  }

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
                      style: const TextStyle(color: AppColors.textGray, fontSize: 13.5)),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: TextField(
            controller: _menuSearchCtrl,
            onChanged: (v) => setState(() => _menuQuery = v),
            decoration: InputDecoration(
              hintText: 'ابحث في المنيو…',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              suffixIcon: _menuQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        _menuSearchCtrl.clear();
                        _menuQuery = '';
                      }),
                    ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<MenuCategory>>(
            stream: service.streamCategories(restaurant.id),
            builder: (context, catSnap) {
              if (catSnap.hasError) {
                // ودجت الخطأ الموحّد بدل النص الأحمر الإنجليزي الخام: يعرض
                // رسالة عربية ورمز خطأ مختصر، ويحصر التفاصيل التقنية بوضع
                // التطوير — العميل لا يرى نص Firestore الخام.
                return AppError(
                  error: catSnap.error,
                  message: 'تعذّر تحميل قائمة المطعم',
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
                    return AppError(
                      error: itemSnap.error,
                      message: 'تعذّر تحميل أصناف المطعم',
                    );
                  }
                  if (!itemSnap.hasData) {
                    // هيكل تحميل (و5) من بنية بطاقة الصنف الحقيقية لا
                    // دوّامة: العين تحجز أماكن المحتوى قبل وصوله فلا
                    // «تقفز» الشاشة، وSkeletonizer يرمّد أي ودجت يُغلَّف
                    // به — فلا هيكل موازٍ يتقادم مع كل تعديل تصميم.
                    return Skeletonizer(
                      enabled: true,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: 6,
                        itemBuilder: (_, __) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const CircleAvatar(radius: 26),
                            title: Text('اسم صنف للتحميل'),
                            subtitle: Text('وصف مؤقت يشغل سطراً كاملاً هنا'),
                            trailing: Text('00.0 ر.س'),
                          ),
                        ),
                      ),
                    );
                  }
                  final items = itemSnap.data!;

                  var orderableItems =
                      items.where((i) => i.canOrder).toList();
                  // بحث المنيو (ح1): يصفّي بالاسم والوصف معاً — من يكتب
                  // «دجاج» يريد كل ما فيه دجاج ولو لم يبدأ الاسم به.
                  final q = _menuQuery.trim();
                  if (q.isNotEmpty) {
                    orderableItems = orderableItems
                        .where((i) =>
                            i.name.contains(q) ||
                            i.description.contains(q))
                        .toList();
                  }
                  final catIds = cats.map((c) => c.id).toSet();

                  final unmatchedItems = orderableItems
                      .where((i) => !catIds.contains(i.categoryId))
                      .toList();
                  final visibleCats = cats
                      .where((cat) =>
                          orderableItems.any((i) => i.categoryId == cat.id))
                      .toList();

                  if (visibleCats.isEmpty && unmatchedItems.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                            q.isEmpty
                                ? 'لا توجد أصناف متاحة حالياً'
                                : 'لا نتائج لـ«$q» في هذا المنيو',
                            style: const TextStyle(fontSize: 17)),
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
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dark,
                      foregroundColor: Colors.white),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CartScreen())),
                  // الإجمالي في الشريط (نمط كيتا): يعرف كم جمّع قبل فتح
                  // السلة — طمأنة تدفع للإضافة لا للتوقف.
                  child: Text(
                      'السلة (${cart.itemCount}) — ${formatCurrency(cart.itemsTotal)}'),
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
                fontSize: 13.5, color: color, fontWeight: FontWeight.w600)),
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
                        fontSize: 14.5,
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
                            fontSize: 14.5),
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
                                fontSize: 11.5,
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
    // صنف بخيارات: الإضافة تمر دائماً بنافذة الاختيار (الحجم إلزامي مثلاً)،
    // وكل ضغطة + تفتح النافذة لتشكيلة جديدة — نمط جاهز/كيتا نفسه.
    Future<void> addToCart() async {
      // سلة من مطعم آخر كانت تُفرَّغ **صامتةً** هنا، فتختفي اختيارات العميل
      // الأولى بلا تفسير ويظن أن عليه الدفع لكل صنف على حدة (ملاحظة
      // المالك بالصور). الآن استئذان صريح قبل الإفراغ.
      final cart = context.read<CartProvider>();
      if (!cart.isEmpty && cart.restaurantId != restaurant.id) {
        final ok = await showConfirmDialog(
          context,
          title: 'سلة من مطعم آخر',
          content: 'سلتك تحوي أصنافاً من ${cart.restaurantName ?? 'مطعم آخر'} '
              '— الطلب الواحد من مطعم واحد.\nإفراغها والبدء من '
              '${restaurant.name}؟',
          confirmLabel: 'إفراغ والبدء هنا',
        );
        if (ok != true || !context.mounted) return;
      }
      if (item.hasOptions) {
        _showOptionsSheet(context, item, restaurant);
      } else {
        context.read<CartProvider>().add(
              item,
              restaurant.id,
              restaurant.name,
              restaurant.emoji,
              restaurant.driverShareFee,
              restaurant.appShareFee,
            );
        // تلقين التدفق **مرة واحدة في الجلسة** (ملاحظة المالك بالصور
        // 2026-08-14: الرسالة مع كل إضافة صارت هي المزعجة — عشرة أصناف
        // تعني عشر رسائل تغطي المنيو). أول إضافة تكفي درساً، وشريط
        // «السلة» الدائم بالأسفل يقول الباقي.
        if (context.mounted && !_addHintShown) {
          _addHintShown = true;
          showSuccess(context,
              'أُضيف ✓ أكمل اختيارك — الدفع مرة واحدة من «السلة» بالأسفل');
        }
      }
    }

    // ملاحظة المالك 2026-08-14 (بالصور): الصفحة غرقت ذهبياً — السعر
    // ذهبي وخلفية الصورة ذهبية وزر الإضافة ذهبي، ففقد الفعلُ تميزه.
    // القاعدة: **الفعل أخضر داكن والمعلومة ذهبية** — أضف والعدّاد بلون
    // الهوية الداكن (تباين الأبيض عليه ٩:١+)، والسعر يبقى ذهبياً
    // فيتمايزان من نظرة. (تحل محل معايرة 2026-08-12 الذهبية.)
    const actionBg = AppColors.dark;
    const onAction = Colors.white;

    if (qty == 0) {
      return SizedBox(
        height: 32,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            backgroundColor: actionBg,
            foregroundColor: onAction,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: addToCart,
          child: Text(item.hasOptions ? 'أضف +' : 'أضف',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        ),
      );
    }
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: actionBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          iconSize: 18,
          icon: const Icon(Icons.remove, color: onAction),
          onPressed: () => context.read<CartProvider>().remove(item.id),
        ),
        SizedBox(
          width: 20,
          child: Text('$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                  color: onAction)),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          iconSize: 18,
          icon: const Icon(Icons.add, color: onAction),
          onPressed: addToCart,
        ),
      ]),
    );
  }
}

/// نافذة اختيار خيارات الصنف قبل إضافته — مجموعات الاختيار الواحد الإلزامي
/// (حجم...) كأزرار انتقاء، والإضافات الاختيارية كخانات تحديد، مع سعر حيّ
/// يتحدث مع كل تغيير.
void _showOptionsSheet(
    BuildContext context, MenuItem item, Restaurant restaurant) {
  // اختيار مبدئي: أول خيار في كل مجموعة إلزامية — نفس ما تفعله كيتا/جاهز.
  final singleChoice = <int, int>{
    for (var g = 0; g < item.optionGroups.length; g++)
      if (!item.optionGroups[g].multiSelect && item.optionGroups[g].options.isNotEmpty)
        g: 0
  };
  final multiChoice = <int, Set<int>>{
    for (var g = 0; g < item.optionGroups.length; g++)
      if (item.optionGroups[g].multiSelect) g: <int>{}
  };

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheetState) {
        final selections = <ItemOption>[];
        for (var g = 0; g < item.optionGroups.length; g++) {
          final group = item.optionGroups[g];
          if (group.multiSelect) {
            for (final i in (multiChoice[g] ?? const <int>{}).toList()..sort()) {
              selections.add(group.options[i]);
            }
          } else if (singleChoice.containsKey(g)) {
            selections.add(group.options[singleChoice[g]!]);
          }
        }
        final unitPrice = item.price +
            selections.fold(0.0, (s, o) => s + o.priceDelta);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  Text(formatCurrency(unitPrice),
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ]),
                const SizedBox(height: 6),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var g = 0; g < item.optionGroups.length; g++) ...[
                          const SizedBox(height: 10),
                          Row(children: [
                            Text(item.optionGroups[g].name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5)),
                            const SizedBox(width: 6),
                            Text(
                                item.optionGroups[g].multiSelect
                                    ? 'اختياري'
                                    : 'إلزامي',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: item.optionGroups[g].multiSelect
                                        ? AppColors.textGray
                                        : AppColors.warning)),
                          ]),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (var i = 0;
                                  i < item.optionGroups[g].options.length;
                                  i++)
                                _optionChip(
                                  item.optionGroups[g].options[i],
                                  item.optionGroups[g].multiSelect
                                      ? (multiChoice[g] ?? const <int>{})
                                          .contains(i)
                                      : singleChoice[g] == i,
                                  () => setSheetState(() {
                                    if (item.optionGroups[g].multiSelect) {
                                      final set = multiChoice[g]!;
                                      set.contains(i)
                                          ? set.remove(i)
                                          : set.add(i);
                                    } else {
                                      singleChoice[g] = i;
                                    }
                                  }),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<CartProvider>().add(
                            item,
                            restaurant.id,
                            restaurant.name,
                            restaurant.emoji,
                            restaurant.driverShareFee,
                            restaurant.appShareFee,
                            selections,
                          );
                      Navigator.pop(sheetCtx);
                    },
                    child: Text('أضف للسلة — ${formatCurrency(unitPrice)}'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Widget _optionChip(ItemOption option, bool selected, VoidCallback onTap) =>
    FilterChip(
      label: Text(option.priceDelta == 0
          ? option.name
          : '${option.name} (${option.priceDelta > 0 ? '+' : ''}${option.priceDelta.toStringAsFixed(option.priceDelta.truncateToDouble() == option.priceDelta ? 0 : 2)})'),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withOpacity(0.15),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 12.5,
        color: selected ? AppColors.primary : AppColors.textDark,
        fontWeight: selected ? FontWeight.bold : FontWeight.w600,
      ),
    );