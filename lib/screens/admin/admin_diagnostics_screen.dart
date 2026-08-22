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
import '../../providers/app_check_service.dart';
import '../../providers/firebase_service.dart';
import '../../utils/app_lang.dart';
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
  String? _appCheckToken;
  bool _appCheckLoading = false;
  String? _exchangeResult;

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

      buffer.writeln(tr('■ تشخيص زاد جو', '■ ZadGo diagnostics'));
      buffer.writeln(_stamp(DateTime.now()));
      buffer.writeln();

      // ── الكباتن ─────────────────────────────────────────────────────
      // `activeOrders` يكتبه جهاز الكابتن، فإن أُغلق تطبيقه بعد آخر
      // تسليم بقي العدّاد على قيمته — وكابتنٌ عالقٌ على السقف يُخرج
      // نفسه من كل ترشيح. هذا أول ما يُسأل عنه عند «الطلب لم يصل أحداً».
      final online = drivers.where((d) => d.isOnline).toList();
      buffer.writeln(
          tr('● الكباتن (${online.length} متصل من ${drivers.length})',
              '● Captains (${online.length} online of ${drivers.length})'));
      if (drivers.isEmpty) {
        buffer.writeln(tr('  — لا كباتن مسجّلون', '  — no captains registered'));
      }
      for (final d in drivers) {
        final carrying =
            orders.where((o) => o.driverId == d.id && o.status.isActive).length;
        final mismatch = carrying != d.activeOrders;
        buffer.writeln('  ${d.isOnline ? "🟢" : "⚪"} ${d.name}');
        buffer.writeln(tr(
            '     عدّاده: ${d.activeOrders} | الفعلي: $carrying'
                '${mismatch ? "  ⚠️ متعارضان" : ""}',
            '     counter: ${d.activeOrders} | actual: $carrying'
                '${mismatch ? "  ⚠️ mismatch" : ""}'));
        buffer.writeln(tr(
            '     متاح: ${d.isAvailable ? "نعم" : "لا"}'
                ' | موقع: ${d.lat == null ? "⚠️ غير مسجَّل" : "مسجَّل"}'
                ' | عنقود: ${d.clusterLat == null ? "—" : "مضبوط"}',
            '     available: ${d.isAvailable ? "yes" : "no"}'
                ' | location: ${d.lat == null ? "⚠️ not recorded" : "recorded"}'
                ' | cluster: ${d.clusterLat == null ? "—" : "set"}'));
      }
      buffer.writeln();

      // ── المطاعم ─────────────────────────────────────────────────────
      // مطعمٌ بلا إحداثيات كان يُسقط الإسناد صامتاً — وهو أوّل ما
      // انكشف في بلاغ «طلبات الهميلي لم تصل السائق».
      buffer.writeln(tr('● المطاعم (${restaurants.length})',
          '● Restaurants (${restaurants.length})'));
      for (final r in restaurants) {
        final noCoords = r.lat == null || r.lng == null;
        buffer.writeln(tr(
            '  ${r.isOpen ? "🟢" : "🔴"} ${r.name}'
                '${noCoords ? "  ⚠️ بلا إحداثيات" : ""}',
            '  ${r.isOpen ? "🟢" : "🔴"} ${r.name}'
                '${noCoords ? "  ⚠️ no coordinates" : ""}'));
      }
      buffer.writeln();

      // ── الطلبات الجارية ─────────────────────────────────────────────
      buffer.writeln(tr('● الطلبات الجارية (${orders.length})',
          '● Active orders (${orders.length})'));
      if (orders.isEmpty) buffer.writeln(tr('  — لا شيء', '  — none'));
      final now = DateTime.now();
      for (final o in orders) {
        final age = now.difference(o.createdAt);
        final stuck = age.inMinutes >= 30;
        final noDriver = (o.driverId ?? '').isEmpty;
        buffer.writeln('  #${o.orderNumber} — ${o.status.label}');
        buffer.writeln(tr(
            '     ${o.restaurantName} | عمره ${_age(age)}'
                '${stuck ? "  ⚠️" : ""}',
            '     ${o.restaurantName} | age ${_age(age)}'
                '${stuck ? "  ⚠️" : ""}'));
        buffer.writeln(tr(
            '     الكابتن: '
                '${noDriver ? "⚠️ بلا كابتن" : (o.driverName ?? o.driverId)}'
                '${o.needsDriverAcknowledgement ? " (عرض معلّق)" : ""}',
            '     captain: '
                '${noDriver ? "⚠️ none" : (o.driverName ?? o.driverId)}'
                '${o.needsDriverAcknowledgement ? " (offer pending)" : ""}'));
        if (o.status == OrderStatus.readyForPickup) {
          buffer.writeln(tr(
              '     وصل الكابتن: '
                  '${o.arrivedAtRestaurantAt == null ? "لا" : "نعم"}'
                  ' | ختم المطعم: '
                  '${o.restaurantHandoverAt == null ? "لا" : "نعم"}',
              '     captain arrived: '
                  '${o.arrivedAtRestaurantAt == null ? "no" : "yes"}'
                  ' | restaurant handover: '
                  '${o.restaurantHandoverAt == null ? "no" : "yes"}'));
        }
      }
      buffer.writeln();

      // ── الإعدادات التشغيلية ─────────────────────────────────────────
      // تُقرأ من `delivery_settings/incentives`؛ وقد مرّت مرحلةٌ كانت
      // فيها في مستندٍ لا يقرؤه تطبيقا المطعم والكابتن، فتعود للقيم
      // الافتراضية أبداً ويصير ضبطها من اللوحة بلا أثر (خلاف بند ج١).
      buffer.writeln(tr('● الإعدادات التشغيلية', '● Operational settings'));
      try {
        final s = await service.getIncentiveSettings();
        buffer.writeln(tr('  سقف الحمولة: ${s.maxOrdersPerDriver}',
            '  load cap: ${s.maxOrdersPerDriver}'));
        buffer.writeln(tr('  نطاق العنقود: ${s.stackRadiusKm} كم',
            '  cluster radius: ${s.stackRadiusKm} km'));
        buffer.writeln(tr(
            '  تعويض الإلغاء بعد التحضير: ${s.restaurantCancelCompensationPercent}%',
            '  cancel compensation after prep: ${s.restaurantCancelCompensationPercent}%'));
        buffer.writeln(tr('  القراءة: ✅ ناجحة', '  read: ✅ ok'));
      } catch (e) {
        buffer.writeln(tr('  ⚠️ تعذّرت القراءة — $e', '  ⚠️ read failed — $e'));
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
    if (d.inMinutes < 60) {
      return tr('منذ ${d.inMinutes} د', '${d.inMinutes} min ago');
    }
    if (d.inHours < 24) return tr('منذ ${d.inHours} س', '${d.inHours} h ago');
    return tr('منذ ${d.inDays} يوم', '${d.inDays} d ago');
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          tr('لقطة تقنية للحالة التشغيلية. اضغط «افحص»، ثم «انسخ» وأرسل النص '
                  'عند أي عطل — يغني عن اللقطات وجولات الأسئلة.',
              'A technical snapshot of the operational state. Tap "Run check", '
                  'then "Copy" and send the text on any incident — it replaces '
                  'screenshots and rounds of questions.'),
          style: const TextStyle(fontSize: 12.5, color: AppColors.textGray),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(_running
                  ? tr('جارٍ الفحص…', 'Checking…')
                  : tr('افحص الآن', 'Run check')),
              onPressed: _running ? null : _run,
            ),
          ),
          if (_report != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: Text(tr('انسخ', 'Copy')),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _report!));
                  showSuccess(
                      context,
                      tr('نُسخ التقرير — الصقه في المحادثة',
                          'Report copied — paste it into the chat'));
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
              Text(tr('مصالحة توافر الكباتن', 'Captain availability repair'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13.5)),
              const SizedBox(height: 4),
              Text(
                tr('تُصفّر عدّاد الحمولة لكل كابتن لا طلب جارياً له — استعملها '
                        'إن ظهر أعلاه «عدّاده يخالف الفعلي».',
                    'Resets the load counter for every captain with no active '
                        'order — use it if "counter mismatch" shows above.'),
                style: const TextStyle(fontSize: 12.5, color: AppColors.textGray),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.healing_outlined),
                label: Text(tr('صالِح الآن', 'Repair now')),
                onPressed: () async {
                  try {
                    final n = await service.reconcileDriverAvailability();
                    if (context.mounted) {
                      showSuccess(
                          context,
                          n == 0
                              ? tr('لا كابتن عالقاً — الحالة سليمة',
                                  'No stuck captains — all healthy')
                              : tr('حُرِّر $n كابتن', '$n captains released'));
                    }
                    if (_report != null) _run();
                  } catch (e) {
                    if (context.mounted) {
                      showError(context,
                          tr('تعذّرت المصالحة: $e', 'Repair failed: $e'));
                    }
                  }
                },
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // رمز حماية الذكاء: فرض App Check على AI Logic لا يُعطَّل، وكل
        // جهاز إداري يولّد رمز تصحيح يجب تسجيله في الكونسول مرة واحدة —
        // وإلا ظهر «App Check token is invalid» عند زر «اقترح رداً».
        // مكانه هنا لأن انكشافه كان عبر التشخيص، وعلاجه بيد من يقرؤه.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('رمز حماية الذكاء (App Check)', 'AI protection token (App Check)'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13.5)),
              const SizedBox(height: 4),
              Text(
                tr('إن ظهر خطأ «App Check token is invalid» عند «اقترح رداً»: '
                        'أظهر الرمز، انسخه، وسجّله مرة واحدة في كونسول فيربيز: '
                        'App Check ← Apps ← Admin ← ⋮ Manage debug tokens ← Add.',
                    'If "App Check token is invalid" appears on "Suggest a reply": '
                        'show the token, copy it, and register it once in the '
                        'Firebase console: App Check → Apps → Admin → '
                        '⋮ Manage debug tokens → Add.'),
                style: const TextStyle(fontSize: 12.5, color: AppColors.textGray),
              ),
              const SizedBox(height: 8),
              if (_appCheckToken == null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.shield_outlined),
                  label: Text(_appCheckLoading
                      ? tr('جارٍ التوليد…', 'Generating…')
                      : tr('أظهر رمز هذا الجهاز', "Show this device's token")),
                  onPressed: _appCheckLoading
                      ? null
                      : () async {
                          setState(() => _appCheckLoading = true);
                          final t = await AppCheckService.readDebugToken();
                          if (!mounted) return;
                          setState(() {
                            _appCheckLoading = false;
                            _appCheckToken = t;
                          });
                          if (t == null) {
                            showError(
                                context,
                                tr('لم يُعثر على الرمز — أعد فتح التطبيق ثم حاول',
                                    'Token not found — reopen the app and try again'));
                          }
                        },
                )
              else ...[
                Row(children: [
                  Expanded(
                    child: SelectableText(_appCheckToken!,
                        style: const TextStyle(
                            fontSize: 12.5, fontFamily: 'monospace')),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: tr('انسخ', 'Copy'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _appCheckToken!));
                      showSuccess(
                          context,
                          tr('نُسخ — الصقه في الكونسول',
                              'Copied — paste it into the console'));
                    },
                  ),
                ]),
                const SizedBox(height: 6),
                // فحص التبادل: بعد تسجيل الرمز في الكونسول، «نجح» هنا =
                // الحماية سليمة؛ وأي فشل يعرض نص خطأ جوجل الحرفي —
                // أُضيف حين سُجّل الرمز صحيحاً وبقي الرفض (2026-08-16).
                OutlinedButton.icon(
                  icon: const Icon(Icons.sync_lock_outlined, size: 17),
                  label: Text(_exchangeResult == null
                      ? tr('افحص التبادل مع جوجل', 'Test the Google exchange')
                      : tr('أعد فحص التبادل', 'Retest the exchange')),
                  onPressed: () async {
                    final r = await AppCheckService.exchangeStatus();
                    if (mounted) setState(() => _exchangeResult = r);
                  },
                ),
                if (_exchangeResult != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: SelectableText(_exchangeResult!,
                        style: TextStyle(
                            fontSize: 12,
                            color: _exchangeResult!.startsWith('نجح')
                                ? AppColors.success
                                : AppColors.error)),
                  ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // تقرير الذراع الخادمية (فحص الأسعار): يكتبه الخادم وحده —
        // العملاء ممنوعون بالقواعد، فما يُعرض هنا لا يلفّقه جهاز.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<Map<String, dynamic>?>(
              stream: service.streamServerReport('price_audit'),
              builder: (ctx, snap) {
                final r = snap.data;
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          tr('فحص الأسعار الخادمي (الذراع ١)',
                              'Server-side price audit (arm 1)'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13.5)),
                      const SizedBox(height: 6),
                      if (r == null)
                        Text(
                          tr('لم يصل تقرير بعد — الذراع الخادمية قيد التفعيل '
                                  '(انظر server/supabase-arm).',
                              'No report yet — the server arm is being enabled '
                                  '(see server/supabase-arm).'),
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textGray),
                        )
                      else ...[
                        Text(
                          tr('آخر فحص: يوم ${r['day'] ?? '؟'} — فُحص '
                                  '${r['ordersChecked'] ?? '؟'} طلباً',
                              'Last audit: day ${r['day'] ?? '?'} — '
                                  '${r['ordersChecked'] ?? '?'} orders checked'),
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        const SizedBox(height: 6),
                        if ((r['findingsCount'] ?? 0) == 0)
                          Text(
                              tr('✅ كل الطلبات مطابقة — لا مخالفات',
                                  '✅ All orders match — no findings'),
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold))
                        else ...[
                          Text(
                              tr('⚠️ ${r['findingsCount']} مخالفة:',
                                  '⚠️ ${r['findingsCount']} findings:'),
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold)),
                          ...((r['findings'] as List? ?? const [])
                              .whereType<Map>()
                              .take(10)
                              .map((f) => Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                        tr('• طلب #${f['orderNumber']}: '
                                                '${f['detail']}',
                                            '• order #${f['orderNumber']}: '
                                                '${f['detail']}'),
                                        style:
                                            const TextStyle(fontSize: 12)),
                                  ))),
                        ],
                      ],
                    ]);
              },
            ),
          ),
        ),
        const SizedBox(height: 14),

        if (_error != null)
          Card(
            color: AppColors.errorLight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(tr('تعذّر الفحص: $_error', 'Check failed: $_error'),
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
