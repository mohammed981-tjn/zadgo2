// lib/screens/admin/admin_menu_import_screen.dart
//
// استيراد منيو مطعم كاملاً من نص JSON — بديل عن إدخال عشرات الأصناف يدوياً
// عبر نموذج لكل صنف (منيو من 74 صنفاً يعني 74 نموذجاً وساعات من العمل).
//
// التدفّق: لصق النص ← تحليل ومعاينة (كم تصنيفاً وكم صنفاً وأول الأصناف) ←
// تأكيد ← كتابة دفعة واحدة. المعاينة قبل الكتابة مقصودة: الاستيراد يكتب
// عشرات المستندات، فرؤية ما سيُكتب قبل تنفيذه تمنع أخطاء يصعب تداركها.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class AdminMenuImportScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const AdminMenuImportScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<AdminMenuImportScreen> createState() => _AdminMenuImportScreenState();
}

class _AdminMenuImportScreenState extends State<AdminMenuImportScreen> {
  final _jsonCtrl = TextEditingController();
  bool _importing = false;

  /// نتيجة التحليل: تصنيفات وأصناف جاهزة للكتابة، أو رسالة خطأ مفهومة.
  List<MenuCategory>? _categories;
  List<MenuItem>? _items;
  String? _error;

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

  void _parse() {
    setState(() {
      _error = null;
      _categories = null;
      _items = null;
    });

    final raw = _jsonCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'الصق نص المنيو (JSON) أولاً');
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      // يُقبل الشكلان: كائن يحوي categories، أو مصفوفة تصنيفات مباشرة.
      final rawCats = decoded is Map<String, dynamic>
          ? decoded['categories']
          : decoded;
      if (rawCats is! List || rawCats.isEmpty) {
        setState(() => _error = 'لم يُعثر على تصنيفات في الملف');
        return;
      }

      const uuid = Uuid();
      final cats = <MenuCategory>[];
      final items = <MenuItem>[];
      var sort = 0;

      for (final c in rawCats) {
        if (c is! Map) continue;
        final catName = (c['name'] as String?)?.trim() ?? '';
        if (catName.isEmpty) continue;

        final catId = uuid.v4();
        cats.add(MenuCategory(
          id: catId,
          restaurantId: widget.restaurantId,
          name: catName,
          sortOrder: sort++,
        ));

        final rawItems = c['items'];
        if (rawItems is! List) continue;
        for (final i in rawItems) {
          if (i is! Map) continue;
          final name = (i['name'] as String?)?.trim() ?? '';
          if (name.isEmpty) continue;
          final price = (i['price'] as num?)?.toDouble() ?? 0;
          final kcal = (i['kcal'] as num?)?.toInt();
          // السعرات تُحفظ ضمن الوصف لأن النموذج لا يملك حقلاً لها، وعرضها
          // للعميل قيمة مضافة حقيقية في منيو مأكولات.
          final desc = (i['description'] as String?)?.trim().isNotEmpty == true
              ? i['description'] as String
              : (kcal != null ? '$kcal سعرة حرارية' : '');

          items.add(MenuItem(
            id: uuid.v4(),
            restaurantId: widget.restaurantId,
            categoryId: catId,
            name: name,
            description: desc,
            price: price,
            emoji: (i['emoji'] as String?)?.trim().isNotEmpty == true
                ? i['emoji'] as String
                : '🍽️',
            imageUrl: (i['imageUrl'] as String?)?.trim().isNotEmpty == true
                ? i['imageUrl'] as String
                : null,
          ));
        }
      }

      if (items.isEmpty) {
        setState(() => _error = 'لم يُعثر على أي صنف صالح داخل التصنيفات');
        return;
      }

      setState(() {
        _categories = cats;
        _items = items;
      });
    } catch (_) {
      setState(() => _error = 'صيغة JSON غير صالحة — تأكّد من نسخ الملف كاملاً');
    }
  }

  Future<void> _import() async {
    final cats = _categories, items = _items;
    if (cats == null || items == null) return;

    final ok = await showConfirmDialog(
      context,
      title: 'تأكيد الاستيراد',
      content: 'سيُضاف ${cats.length} تصنيفاً و${items.length} صنفاً إلى '
          '«${widget.restaurantName}». الأصناف الحالية لن تُحذف.',
      confirmLabel: 'استيراد',
    );
    if (ok != true || !mounted) return;

    setState(() => _importing = true);
    try {
      await context.read<FirebaseService>().importMenu(
            restaurantId: widget.restaurantId,
            categories: cats,
            items: items,
          );
      if (mounted) {
        showSuccess(context, 'تم استيراد ${items.length} صنفاً بنجاح');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showError(context, 'تعذّر الاستيراد، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = _categories, items = _items;
    final parsed = cats != null && items != null;

    return Scaffold(
      appBar: AppBar(title: const Text('استيراد منيو')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.restaurant_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.restaurantName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('الصق محتوى ملف المنيو (JSON)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          const Text(
            'كل تصنيف يحتوي name وقائمة items، وكل صنف فيه name و price '
            '(واختيارياً kcal و description و imageUrl).',
            style: TextStyle(fontSize: 12, color: AppColors.textGray),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _jsonCtrl,
            maxLines: 8,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              hintText: '{ "categories": [ { "name": "الفطير", "items": [...] } ] }',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('تحليل ومعاينة'),
              onPressed: _importing ? null : _parse,
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_error!,
                        style: const TextStyle(color: AppColors.error))),
              ]),
            ),
          ],

          if (parsed) ...[
            const SizedBox(height: 16),
            const SectionHeader(title: 'المعاينة قبل الاستيراد'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  PriceRow(label: 'التصنيفات', value: '${cats.length}'),
                  PriceRow(label: 'الأصناف', value: '${items.length}', bold: true),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            ...cats.map((c) {
              final count = items.where((i) => i.categoryId == c.id).length;
              return ListTile(
                dense: true,
                leading: const Icon(Icons.folder_outlined,
                    size: 20, color: AppColors.primary),
                title: Text(c.name),
                trailing: Text('$count صنف',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textGray)),
              );
            }),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: _importing
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_importing
                    ? 'جاري الاستيراد...'
                    : 'استيراد ${items.length} صنفاً'),
                onPressed: _importing ? null : _import,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
