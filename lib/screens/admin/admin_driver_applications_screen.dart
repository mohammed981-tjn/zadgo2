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
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/app_lang.dart';
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
          return AppEmpty(
            emoji: '📋',
            title: tr('لا طلبات انضمام بعد', 'No join applications yet'),
            subtitle: tr(
                'تصل هنا من صفحة التسجيل على الموقع '
                '(zadgo.co/join) بعد رفع المستندات',
                'They arrive here from the website sign-up page '
                '(zadgo.co/join) after documents are uploaded'),
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
                Text(tr('$pending طلب بانتظار مراجعتك',
                        '$pending applications awaiting your review'),
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
        subtitle: Text(
          [
            app.phone,
            tr('$docsCount مستند', '$docsCount documents'),
            if (app.source == 'app') tr('من التطبيق 📱', 'From the app 📱'),
            if (app.referredByCode.isNotEmpty)
              tr('دعوة ${app.referredByCode}', 'Referral ${app.referredByCode}'),
            if (app.operatorCode.isNotEmpty)
              tr('أسطول 🛵 ${app.operatorCode}', 'Fleet 🛵 ${app.operatorCode}'),
            if (app.missingRequired.isNotEmpty)
              tr('ناقص ${app.missingRequired.length}',
                  '${app.missingRequired.length} missing'),
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
                  const TextStyle(fontSize: 12.5, color: AppColors.textGray)),
        ]),
        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('البيانات', 'Details'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _field(tr('الجوال', 'Phone'), app.phone, copyable: true),
              _field(tr('البريد', 'Email'), app.email, copyable: true),
              _field(tr('الهوية/الإقامة', 'National/residency ID'),
                  app.nationalId, copyable: true),
              _field(tr('المركبة', 'Vehicle'),
                  [app.vehicleType, app.vehiclePlate]
                      .where((e) => e.isNotEmpty)
                      .join(' — ')),
              if (app.referredByCode.isNotEmpty)
                _field(tr('كود الداعي', 'Referrer code'), app.referredByCode),
              if (app.operatorCode.isNotEmpty) ...[
                _field(tr('كود دعوة الأسطول', 'Fleet invite code'),
                    app.operatorCode),
                // 🟡 (فحص دفعة ٨): المدير كان «يعتمد على العمياء» — يرى
                // الكود مجرّداً بلا اسم مشغّله ولا حالته. الحالة تُجلب
                // حيّةً: صالح/منتهٍ/مستهلَك واسم أسطوله — والاعتماد على
                // كودٍ منتهٍ سيُرفض برسالةٍ صريحة لا صمتاً.
                FutureBuilder<Map<String, dynamic>?>(
                  future: context
                      .read<FirebaseService>()
                      .fetchRegistrationCodeInfo(app.operatorCode),
                  builder: (ctx, snap) {
                    final info = snap.data;
                    if (info == null) return const SizedBox.shrink();
                    final expiresAt =
                        (info['expiresAt'] as Timestamp?)?.toDate();
                    final expired = expiresAt != null &&
                        DateTime.now().isAfter(expiresAt);
                    final used = (info['isUsed'] as bool?) == true;
                    final status = used
                        ? tr('مستهلَك — ${info['usedByName'] ?? ''}',
                            'Consumed — ${info['usedByName'] ?? ''}')
                        : expired
                            ? tr('⚠️ منتهي الصلاحية — اطلب كوداً جديداً',
                                '⚠️ Expired — request a new code')
                            : tr('صالح ✓', 'Valid ✓');
                    return _field(
                        tr('حالة الكود', 'Code status'), status);
                  },
                ),
              ],
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
                    tr(
                        'مستندات إلزامية ناقصة: '
                            '${missing.map((k) => DriverApplication.docLabels[k] ?? k).join('، ')}',
                        'Missing required documents: '
                            '${missing.map((k) => DriverApplication.docLabels[k] ?? k).join(', ')}'),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.error)),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 14),
        SectionHeader(title: tr('المستندات — اضغط للتكبير', 'Documents — tap to zoom')),
        ...DriverApplication.docLabels.entries.map((e) {
          final url = app.documents[e.key] ?? '';
          if (url.isEmpty) return const SizedBox.shrink();
          return _DocTile(label: e.value, url: url);
        }),
        if (app.vehiclePhotos.isNotEmpty) ...[
          const SizedBox(height: 8),
          SectionHeader(title: tr('صور المركبة', 'Vehicle photos')),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: app.vehiclePhotos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _openViewer(
                    context,
                    tr('صورة المركبة ${i + 1}', 'Vehicle photo ${i + 1}'),
                    app.vehiclePhotos[i]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _DocThumb(
                      docRef: app.vehiclePhotos[i], width: 150, height: 110),
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
                Text(tr('كود التسجيل الصادر', 'Issued registration code'),
                    style: const TextStyle(
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
                      if (context.mounted) {
                        showSuccess(context, tr('نُسخ الكود', 'Code copied'));
                      }
                    },
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: Text(tr('نسخ', 'Copy')),
                  ),
                  TextButton.icon(
                    onPressed: () => Share.share(_codeMessage(app)),
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: Text(tr('إرسال للكابتن', 'Send to captain')),
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
              child: Text(tr('سبب الرفض: ${app.reviewNote}',
                      'Rejection reason: ${app.reviewNote}'),
                  style: const TextStyle(fontSize: 13.5)),
            ),
          ),
        ],

        const SizedBox(height: 20),
        if (app.status == DriverApplicationStatus.pending) ...[
          // طلب من داخل التطبيق: حسابه حقيقي وشاشة انتظاره تبثّ — الاعتماد
          // يمنح الدور مباشرة فينفتح تطبيقه لحظتها، بلا كود ولا إعادة تسجيل.
          // طلب الويب: حسابه مجهول يُرمى، فيبقى مسار الكود القديم.
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.verified_outlined),
              label: Text(app.source == 'app'
                  ? tr('اعتماد مباشر — يفتح تطبيقه فوراً',
                      'Direct approval — opens their app instantly')
                  : tr('قبول وإصدار كود التسجيل',
                      'Approve and issue registration code')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success),
              onPressed: () => app.source == 'app'
                  ? _approveDirect(context, service, missing)
                  : _approve(context, service, missing),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.block_outlined, size: 18),
              label: Text(tr('رفض الطلب', 'Reject application')),
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
              ? SelectableText(value, style: const TextStyle(fontSize: 13.5))
              : Text(value, style: const TextStyle(fontSize: 13.5)),
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
          title: Text(tr('قبول الطلب', 'Approve application')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (missing.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                    tr(
                        '⚠️ ناقص: '
                            '${missing.map((k) => DriverApplication.docLabels[k] ?? k).join('، ')}',
                        '⚠️ Missing: '
                            '${missing.map((k) => DriverApplication.docLabels[k] ?? k).join(', ')}'),
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.error)),
              ),
            Text(tr('يُصدَر كود تسجيل للكابتن بصلاحية:',
                    'A registration code is issued to the captain, valid for:'),
                style: const TextStyle(fontSize: 13.5)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: days,
              isDense: true,
              items: [
                DropdownMenuItem(value: 1, child: Text(tr('٢٤ ساعة', '24 hours'))),
                DropdownMenuItem(value: 7, child: Text(tr('٧ أيام', '7 days'))),
                DropdownMenuItem(value: 30, child: Text(tr('٣٠ يوماً', '30 days'))),
                DropdownMenuItem(value: 0, child: Text(tr('بلا انتهاء', 'No expiry'))),
              ],
              onChanged: (v) => setLocal(() => days = v ?? 7),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx2, false),
                child: Text(tr('إلغاء', 'Cancel'))),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx2, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success),
                child: Text(tr('قبول', 'Approve'))),
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
      showSuccess(context, tr('صدر الكود ${entry.code}',
          'Code ${entry.code} issued'));
      // الرجوع للقائمة: البطاقة المحدَّثة تحمل الكود ليُرسل من تفاصيلها.
      Navigator.pop(context);
    } catch (_) {
      if (context.mounted) {
        showError(context, tr('تعذّر إصدار الكود', 'Could not issue the code'));
      }
    }
  }

  Future<void> _approveDirect(BuildContext context, FirebaseService service,
      List<String> missing) async {
    final ok = await showConfirmDialog(
      context,
      title: tr('اعتماد مباشر', 'Direct approval'),
      content: tr(
          '${missing.isNotEmpty ? '⚠️ ناقص: '
                  '${missing.map((k) => DriverApplication.docLabels[k] ?? k).join('، ')}\n\n' : ''}'
              'يُمنح ${app.name} دور الكابتن فوراً وينفتح تطبيقه من شاشة '
              'الانتظار — بلا كود.'
              '${app.operatorCode.isNotEmpty ? '\nكود أسطول ${app.operatorCode}: '
                  'إن صحّ الكود يلتحق بأسطول مشغّله.' : ''}',
          '${missing.isNotEmpty ? '⚠️ Missing: '
                  '${missing.map((k) => DriverApplication.docLabels[k] ?? k).join(', ')}\n\n' : ''}'
              '${app.name} is granted the captain role immediately and their app opens '
              'from the waiting screen — no code needed.'
              '${app.operatorCode.isNotEmpty ? '\nFleet code ${app.operatorCode}: '
                  'if valid, they join that operator\'s fleet.' : ''}'),
      confirmLabel: tr('اعتماد', 'Approve'),
      confirmColor: AppColors.success,
    );
    if (ok != true || !context.mounted) return;
    try {
      await service.approveDriverApplicationDirect(app);
      if (context.mounted) {
        showSuccess(context, tr('اعتُمد ${app.name} — تطبيقه انفتح الآن',
            '${app.name} approved — their app is now open'));
        Navigator.pop(context);
      }
    } catch (_) {
      if (context.mounted) {
        showError(context, tr('تعذّر الاعتماد', 'Approval failed'));
      }
    }
  }

  Future<void> _reject(BuildContext context, FirebaseService service) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('رفض الطلب', 'Reject application')),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: tr('السبب', 'Reason'),
            hintText: tr('رخصة القيادة منتهية — يُعاد التقديم بعد تجديدها',
                'Driving license expired — reapply after renewing it'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('إلغاء', 'Cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(tr('رفض', 'Reject'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final note = ctrl.text.trim();
    if (note.isEmpty) {
      showError(context, tr('اكتب سبب الرفض — يُرسَل للمتقدّم',
          'Write a rejection reason — it is sent to the applicant'));
      return;
    }
    try {
      await service.rejectDriverApplication(
          applicationId: app.id, note: note);
      if (context.mounted) {
        showSuccess(context, tr('رُفض الطلب', 'Application rejected'));
        Navigator.pop(context);
      }
    } catch (_) {
      if (context.mounted) {
        showError(context, tr('تعذّر الرفض', 'Rejection failed'));
      }
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
            child: _DocThumb(docRef: url, width: 52, height: 52),
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

/// هل مرجع المستند رابط شبكة؟ وإلا فهو معرّف مستند Blob في مجموعة
/// `driver_application_docs` (نمط صفحة /join — الموقع بلا خادم رفع؛
/// وعند Blaze تصير القيم روابط Storage فيعود هذا الفرع تلقائياً).
bool _isNetworkRef(String ref) => ref.startsWith('http');

/// مصغّر مستند موحّد: شبكة أو Blob — واجهة واحدة للبطاقات وصور المركبة.
class _DocThumb extends StatelessWidget {
  final String docRef;
  final double width;
  final double height;
  const _DocThumb(
      {required this.docRef, required this.width, required this.height});

  Widget _placeholder({IconData icon = Icons.description_outlined}) =>
      Container(
        width: width,
        height: height,
        color: AppColors.surface,
        child: Icon(icon, color: AppColors.textGray, size: 22),
      );

  @override
  Widget build(BuildContext context) {
    if (_isNetworkRef(docRef)) {
      return CachedNetworkImage(
        imageUrl: docRef,
        width: width,
        height: height,
        fit: BoxFit.cover,
        memCacheWidth: 300,
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }
    // ‏Blob: تُجلب مرة وتخدمها ذاكرة Firestore المحلية بعدها — فتح
    // العارض لاحقاً لنفس المستند لا يعيد التنزيل.
    return FutureBuilder<Uint8List?>(
      future:
          context.read<FirebaseService>().fetchApplicationDocImage(docRef),
      builder: (_, snap) {
        final bytes = snap.data;
        if (bytes == null) {
          return _placeholder(
              icon: snap.connectionState == ConnectionState.waiting
                  ? Icons.hourglass_empty_rounded
                  : Icons.description_outlined);
        }
        return Image.memory(bytes,
            width: width, height: height, fit: BoxFit.cover);
      },
    );
  }
}

/// عارض المستند بحجم الشاشة مع تكبير بالأصابع — مراجعة إقامة أو رخصة
/// تتطلّب قراءة رقمٍ وتاريخِ انتهاء، وصورةٌ مصغّرة لا تكفي لذلك.
class _DocViewer extends StatelessWidget {
  final String label;
  final String url;
  const _DocViewer({required this.label, required this.url});

  Widget _error() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.broken_image_outlined,
              color: Colors.white54, size: 48),
          const SizedBox(height: 12),
          Text(tr('تعذّر تحميل المستند', 'Could not load the document'),
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          SelectableText(url,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final isNetwork = _isNetworkRef(url);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(label),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          // المشاركة للروابط فقط — معرّف Blob لا يفتح شيئاً خارج التطبيق.
          if (isNetwork)
            IconButton(
              tooltip: tr('مشاركة الرابط', 'Share link'),
              icon: const Icon(Icons.share_outlined),
              onPressed: () => Share.share(url),
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: isNetwork
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(),
                  errorWidget: (_, __, ___) => _error(),
                )
              : FutureBuilder<Uint8List?>(
                  future: context
                      .read<FirebaseService>()
                      .fetchApplicationDocImage(url),
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    final bytes = snap.data;
                    if (bytes == null) return _error();
                    return Image.memory(bytes, fit: BoxFit.contain);
                  },
                ),
        ),
      ),
    );
  }
}
