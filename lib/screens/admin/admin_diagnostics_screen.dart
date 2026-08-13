// lib/screens/admin/admin_diagnostics_screen.dart
//
// شاشة «التشخيص» — لقطة تقنية للحالة التشغيلية بضغطة، تُنسخ نصاً وتُرسل.
//
// سببها نمطٌ تكرّر طوال أسبوع: يقع عطل تشغيلي (طلب لم يصل كابتناً، كابتن
// لا يجد زرّ الاستلام)، فيُسأل المالك عن أرقام لا تظهر في أي شاشة —
// «كم `activeOrders` عند الكابتن؟»، «هل للمطعم إحداثيات؟»، «هل الإعدادات
// مقروءة؟» — فيصوّر ويرسل، وتنقص اللقطة فتُعاد الجولة. أضاع ذلك ساعاتٍ
// من وقته.
//
// فالمقصود ليس لوحة مراقبة جميلة: المقصود **سطرٌ واحد يُنسخ** فيه كل ما
// يُسأل عنه عادةً، بلا مفاتيح ولا وصول خارجي ولا لقطات. ويفيد المالك
// نفسه: يعرف بنظرة أين الخلل قبل أن يسأل.
//
// وكل بند فيها مشتقّ من عطلٍ وقع فعلاً، لا من تخمين لما قد يقع.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/helpers.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';

class AdminDiagnosticsScreen extends StatefulWidget {
  const AdminDiagnosticsScreen({super.key});

  @override
  State<AdminDiagnosticsScreen> createState() => _AdminDiagnosticsScreenState();
}

class _AdminDiagnosticsScreenState extends State<AdminDiagnosticsScreen> {
  String? _report;
  bool _running = false;
  String? _error;

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
    });
    final service = context.read<FirebaseService>();
    final buffer = StringBuffer();
    try {
      final drivers = await service.streamDrivers().first;
      final restaurants = await service.streamRestaurants().first;
      final orders = await service.streamActiveOrders().first;

      buffer.writeln('■ تشخيص زاد جو');
      buffer.writeln(_stamp(DateTime.now()));
      buffer.writeln();

      // ── الكباتن ─────────────────────────────────────────────────────
      // `activeOrders` يكتبه جهاز الكابتن، فإن أُغلق تطبيقه بعد آخر
      // تسليم بقي العدّاد على قيمته — وكابتنٌ عالقٌ على السقف يُخرج
      // نفسه من كل ترشيح. هذا أول ما يُسأل عنه عند «الطلب لم يصل أحداً».
      final online = drivers.where((d) => d.isOnline).toList();
      buffer.writeln('● الكباتن (${online.length} متصل من ${drivers.length})');
      if (drivers.isEmpty) {
        buffer.writeln('  — لا كباتن مسجّلون');
      }
      for (final d in drivers) {
        final carrying =
            orders.where((o) => o.driverId == d.id && o.status.isActive).length;
        final mismatch = carrying != d.activeOrders;
        buffer.writeln('  ${d.isOnline ? "🟢" : "⚪"} ${d.name}');
        buffer.writeln('     عدّاده: ${d.activeOrders} | الفعلي: $carrying'
            '${mismatch ? "  ⚠️ متعارضان" : ""}');
        buffer.writeln('     متاح: ${d.isAvailable ? "نعم" : "لا"}'
            ' | موقع: ${d.lat == null ? "⚠️ غير مسجَّل" : "مسجَّل"}'
            ' | عنقود: ${d.clusterLat == null ? "—" : "مضبوط"}');
      }
      buffer.writeln();

      // ── المطاعم ─────────────────────────────────────────────────────
      // مطعمٌ بلا إحداثيات كان يُسقط الإسناد صامتاً — وهو أوّل ما
      // انكشف في بلاغ «طلبات الهميلي لم تصل السائق».
      buffer.writeln('● المطاعم (${restaurants.length})');
      for (final r in restaurants) {
        final noCoords = r.lat == null || r.lng == null;
        buffer.writeln('  ${r.isOpen ? "🟢" : "🔴"} ${r.name}'
            '${noCoords ? "  ⚠️ بلا إحداثيات" : ""}');
      }
      buffer.writeln();

      // ── الطلبات الجارية ─────────────────────────────────────────────
      buffer.writeln('● الطلبات الجارية (${orders.length})');
      if (orders.isEmpty) buffer.writeln('  — لا شيء');
      final now = DateTime.now();
      for (final o in orders) {
        final age = now.difference(o.createdAt);
        final stuck = age.inMinutes >= 30;
        final noDriver = (o.driverId ?? '').isEmpty;
        buffer.writeln('  #${o.orderNumber} — ${o.status.label}');
        buffer.writeln('     ${o.restaurantName} | عمره ${_age(age)}'
            '${stuck ? "  ⚠️" : ""}');
        buffer.writeln('     الكابتن: '
            '${noDriver ? "⚠️ بلا كابتن" : (o.driverName ?? o.driverId)}'
            '${o.needsDriverAcknowledgement ? " (عرض معلّق)" : ""}');
        if (o.status == OrderStatus.readyForPickup) {
          buffer.writeln('     وصل الكابتن: '
              '${o.arrivedAtRestaurantAt == null ? "لا" : "نعم"}'
              ' | ختم المطعم: '
              '${o.restaurantHandoverAt == null ? "لا" : "نعم"}');
        }
      }
      buffer.writeln();

      // ── الإعدادات التشغيلية ─────────────────────────────────────────
      // تُقرأ من `delivery_settings/incentives`؛ وقد مرّت مرحلةٌ كانت
      // فيها في مستندٍ لا يقرؤه تطبيقا المطعم والكابتن، فتعود للقيم
      // الافتراضية أبداً ويصير ضبطها من اللوحة بلا أثر (خلاف بند ج١).
      buffer.writeln('● الإعدادات التشغيلية');
      try {
        final s = await service.getIncentiveSettings();
        buffer.writeln('  سقف الحمولة: ${s.maxOrdersPerDriver}');
        buffer.writeln('  نطاق العنقود: ${s.stackRadiusKm} كم');
        buffer.writeln(
            '  تعويض الإلغاء بعد التحضير: ${s.restaurantCancelCompensationPercent}%');
        buffer.writeln('  القراءة: ✅ ناجحة');
      } catch (e) {
        buffer.writeln('  ⚠️ تعذّرت القراءة — $e');
      }

      setState(() => _report = buffer.toString());
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  static String _stamp(DateTime t) =>
      '${t.year}/${t.month}/${t.day} — '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _age(Duration d) {
    if (d.inMinutes < 60) return 'منذ ${d.inMinutes} د';
    if (d.inHours < 24) return 'منذ ${d.inHours} س';
    return 'منذ ${d.inDays} يوم';
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'لقطة تقنية للحالة التشغيلية. اضغط «افحص»، ثم «انسخ» وأرسل النص '
          'عند أي عطل — يغني عن اللقطات وجولات الأسئلة.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textGray),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(_running ? 'جارٍ الفحص…' : 'افحص الآن'),
              onPressed: _running ? null : _run,
            ),
          ),
          if (_report != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: const Text('انسخ'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _report!));
                  showSuccess(context, 'نُسخ التقرير — الصقه في المحادثة');
                },
              ),
            ),
          ],
        ]),
        const SizedBox(height: 14),

        // مصالحة التوافر: العلاج المباشر لأشهر عطل يكشفه التقرير أعلاه
        // (عدّاد يخالف الفعلي). زرّها هنا لا في شاشة أخرى، فمن رأى العطل
        // يعالجه في مكانه.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('مصالحة توافر الكباتن',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              const SizedBox(height: 4),
              const Text(
                'تُصفّر عدّاد الحمولة لكل كابتن لا طلب جارياً له — استعملها '
                'إن ظهر أعلاه «عدّاده يخالف الفعلي».',
                style: TextStyle(fontSize: 12.5, color: AppColors.textGray),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.healing_outlined),
                label: const Text('صالِح الآن'),
                onPressed: () async {
                  try {
                    final n = await service.reconcileDriverAvailability();
                    if (context.mounted) {
                      showSuccess(
                          context,
                          n == 0
                              ? 'لا كابتن عالقاً — الحالة سليمة'
                              : 'حُرِّر $n كابتن');
                    }
                    if (_report != null) _run();
                  } catch (e) {
                    if (context.mounted) showError(context, 'تعذّرت المصالحة: $e');
                  }
                },
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        if (_error != null)
          Card(
            color: AppColors.errorLight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('تعذّر الفحص: $_error',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.error)),
            ),
          ),
        if (_report != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                _report!,
                style: const TextStyle(fontSize: 12.5, height: 1.6),
              ),
            ),
          ),
      ],
    );
  }
}
