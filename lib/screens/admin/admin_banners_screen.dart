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
        label: const Text('بنر جديد'),
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
                title: const Text('البنر الافتراضي',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(
                    show
                        ? 'يظهر بنرٌ تعريفيّ حين لا يوجد إعلان فعّال'
                        : 'الشاشة بلا إعلان حين لا يوجد إعلان فعّال',
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
                return const AppEmpty(
                  emoji: '🖼️',
                  title: 'لا بنرات بعد',
                  subtitle:
                      'أضف بنر عروض أو مطعم جديد — يظهر فوراً أعلى شاشة العميل',
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
                child: const Text('تعذّر تحميل الصورة — تحقق من الرابط',
                    style: TextStyle(fontSize: 12.5, color: AppColors.error)),
              ),
            ),
            // طبقةٌ سوداء ونصّ الحالة: «مُوقَف» يدوياً، أو «منتهٍ» زمنياً —
            // كلاهما يعني «لا يظهر للعميل الآن» فيُبرَز للمدير بوضوح.
            if (!b.isActive || b.isExpired)
              Container(
                color: Colors.black45,
                alignment: Alignment.center,
                child: Text(b.isExpired ? 'منتهٍ' : 'مُوقَف',
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
                b.title.trim().isEmpty ? '(بلا عنوان)' : b.title,
                style:
                    const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('ترتيب ${b.sortOrder}',
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
                      ? 'انتهى في ${_fmtDate(b.endsAt!)}'
                      : [
                          if (b.startsAt != null &&
                              b.startsAt!.isAfter(DateTime.now()))
                            'يبدأ ${_fmtDate(b.startsAt!)}',
                          if (b.endsAt != null) 'ينتهي ${_fmtDate(b.endsAt!)}',
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
          Text(b.isActive ? 'فعّال' : 'موقَف',
              style: const TextStyle(fontSize: 12.5)),
          const Spacer(),
          IconButton(
            tooltip: 'تعديل',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _showEditSheet(context, existing: b),
          ),
          IconButton(
            tooltip: 'حذف',
            icon: const Icon(Icons.delete_outline,
                size: 20, color: AppColors.error),
            onPressed: () async {
              final ok = await showConfirmDialog(context,
                  title: 'حذف البنر',
                  content: 'يُحذف نهائياً ويختفي من شاشة العملاء فوراً.',
                  confirmLabel: 'حذف',
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
                Text(existing == null ? 'بنر جديد' : 'تعديل البنر',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: urlCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'رابط الصورة',
                    hintText: 'https://zadgo.co/images/offer-1.jpg',
                    helperText:
                        'الأنسب: صورة عرضية بنسبة ~2.4:1 على zadgo.co/images',
                    helperMaxLines: 2,
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'الرابط مطلوب';
                    final uri = Uri.tryParse(t);
                    if (uri == null || !uri.isScheme('https')) {
                      return 'رابط https صالح مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'عنوان (اختياري)',
                    hintText: 'خصم الافتتاح ٢٠٪',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: orderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الترتيب (الأصغر أولاً)',
                  ),
                ),
                const SizedBox(height: 10),
                AppStreamBuilder<List<Restaurant>>(
                  stream: service.streamRestaurants,
                  builder: (c, restaurants) =>
                      DropdownButtonFormField<String?>(
                    value: restaurantId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'يفتح مطعماً عند الضغط (اختياري)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('بلا ربط')),
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
                const Text('نافذة العرض (اختيارية)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
                const SizedBox(height: 2),
                const Text(
                    'اتركها فارغة ليظهر دائماً، أو حدّد «ينتهي في» فيختفي وحده.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textGray)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_outlined, size: 16),
                      label: Text(
                          startsAt == null
                              ? 'يبدأ: الآن'
                              : 'يبدأ: ${_fmtDate(startsAt!)}',
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
                              ? 'ينتهي: بلا حدّ'
                              : 'ينتهي: ${_fmtDate(endsAt!)}',
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
                      label: const Text('مسح التواريخ',
                          style: TextStyle(fontSize: 12)),
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
                      showError(ctx, 'تاريخ الانتهاء يجب أن يكون بعد البداية');
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
                  child: Text(existing == null ? 'إضافة' : 'حفظ'),
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
