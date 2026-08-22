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
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/ai_assist.dart';
import '../../providers/firebase_service.dart';
import '../../utils/app_lang.dart';
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
  bool _replaceExisting = false;
  bool _aiReading = false;

  /// «المنيو من صورة» (2026-08-16): تصوير المنيو الورقي ← Gemini رؤية ←
  /// JSON يُسكب في خانة اللصق ويمرّ من نفس خط التحليل والمعاينة
  /// والتأكيد — إعادة استخدام كاملة لخط الاستيراد القائم، والمدير يرى
  /// ويعتمد قبل كتابة أي مستند (الذكاء يقترح والإنسان يقرر).
  Future<void> _fromImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(tr('التقط صورة المنيو الآن', 'Take a photo of the menu now')),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(tr('اختر من المعرض', 'Choose from gallery')),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _aiReading = true;
      _error = null;
      _categories = null;
      _items = null;
    });
    try {
      final bytes = await picked.readAsBytes();
      final json = await AiAssist.menuJsonFromImage(bytes);
      if (!mounted) return;
      _jsonCtrl.text = json;
      _parse();
      if (_error == null && mounted) {
        showSuccess(context,
            tr('قُرئ المنيو من الصورة — راجع المعاينة قبل الاستيراد',
                'Menu read from the photo — review the preview before importing'));
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _aiReading = false);
    }
  }

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
      setState(() => _error = tr('الصق نص المنيو (JSON) أولاً',
          'Paste the menu text (JSON) first'));
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      // يُقبل الشكلان: كائن يحوي categories، أو مصفوفة تصنيفات مباشرة.
      final rawCats = decoded is Map<String, dynamic>
          ? decoded['categories']
          : decoded;
      if (rawCats is! List || rawCats.isEmpty) {
        setState(() => _error = tr('لم يُعثر على تصنيفات في الملف',
            'No categories found in the file'));
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
          final desc = (i['description'] as String?)?.trim() ?? '';

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
            kcal: kcal,
          ));
        }
      }

      if (items.isEmpty) {
        setState(() => _error = tr('لم يُعثر على أي صنف صالح داخل التصنيفات',
            'No valid item found inside the categories'));
        return;
      }

      setState(() {
        _categories = cats;
        _items = items;
      });
    } catch (_) {
      setState(() => _error = tr('صيغة JSON غير صالحة — تأكّد من نسخ الملف كاملاً',
          'Invalid JSON — make sure you copied the whole file'));
    }
  }

  Future<void> _import() async {
    final cats = _categories, items = _items;
    if (cats == null || items == null) return;

    final ok = await showConfirmDialog(
      context,
      title: _replaceExisting
          ? tr('تأكيد الاستبدال', 'Confirm replacement')
          : tr('تأكيد الاستيراد', 'Confirm import'),
      content: _replaceExisting
          ? tr(
              'سيُحذف منيو «${widget.restaurantName}» الحالي كاملاً ثم يُستورد '
              '${cats.length} تصنيفاً و${items.length} صنفاً مكانه. '
              'الحذف نهائي لا رجعة فيه.',
              'The entire current menu of "${widget.restaurantName}" will be deleted, then '
              '${cats.length} categories and ${items.length} items imported in its place. '
              'Deletion is permanent.')
          : tr(
              'سيُضاف ${cats.length} تصنيفاً و${items.length} صنفاً إلى '
              '«${widget.restaurantName}». الأصناف الحالية لن تُحذف.',
              '${cats.length} categories and ${items.length} items will be added to '
              '"${widget.restaurantName}". Existing items will not be deleted.'),
      confirmLabel: _replaceExisting ? tr('استبدال', 'Replace') : tr('استيراد', 'Import'),
      confirmColor: _replaceExisting ? AppColors.error : null,
    );
    if (ok != true || !mounted) return;

    setState(() => _importing = true);
    try {
      final result = await context.read<FirebaseService>().importMenu(
            restaurantId: widget.restaurantId,
            categories: cats,
            items: items,
            replaceExisting: _replaceExisting,
          );
      if (mounted) {
        // ت٣٨: رسالة صادقة بما كُتب وما تُخطّي — «استيرادٌ» أعاد كتابة
        // لا شيء لأن كل الأصناف مكرّرة يجب أن يُقال صراحةً.
        showSuccess(
            context,
            result.skipped == 0
                ? tr('تم استيراد ${result.imported} صنفاً بنجاح',
                    'Imported ${result.imported} items successfully')
                : tr(
                    'استُورد ${result.imported} صنفاً، وتُخُطّي ${result.skipped} مكرّراً موجوداً مسبقاً',
                    'Imported ${result.imported} items; skipped ${result.skipped} duplicates already in the menu'));
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        showError(context, tr('تعذّر الاستيراد، حاول مرة أخرى',
            'Import failed, try again'));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = _categories, items = _items;
    final parsed = cats != null && items != null;

    return Scaffold(
      appBar: AppBar(title: Text(tr('استيراد منيو', 'Import menu'))),
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
          // مسار الصورة أولاً — هو الأسرع لمطعم جديد: تصوير المنيو الورقي
          // يغني عن إدخال عشرات الأصناف يدوياً أو تجهيز JSON خارجياً.
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: _aiReading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.photo_camera_outlined),
              label: Text(_aiReading
                  ? tr('جارٍ قراءة الصورة…', 'Reading the photo…')
                  : tr('المنيو من صورة ✨', 'Menu from a photo ✨')),
              onPressed: (_importing || _aiReading) ? null : _fromImage,
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(tr('— أو —', '— or —'),
                style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
          ),
          const SizedBox(height: 6),
          Text(tr('الصق محتوى ملف المنيو (JSON)', 'Paste the menu file content (JSON)'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
          const SizedBox(height: 6),
          Text(
            tr(
                'كل تصنيف يحتوي name وقائمة items، وكل صنف فيه name و price '
                '(واختيارياً kcal و description و imageUrl).',
                'Each category has a name and an items list, and each item has a name and price '
                '(optionally kcal, description and imageUrl).'),
            style: const TextStyle(fontSize: 12.5, color: AppColors.textGray),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _jsonCtrl,
            maxLines: 8,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              hintText: tr(
                  '{ "categories": [ { "name": "الفطير", "items": [...] } ] }',
                  '{ "categories": [ { "name": "Pastries", "items": [...] } ] }'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 4),
          // وضع الاستبدال — لإعادة استيراد منيو استُورد سابقاً (من لوحة
          // الويب مثلاً) دون تكرار الأصناف: يُحذف القائم ثم يُكتب الجديد.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _replaceExisting,
            onChanged: _importing
                ? null
                : (v) => setState(() => _replaceExisting = v),
            title: Text(tr('استبدال المنيو الحالي', 'Replace the current menu'),
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            subtitle: Text(
              _replaceExisting
                  ? tr('سيُحذف المنيو القائم كاملاً ثم يُستورد الجديد مكانه',
                      'The existing menu will be fully deleted, then the new one imported in its place')
                  : tr('مطفأ: الاستيراد يضيف فوق الأصناف الحالية دون حذف',
                      'Off: the import adds on top of existing items without deleting'),
              style: TextStyle(
                  fontSize: 11.5,
                  color: _replaceExisting
                      ? AppColors.error
                      : AppColors.textGray),
            ),
            activeColor: AppColors.error,
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(tr('تحليل ومعاينة', 'Parse and preview')),
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
            SectionHeader(title: tr('المعاينة قبل الاستيراد', 'Preview before import')),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  PriceRow(label: tr('التصنيفات', 'Categories'), value: '${cats.length}'),
                  PriceRow(label: tr('الأصناف', 'Items'), value: '${items.length}', bold: true),
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
                trailing: Text(tr('$count صنف', '$count items'),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textGray)),
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
                    ? tr('جاري الاستيراد...', 'Importing...')
                    : _replaceExisting
                        ? tr('استبدال المنيو بـ${items.length} صنفاً',
                            'Replace the menu with ${items.length} items')
                        : tr('استيراد ${items.length} صنفاً',
                            'Import ${items.length} items')),
                onPressed: _importing ? null : _import,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
