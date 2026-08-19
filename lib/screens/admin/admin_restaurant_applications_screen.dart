// lib/screens/admin/admin_restaurant_applications_screen.dart
//
// مراجعة طلبات انضمام المطاعم — نظير شاشة طلبات الكباتن: قائمة بحالاتها،
// تفاصيل بالمستندات (Blob من `restaurant_application_docs`) بعارضٍ يكبَّر
// بالأصابع، واعتماد يربط الحساب بمطعم يختاره المدير (يُنشأ من شاشة
// المطاعم أولاً إن لم يوجد) فينفتح تطبيق صاحبه من شاشة انتظاره فوراً.
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

const _docsCollection = 'restaurant_application_docs';

class AdminRestaurantApplicationsScreen extends StatelessWidget {
  const AdminRestaurantApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<List<RestaurantApplication>>(
      stream: service.streamRestaurantApplications,
      builder: (ctx, apps) {
        if (apps.isEmpty) {
          return const AppEmpty(
            emoji: '🏪',
            title: 'لا طلبات مطاعم بعد',
            subtitle: 'تصل هنا حين يسجّل صاحب مطعم من تطبيق المطعم '
                '(«سجّل مطعمك من هنا»)',
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
  final RestaurantApplication app;
  const _AppCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _AppDetailScreen(app: app)),
        ),
        title: Text(app.restaurantName,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
        subtitle: Text(
          [
            app.ownerName,
            app.phone,
            '${app.documents.length} مستند',
            if (app.missingRequired.isNotEmpty)
              'ناقص ${app.missingRequired.length}',
          ].where((e) => e.isNotEmpty).join(' • '),
          style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
        ),
        trailing: StatusChip(label: app.status.label, color: app.status.color),
      ),
    );
  }
}

class _AppDetailScreen extends StatelessWidget {
  final RestaurantApplication app;
  const _AppDetailScreen({required this.app});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final missing = app.missingRequired;

    return Scaffold(
      appBar: AppBar(title: Text(app.restaurantName)),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Row(children: [
          StatusChip(label: app.status.label, color: app.status.color),
          const Spacer(),
          Text(
              '${app.createdAt.day}/${app.createdAt.month}/${app.createdAt.year}',
              style:
                  const TextStyle(fontSize: 12.5, color: AppColors.textGray)),
        ]),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('البيانات',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _field('المالك', app.ownerName),
                  _field('الجوال', app.phone, copyable: true),
                  _field('البريد', app.email, copyable: true),
                  _field('الحي', app.district),
                  _field('الوصف', app.description),
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
                    '${missing.map((k) => RestaurantApplication.docLabels[k] ?? k).join('، ')}',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.error)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        const SectionHeader(title: 'المستندات — اضغط للتكبير'),
        ...RestaurantApplication.docLabels.entries.map((e) {
          final ref = app.documents[e.key] ?? '';
          if (ref.isEmpty) return const SizedBox.shrink();
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => _DocViewer(label: e.value, docId: ref)),
              ),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _DocThumb(docId: ref, width: 52, height: 52),
              ),
              title: Text(e.value, style: const TextStyle(fontSize: 13.5)),
              trailing: const Icon(Icons.zoom_in_rounded, size: 20),
            ),
          );
        }),
        if (app.status == DriverApplicationStatus.rejected &&
            app.reviewNote.isNotEmpty) ...[
          const SizedBox(height: 14),
          Card(
            color: AppColors.errorLight,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('سبب الرفض: ${app.reviewNote}',
                  style: const TextStyle(fontSize: 13.5)),
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
              label: const Text('اعتماد وربط بمطعم — يفتح تطبيقه فوراً'),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.success),
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

  /// الاعتماد يستلزم مطعماً قائماً يُربط به الحساب — الكيان (الموقع،
  /// العمولة، المنيو) يُبنى من شاشة المطاعم بأدواتها الكاملة، وهنا الربط
  /// والقرار فقط. هذا فصلٌ مقصود لا نقص: بناء مطعم كامل داخل حوار ضيّق
  /// كان سيكرّر شاشة قائمة بأدوات أفقر.
  Future<void> _approve(BuildContext context, FirebaseService service,
      List<String> missing) async {
    String? restaurantId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setLocal) => AlertDialog(
          title: const Text('اعتماد وربط بمطعم'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (missing.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                    '⚠️ ناقص: '
                    '${missing.map((k) => RestaurantApplication.docLabels[k] ?? k).join('، ')}',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.error)),
              ),
            const Text(
                'اختر المطعم الذي يُربط به هذا الحساب — أنشئه أولاً من '
                'شاشة «المطاعم» إن لم يوجد.',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            StreamBuilder<List<Restaurant>>(
              stream: service.streamRestaurants(),
              builder: (c, snap) => DropdownButtonFormField<String>(
                value: restaurantId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المطعم'),
                items: (snap.data ?? const [])
                    .map((r) => DropdownMenuItem(
                          value: r.id,
                          child: Text(r.displayName,
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setLocal(() => restaurantId = v),
              ),
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
                child: const Text('اعتماد')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    if (restaurantId == null) {
      showError(context, 'اختر المطعم أولاً — أو أنشئه من شاشة المطاعم');
      return;
    }
    try {
      await service.approveRestaurantApplication(
          application: app, restaurantId: restaurantId!);
      if (context.mounted) {
        showSuccess(context,
            'اعتُمد ${app.restaurantName} — تطبيق صاحبه انفتح الآن');
        Navigator.pop(context);
      }
    } catch (_) {
      if (context.mounted) showError(context, 'تعذّر الاعتماد');
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
            hintText: 'السجل التجاري منتهٍ — يُعاد التقديم بعد تجديده',
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
      showError(context, 'اكتب سبب الرفض — يظهر للمتقدّم في تطبيقه');
      return;
    }
    try {
      await service.rejectRestaurantApplication(
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

/// مصغّر مستند Blob — يُجلب مرة وتخدمه ذاكرة Firestore المحلية بعدها.
class _DocThumb extends StatelessWidget {
  final String docId;
  final double width;
  final double height;
  const _DocThumb(
      {required this.docId, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: context
          .read<FirebaseService>()
          .fetchApplicationDocImage(docId, collection: _docsCollection),
      builder: (_, snap) {
        final bytes = snap.data;
        if (bytes == null) {
          return Container(
            width: width,
            height: height,
            color: AppColors.surface,
            child: Icon(
                snap.connectionState == ConnectionState.waiting
                    ? Icons.hourglass_empty_rounded
                    : Icons.description_outlined,
                color: AppColors.textGray,
                size: 22),
          );
        }
        return Image.memory(bytes,
            width: width, height: height, fit: BoxFit.cover);
      },
    );
  }
}

class _DocViewer extends StatelessWidget {
  final String label;
  final String docId;
  const _DocViewer({required this.label, required this.docId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(label),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: FutureBuilder<Uint8List?>(
            future: context
                .read<FirebaseService>()
                .fetchApplicationDocImage(docId, collection: _docsCollection),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              final bytes = snap.data;
              if (bytes == null) {
                return const Text('تعذّر تحميل المستند',
                    style: TextStyle(color: Colors.white70));
              }
              return Image.memory(bytes, fit: BoxFit.contain);
            },
          ),
        ),
      ),
    );
  }
}
