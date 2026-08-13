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
      body: AppStreamBuilder<List<PromoBanner>>(
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
            if (!b.isActive)
              Container(
                color: Colors.black45,
                alignment: Alignment.center,
                child: const Text('مُوقَف',
                    style: TextStyle(
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
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () async {
                    if (!form.currentState!.validate()) return;
                    final banner = PromoBanner(
                      id: existing?.id ?? const Uuid().v4(),
                      imageUrl: urlCtrl.text.trim(),
                      title: titleCtrl.text.trim(),
                      restaurantId: restaurantId,
                      isActive: existing?.isActive ?? true,
                      sortOrder: int.tryParse(orderCtrl.text.trim()) ?? 0,
                      createdAt: existing?.createdAt ?? DateTime.now(),
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
