// lib/screens/admin/admin_banners_screen.dart
//
// إدارة البنرات الترويجية التي تظهر أعلى شاشة مطاعم العميل: إضافة برابط
// صورة (المكان الطبيعي: zadgo.co/images)، تفعيل/إيقاف لحظي، ترتيب، وربط
// اختياري بمطعم تُفتح صفحته عند ضغط البنر.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/app_lang.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class AdminBannersScreen extends StatelessWidget {
  const AdminBannersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditSheet(context),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(tr('بنر جديد', 'New banner')),
      ),
      body: Column(children: [
        // مفتاح البنر الافتراضي (دفعة «الإعلانات الذكية»): حين لا حملة فعّالة
        // يظهر بنرٌ تعريفيّ مدمج — وقد يريد المدير شاشةً بلا إعلان، فيطفئه هنا.
        StreamBuilder<bool>(
          stream: service.streamShowDefaultBanner(),
          builder: (ctx, s) {
            final show = s.data ?? true;
            return Card(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: SwitchListTile(
                value: show,
                activeColor: AppColors.success,
                onChanged: (v) => service.setShowDefaultBanner(v),
                title: Text(tr('البنر الافتراضي', 'Default banner'),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(
                    show
                        ? tr('يظهر بنرٌ تعريفيّ حين لا يوجد إعلان فعّال',
                            'An intro banner shows when no active ad exists')
                        : tr('الشاشة بلا إعلان حين لا يوجد إعلان فعّال',
                            'The screen shows no ad when no active ad exists'),
                    style: const TextStyle(fontSize: 11.5)),
                secondary: const Icon(Icons.auto_awesome_outlined),
              ),
            );
          },
        ),
        Expanded(
          child: AppStreamBuilder<List<PromoBanner>>(
            stream: service.streamAllBanners,
            builder: (context, banners) {
              if (banners.isEmpty) {
                return AppEmpty(
                  emoji: '🖼️',
                  title: tr('لا بنرات بعد', 'No banners yet'),
                  subtitle: tr(
                      'أضف بنر عروض أو مطعم جديد — يظهر فوراً أعلى شاشة العميل',
                      'Add an offers or new-restaurant banner — it shows immediately at the top of the customer screen'),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                itemCount: banners.length,
                itemBuilder: (_, i) => _BannerCard(banner: banners[i]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final PromoBanner banner;
  const _BannerCard({required this.banner});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final b = banner;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 120,
          child: Stack(fit: StackFit.expand, children: [
            Image.network(
              b.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.error.withOpacity(0.08),
                alignment: Alignment.center,
                child: Text(tr('تعذّر تحميل الصورة — تحقق من الرابط',
                        'Image failed to load — check the URL'),
                    style: const TextStyle(fontSize: 12.5, color: AppColors.error)),
              ),
            ),
            // طبقةٌ سوداء ونصّ الحالة: «مُوقَف» يدوياً، أو «منتهٍ» زمنياً —
            // كلاهما يعني «لا يظهر للعميل الآن» فيُبرَز للمدير بوضوح.
            if (!b.isActive || b.isExpired)
              Container(
                color: Colors.black45,
                alignment: Alignment.center,
                child: Text(b.isExpired ? tr('منتهٍ', 'Expired') : tr('مُوقَف', 'Paused'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17)),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            Expanded(
              child: Text(
                b.title.trim().isEmpty ? tr('(بلا عنوان)', '(no title)') : b.title,
                style:
                    const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(tr('ترتيب ${b.sortOrder}', 'Order ${b.sortOrder}'),
                style:
                    const TextStyle(fontSize: 11.5, color: AppColors.textGray)),
          ]),
        ),
        // سطر الجدولة: يظهر فقط إن حُدّدت نافذة — يصارح المدير بحالة البنر
        // الزمنية (منتهٍ/ينتهي/يبدأ) فلا يتساءل «لماذا لا يظهر؟».
        if (b.startsAt != null || b.endsAt != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Row(children: [
              Icon(
                  b.isExpired
                      ? Icons.event_busy
                      : Icons.schedule,
                  size: 13,
                  color: b.isExpired ? AppColors.error : AppColors.textGray),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  b.isExpired
                      ? tr('انتهى في ${_fmtDate(b.endsAt!)}',
                          'Ended on ${_fmtDate(b.endsAt!)}')
                      : [
                          if (b.startsAt != null &&
                              b.startsAt!.isAfter(DateTime.now()))
                            tr('يبدأ ${_fmtDate(b.startsAt!)}',
                                'Starts ${_fmtDate(b.startsAt!)}'),
                          if (b.endsAt != null)
                            tr('ينتهي ${_fmtDate(b.endsAt!)}',
                                'Ends ${_fmtDate(b.endsAt!)}'),
                        ].join(' • '),
                  style: TextStyle(
                      fontSize: 11.5,
                      color: b.isExpired ? AppColors.error : AppColors.textGray,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        Row(children: [
          const SizedBox(width: 4),
          Switch(
            value: b.isActive,
            activeColor: AppColors.success,
            onChanged: (v) => service.setBannerActive(b.id, v),
          ),
          Text(b.isActive ? tr('فعّال', 'Active') : tr('موقَف', 'Paused'),
              style: const TextStyle(fontSize: 12.5)),
          const Spacer(),
          IconButton(
            tooltip: tr('تعديل', 'Edit'),
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _showEditSheet(context, existing: b),
          ),
          IconButton(
            tooltip: tr('حذف', 'Delete'),
            icon: const Icon(Icons.delete_outline,
                size: 20, color: AppColors.error),
            onPressed: () async {
              final ok = await showConfirmDialog(context,
                  title: tr('حذف البنر', 'Delete banner'),
                  content: tr('يُحذف نهائياً ويختفي من شاشة العملاء فوراً.',
                      'It is permanently deleted and disappears from the customer screen immediately.'),
                  confirmLabel: tr('حذف', 'Delete'),
                  confirmColor: AppColors.error);
              if (ok == true) await service.deleteBanner(b.id);
            },
          ),
        ]),
      ]),
    );
  }
}

Future<void> _showEditSheet(BuildContext context, {PromoBanner? existing}) {
  final service = context.read<FirebaseService>();
  final urlCtrl = TextEditingController(text: existing?.imageUrl ?? '');
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final orderCtrl =
      TextEditingController(text: (existing?.sortOrder ?? 0).toString());
  String? restaurantId = existing?.restaurantId;
  // نافذة العرض المجدولة (دفعة «الإعلانات الذكية»): كلاهما اختياري.
  DateTime? startsAt = existing?.startsAt;
  DateTime? endsAt = existing?.endsAt;
  final form = GlobalKey<FormState>();

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(existing == null
                        ? tr('بنر جديد', 'New banner')
                        : tr('تعديل البنر', 'Edit banner'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: urlCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: tr('رابط الصورة', 'Image URL'),
                    hintText: 'https://zadgo.co/images/offer-1.jpg',
                    helperText: tr(
                        'الأنسب: صورة عرضية بنسبة ~2.4:1 على zadgo.co/images',
                        'Best: a wide image at ~2.4:1 on zadgo.co/images'),
                    helperMaxLines: 2,
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return tr('الرابط مطلوب', 'URL is required');
                    final uri = Uri.tryParse(t);
                    if (uri == null || !uri.isScheme('https')) {
                      return tr('رابط https صالح مطلوب', 'A valid https URL is required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: tr('عنوان (اختياري)', 'Title (optional)'),
                    hintText: tr('خصم الافتتاح ٢٠٪', 'Opening discount 20%'),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: orderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('الترتيب (الأصغر أولاً)', 'Order (lowest first)'),
                  ),
                ),
                const SizedBox(height: 10),
                AppStreamBuilder<List<Restaurant>>(
                  stream: service.streamRestaurants,
                  builder: (c, restaurants) =>
                      DropdownButtonFormField<String?>(
                    value: restaurantId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr('يفتح مطعماً عند الضغط (اختياري)',
                          'Opens a restaurant on tap (optional)'),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                          value: null, child: Text(tr('بلا ربط', 'No link'))),
                      ...restaurants.map((r) => DropdownMenuItem<String?>(
                            value: r.id,
                            child: Text(r.displayName,
                                overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) => setSheetState(() => restaurantId = v),
                  ),
                ),
                const SizedBox(height: 16),
                // نافذة العرض المجدولة (دفعة «الإعلانات الذكية»): «ينتهي في»
                // يُخفي البنر وحده — علاجاً لشكوى «الإعلان يستمر بلا نهاية».
                Text(tr('نافذة العرض (اختيارية)', 'Display window (optional)'),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(
                    tr('اتركها فارغة ليظهر دائماً، أو حدّد «ينتهي في» فيختفي وحده.',
                        'Leave empty to always show, or set "ends on" so it hides itself.'),
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textGray)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_outlined, size: 16),
                      label: Text(
                          startsAt == null
                              ? tr('يبدأ: الآن', 'Starts: now')
                              : tr('يبدأ: ${_fmtDate(startsAt!)}',
                                  'Starts: ${_fmtDate(startsAt!)}'),
                          style: const TextStyle(fontSize: 12.5),
                          overflow: TextOverflow.ellipsis),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: startsAt ?? DateTime.now(),
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 1)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) setSheetState(() => startsAt = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_busy_outlined, size: 16),
                      label: Text(
                          endsAt == null
                              ? tr('ينتهي: بلا حدّ', 'Ends: never')
                              : tr('ينتهي: ${_fmtDate(endsAt!)}',
                                  'Ends: ${_fmtDate(endsAt!)}'),
                          style: const TextStyle(fontSize: 12.5),
                          overflow: TextOverflow.ellipsis),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: endsAt ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        // آخر اللحظة من اليوم المختار كي يشمل يومه كاملاً.
                        if (d != null) {
                          setSheetState(() => endsAt = DateTime(
                              d.year, d.month, d.day, 23, 59, 59));
                        }
                      },
                    ),
                  ),
                ]),
                if (startsAt != null || endsAt != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      icon: const Icon(Icons.clear, size: 15),
                      label: Text(tr('مسح التواريخ', 'Clear dates'),
                          style: const TextStyle(fontSize: 12)),
                      onPressed: () =>
                          setSheetState(() { startsAt = null; endsAt = null; }),
                    ),
                  ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    if (!form.currentState!.validate()) return;
                    // منعُ نافذةٍ مقلوبة (ينتهي قبل يبدأ) — خطأٌ صامت يُخفي
                    // البنر أبداً؛ نصارح المدير بدل حفظٍ لا يظهر.
                    if (startsAt != null &&
                        endsAt != null &&
                        !endsAt!.isAfter(startsAt!)) {
                      showError(ctx, tr('تاريخ الانتهاء يجب أن يكون بعد البداية',
                          'End date must be after the start date'));
                      return;
                    }
                    final banner = PromoBanner(
                      id: existing?.id ?? const Uuid().v4(),
                      imageUrl: urlCtrl.text.trim(),
                      title: titleCtrl.text.trim(),
                      restaurantId: restaurantId,
                      isActive: existing?.isActive ?? true,
                      sortOrder: int.tryParse(orderCtrl.text.trim()) ?? 0,
                      createdAt: existing?.createdAt ?? DateTime.now(),
                      startsAt: startsAt,
                      endsAt: endsAt,
                    );
                    await service.saveBanner(banner);
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  },
                  child: Text(existing == null ? tr('إضافة', 'Add') : tr('حفظ', 'Save')),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// تاريخٌ مختصر (سنة/شهر/يوم) لأزرار الجدولة وبطاقة البنر.
String _fmtDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
