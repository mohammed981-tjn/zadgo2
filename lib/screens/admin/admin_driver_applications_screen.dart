// lib/screens/admin/admin_driver_applications_screen.dart
//
// مراجعة طلبات انضمام الكباتن — من التطبيق لا من المتصفح.
//
// المتقدّم يملأ بياناته ويرفع مستنداته في صفحة zadgo.co/join (الرفع يحتاج
// استضافة تقبل الملفات، وFirebase Storage موقوف على ترقية Blaze)، لكن
// **المراجعة والقرار هنا**: المدير يفتح المستند بحجم الشاشة ويكبّره
// بأصابعه ليقرأ رقم الإقامة وتاريخ الانتهاء، ثم يقبل فيصدر كود التسجيل
// أو يرفض بسبب مكتوب.
//
// الصور تُعرض بروابطها لا بتنزيلها — نفس آلية صور المطاعم والبنرات، فلا
// تتطلّب الترقية شيئاً هنا.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class AdminDriverApplicationsScreen extends StatelessWidget {
  const AdminDriverApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<List<DriverApplication>>(
      stream: service.streamDriverApplications,
      builder: (ctx, apps) {
        if (apps.isEmpty) {
          return const AppEmpty(
            emoji: '📋',
            title: 'لا طلبات انضمام بعد',
            subtitle: 'تصل هنا من صفحة التسجيل على الموقع '
                '(zadgo.co/join) بعد رفع المستندات',
          );
        }
        final pending = apps
            .where((a) => a.status == DriverApplicationStatus.pending)
            .length;
        return ListView(padding: const EdgeInsets.all(12), children: [
          if (pending > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.pending_actions_rounded,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Text('$pending طلب بانتظار مراجعتك',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5)),
              ]),
            ),
          ...apps.map((a) => _AppCard(app: a)),
        ]);
      },
    );
  }
}

class _AppCard extends StatelessWidget {
  final DriverApplication app;
  const _AppCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final docsCount = app.documents.length + app.vehiclePhotos.length;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _AppDetailScreen(app: app)),
        ),
        title: Text(app.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          [
            app.phone,
            '$docsCount مستند',
            if (app.referredByCode.isNotEmpty) 'دعوة ${app.referredByCode}',
            if (app.missingRequired.isNotEmpty)
              'ناقص ${app.missingRequired.length}',
          ].join(' • '),
          style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
        ),
        trailing: StatusChip(label: app.status.label, color: app.status.color),
      ),
    );
  }
}

class _AppDetailScreen extends StatelessWidget {
  final DriverApplication app;
  const _AppDetailScreen({required this.app});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final missing = app.missingRequired;

    return Scaffold(
      appBar: AppBar(title: Text(app.name)),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Row(children: [
          StatusChip(label: app.status.label, color: app.status.color),
          const Spacer(),
          Text('${app.createdAt.day}/${app.createdAt.month}/${app.createdAt.year}',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textGray)),
        ]),
        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('البيانات',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _field('الجوال', app.phone, copyable: true),
              _field('البريد', app.email, copyable: true),
              _field('الهوية/الإقامة', app.nationalId, copyable: true),
              _field('المركبة',
                  [app.vehicleType, app.vehiclePlate]
                      .where((e) => e.isNotEmpty)
                      .join(' — ')),
              if (app.referredByCode.isNotEmpty)
                _field('كود الداعي', app.referredByCode),
            ]),
          ),
        ),

        if (missing.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'مستندات إلزامية ناقصة: '
                    '${missing.map((k) => DriverApplication.docLabels[k] ?? k).join('، ')}',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.error)),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 14),
        const SectionHeader(title: 'المستندات — اضغط للتكبير'),
        ...DriverApplication.docLabels.entries.map((e) {
          final url = app.documents[e.key] ?? '';
          if (url.isEmpty) return const SizedBox.shrink();
          return _DocTile(label: e.value, url: url);
        }),
        if (app.vehiclePhotos.isNotEmpty) ...[
          const SizedBox(height: 8),
          const SectionHeader(title: 'صور المركبة'),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: app.vehiclePhotos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _openViewer(
                    context, 'صورة المركبة ${i + 1}', app.vehiclePhotos[i]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: app.vehiclePhotos[i],
                    width: 150,
                    height: 110,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 150,
                      color: AppColors.surface,
                      child: const Icon(Icons.broken_image_outlined,
                          color: AppColors.textGray),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],

        if (app.status == DriverApplicationStatus.approved &&
            app.issuedCode.isNotEmpty) ...[
          const SizedBox(height: 14),
          Card(
            color: AppColors.success.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                const Text('كود التسجيل الصادر',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success)),
                const SizedBox(height: 6),
                SelectableText(app.issuedCode,
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6)),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: app.issuedCode));
                      if (context.mounted) showSuccess(context, 'نُسخ الكود');
                    },
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('نسخ'),
                  ),
                  TextButton.icon(
                    onPressed: () => Share.share(_codeMessage(app)),
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('إرسال للكابتن'),
                  ),
                ]),
              ]),
            ),
          ),
        ],

        if (app.status == DriverApplicationStatus.rejected &&
            app.reviewNote.isNotEmpty) ...[
          const SizedBox(height: 14),
          Card(
            color: AppColors.errorLight,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('سبب الرفض: ${app.reviewNote}',
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],

        const SizedBox(height: 20),
        if (app.status == DriverApplicationStatus.pending) ...[
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.verified_outlined),
              label: const Text('قبول وإصدار كود التسجيل'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success),
              onPressed: () => _approve(context, service, missing),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.block_outlined, size: 18),
              label: const Text('رفض الطلب'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              onPressed: () => _reject(context, service),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }

  static String _codeMessage(DriverApplication a) =>
      'مرحباً ${a.name} 👋\nتمت الموافقة على انضمامك لكباتن ZadGo.\n'
      'كود التسجيل: ${a.issuedCode}\n'
      'حمّل تطبيق الكابتن وسجّل بهذا الكود.';

  Widget _field(String label, String value, {bool copyable = false}) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12.5, color: AppColors.textGray)),
        ),
        Expanded(
          child: copyable
              ? SelectableText(value, style: const TextStyle(fontSize: 13))
              : Text(value, style: const TextStyle(fontSize: 13)),
        ),
      ]),
    );
  }

  Future<void> _approve(BuildContext context, FirebaseService service,
      List<String> missing) async {
    // نقص المستندات الإلزامية تحذيرٌ لا منع: قد يصل المستند عبر واتساب،
    // والقرار للمدير — لكن لا يمرّ صامتاً.
    var days = 7;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setLocal) => AlertDialog(
          title: const Text('قبول الطلب'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (missing.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                    '⚠️ ناقص: '
                    '${missing.map((k) => DriverApplication.docLabels[k] ?? k).join('، ')}',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.error)),
              ),
            const Text('يُصدَر كود تسجيل للكابتن بصلاحية:',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: days,
              isDense: true,
              items: const [
                DropdownMenuItem(value: 1, child: Text('٢٤ ساعة')),
                DropdownMenuItem(value: 7, child: Text('٧ أيام')),
                DropdownMenuItem(value: 30, child: Text('٣٠ يوماً')),
                DropdownMenuItem(value: 0, child: Text('بلا انتهاء')),
              ],
              onChanged: (v) => setLocal(() => days = v ?? 7),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx2, false),
                child: const Text('إلغاء')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx2, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success),
                child: const Text('قبول')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final entry = await service.approveDriverApplication(
        application: app,
        validity: days == 0 ? null : Duration(days: days),
      );
      if (!context.mounted) return;
      showSuccess(context, 'صدر الكود ${entry.code}');
      // الرجوع للقائمة: البطاقة المحدَّثة تحمل الكود ليُرسل من تفاصيلها.
      Navigator.pop(context);
    } catch (_) {
      if (context.mounted) showError(context, 'تعذّر إصدار الكود');
    }
  }

  Future<void> _reject(BuildContext context, FirebaseService service) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'السبب',
            hintText: 'رخصة القيادة منتهية — يُعاد التقديم بعد تجديدها',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('رفض')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final note = ctrl.text.trim();
    if (note.isEmpty) {
      showError(context, 'اكتب سبب الرفض — يُرسَل للمتقدّم');
      return;
    }
    try {
      await service.rejectDriverApplication(
          applicationId: app.id, note: note);
      if (context.mounted) {
        showSuccess(context, 'رُفض الطلب');
        Navigator.pop(context);
      }
    } catch (_) {
      if (context.mounted) showError(context, 'تعذّر الرفض');
    }
  }
}

class _DocTile extends StatelessWidget {
  final String label;
  final String url;
  const _DocTile({required this.label, required this.url});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: () => _openViewer(context, label, url),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              memCacheWidth: 200,
              errorWidget: (_, __, ___) => Container(
                width: 52,
                height: 52,
                color: AppColors.surface,
                child: const Icon(Icons.description_outlined,
                    color: AppColors.textGray, size: 22),
              ),
            ),
          ),
          title: Text(label, style: const TextStyle(fontSize: 13.5)),
          trailing: const Icon(Icons.zoom_in_rounded, size: 20),
        ),
      );
}

void _openViewer(BuildContext context, String label, String url) =>
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _DocViewer(label: label, url: url)),
    );

/// عارض المستند بحجم الشاشة مع تكبير بالأصابع — مراجعة إقامة أو رخصة
/// تتطلّب قراءة رقمٍ وتاريخِ انتهاء، وصورةٌ مصغّرة لا تكفي لذلك.
class _DocViewer extends StatelessWidget {
  final String label;
  final String url;
  const _DocViewer({required this.label, required this.url});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(label),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'مشاركة الرابط',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => Share.share(url),
            ),
          ],
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (_, __) => const CircularProgressIndicator(),
              errorWidget: (_, __, ___) => Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.broken_image_outlined,
                      color: Colors.white54, size: 48),
                  const SizedBox(height: 12),
                  const Text('تعذّر تحميل المستند',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  SelectableText(url,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ]),
              ),
            ),
          ),
        ),
      );
}
