// بحث الصنف عبر المطاعم (دفعة ٥ — النمو والاحتفاظ): العميل يعرف ما يشتهيه
// («شاورما»، «كبسة») قبل أن يعرف من يقدّمه — المعيار العالمي (دور داش/
// هنقرستيشن) يبحث في الأصناف لا المطاعم وحدها. سابقاً كان عليه تخمين المطعم
// ثم تصفّح منيوه، فيضيع اشتهاءٌ كان طلباً.
//
// الفهرس يُجلب مرّة عند فتح الشاشة (collectionGroup) ويُخزَّن، والفلترة
// بالاسم/الوصف تقع في العميل مطبَّعةً عربياً (لا يبحث Firestore عن نصٍّ
// جزئي). النقر يفتح صفحة المطعم مباشرةً — أقصر طريق من الاشتهاء إلى السلة.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import 'restaurant_detail_screen.dart';

class ItemSearchScreen extends StatefulWidget {
  const ItemSearchScreen({super.key});

  @override
  State<ItemSearchScreen> createState() => _ItemSearchScreenState();
}

class _ItemSearchScreenState extends State<ItemSearchScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  List<MenuItem>? _catalog; // null = يُحمَّل
  Map<String, Restaurant> _restaurantsById = const {};
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final service = context.read<FirebaseService>();
    try {
      // الفهرس وقائمة المطاعم معاً: الصنف يحمل معرّف مطعمه لا اسمه، فنبني
      // خريطة معرّف←مطعم لعرض الاسم وحالة الفتح والانتقال بنقرة.
      final results = await Future.wait([
        service.fetchItemCatalog(),
        service.streamRestaurants().first,
      ]);
      final items = results[0] as List<MenuItem>;
      final restaurants = results[1] as List<Restaurant>;
      if (!mounted) return;
      setState(() {
        _restaurantsById = {for (final r in restaurants) r.id: r};
        // أصنافُ مطاعم غير معروضة (محذوفة/موقوفة) لا تُبحث: تُبقى فقط ما ينتمي
        // لمطعمٍ حيّ في القائمة.
        _catalog =
            items.where((i) => _restaurantsById.containsKey(i.restaurantId)).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  List<MenuItem> get _results {
    final q = _query.trim();
    if (q.length < 2 || _catalog == null) return const [];
    return _catalog!
        .where((i) =>
            normalizedContains(i.name, q) ||
            normalizedContains(i.description, q))
        .toList()
      // الأكثر مبيعاً أولاً: النتائج الأشيع أقرب لما يريده الباحث.
      ..sort((a, b) => b.totalSold.compareTo(a.totalSold));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ابحث عن صنف'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'شاورما، برجر، كبسة…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppError(error: _error, message: 'تعذّر تحميل الأصناف');
    }
    if (_catalog == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final q = _query.trim();
    if (q.length < 2) {
      return const AppEmpty(
          emoji: '🍽️',
          title: 'اكتب اسم صنف',
          subtitle: 'ابحث عمّا تشتهيه في كل مطاعم المدينة دفعةً واحدة');
    }
    final results = _results;
    if (results.isEmpty) {
      return const AppEmpty(emoji: '🔍', title: 'لا أصناف مطابقة');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = results[i];
        final restaurant = _restaurantsById[item.restaurantId];
        return _ItemResultTile(
          item: item,
          restaurant: restaurant,
          onTap: restaurant == null
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            RestaurantDetailScreen(restaurant: restaurant)),
                  ),
        );
      },
    );
  }
}

class _ItemResultTile extends StatelessWidget {
  final MenuItem item;
  final Restaurant? restaurant;
  final VoidCallback? onTap;
  const _ItemResultTile(
      {required this.item, required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(item.emoji.isEmpty ? '🍽️' : item.emoji,
              style: const TextStyle(fontSize: 24)),
        ),
        title: Text(item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
        subtitle: Row(children: [
          const Icon(Icons.storefront_rounded,
              size: 13, color: AppColors.textGray),
          const SizedBox(width: 4),
          Expanded(
            child: Text(restaurant?.name ?? 'مطعم',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12.5, color: AppColors.textGray)),
          ),
        ]),
        // السعر كحليّ لا ذهبيّ (اتساقاً مع تباين المال في دفعة ٤).
        trailing: Text(formatCurrency(item.price),
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.dark)),
      ),
    );
  }
}
