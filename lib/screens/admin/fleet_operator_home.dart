// lib/screens/admin/fleet_operator_home.dart
//
// شاشة مشغّل الأسطول — «بأحدث طراز» (دفعة ٨، بأمر المالك بعد بحث نماذج
// جاهز/Logi وهنقرستيشن 3PL وكيتا): كانت عرضاً فقط، وصارت لوحة تشغيلٍ
// كاملة على ثلاثة تبويبات:
//   ١) كباتني: إضافة كابتن بكود دعوة، حظر/تفعيل، تسوية مالية، دفتر
//      الكابتن، اتصال، وفصلٌ عن الأسطول.
//   ٢) الخريطة: مواقع كباتنه الحيّة وحالتهم، وطلباتهم الجارية مع زرّ
//      اتصالٍ بالعميل (فتحها ختمُ التبعية عند الإسناد).
//   ٣) المال: مستحقّاته المتراكمة ودفتره وأرصدة كباتنه.
//
// القيد الحقيقي في قواعد Firestore لا هنا: كباتنه حصراً (operatorId==uid)،
// صلاحيات مسمّاة (isActive/فصل/تسوية ذرّية)، ولا مساس بالحصص والإنذارات.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/app_lang.dart';
import '../../utils/helpers.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/osm_attribution.dart';

class FleetOperatorHome extends StatefulWidget {
  const FleetOperatorHome({super.key});

  @override
  State<FleetOperatorHome> createState() => _FleetOperatorHomeState();
}

class _FleetOperatorHomeState extends State<FleetOperatorHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();
    final uid = auth.user?.uid ?? '';

    if (uid.isEmpty) {
      return Scaffold(
        body: AppEmpty(
            emoji: '👤',
            title: tr('تعذّر تحميل حسابك', 'Could not load your account')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('أسطولي — ${auth.user?.name ?? ''}',
            'My fleet — ${auth.user?.name ?? ''}')),
        actions: [
          const LanguageToggleButton(),
          IconButton(
            tooltip: tr('تسجيل الخروج', 'Sign out'),
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final ok = await showConfirmDialog(context,
                  title: tr('تسجيل الخروج', 'Sign out'),
                  content: tr('هل تريد تسجيل الخروج؟',
                      'Do you want to sign out?'),
                  confirmLabel: tr('خروج', 'Sign out'),
                  confirmColor: AppColors.error);
              if (ok == true) auth.logout();
            },
          ),
        ],
      ),
      body: StreamBuilder<FleetOperator?>(
        stream: service.streamFleetOperator(uid),
        builder: (ctx, opSnap) {
          final op = opSnap.data;
          return AppStreamBuilder<List<Driver>>(
            stream: () => service.streamOperatorDrivers(uid),
            builder: (ctx, drivers) => AppStreamBuilder<List<Order>>(
              stream: () => service.streamOperatorOrders(uid),
              builder: (ctx, orders) {
                switch (_tab) {
                  case 1:
                    return _FleetMapTab(drivers: drivers, orders: orders);
                  case 2:
                    return _MoneyTab(
                        uid: uid, fleetOp: op, drivers: drivers,
                        orders: orders);
                  default:
                    return _CaptainsTab(uid: uid, drivers: drivers);
                }
              },
            ),
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.groups_2_outlined),
              label: tr('كباتني', 'My captains')),
          NavigationDestination(
              icon: const Icon(Icons.map_outlined),
              label: tr('الخريطة', 'Map')),
          NavigationDestination(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: tr('المال', 'Money')),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// تبويب «كباتني»: إدارة الأسطول — إضافة/حظر/تسوية/دفتر/فصل.
// ═══════════════════════════════════════════════════════════════════════

class _CaptainsTab extends StatelessWidget {
  final String uid;
  final List<Driver> drivers;
  const _CaptainsTab({required this.uid, required this.drivers});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _AddCaptainCard(uid: uid),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(tr('كباتنك (${drivers.length})',
                  'Your captains (${drivers.length})'),
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        if (drivers.isEmpty)
          AppEmpty(
              emoji: '🛵',
              title: tr('لا كباتن بعد', 'No captains yet'),
              subtitle: tr(
                  'أضف كابتناً بكود دعوة من الأعلى، أو يسنده المدير إليك.',
                  'Invite a captain with a code above, or the admin assigns one to you.'))
        else
          ...drivers.map((d) => _CaptainCard(driver: d)),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// «أضف كابتناً» بنمط هنقرستيشن/جاهز المقلوب لصالحنا: بدل نماذج بريدٍ
/// تعالجها المنصّة يدوياً، كودُ دعوةٍ فوريّ يسجّل به الكابتن فيلتحق
/// بالأسطول تلقائياً (القاعدة توثّق التبعية من الكود المستهلَك باسمه).
class _AddCaptainCard extends StatefulWidget {
  final String uid;
  const _AddCaptainCard({required this.uid});

  @override
  State<_AddCaptainCard> createState() => _AddCaptainCardState();
}

class _AddCaptainCardState extends State<_AddCaptainCard> {
  bool _creating = false;

  Future<void> _createCode() async {
    setState(() => _creating = true);
    try {
      final code = await context
          .read<FirebaseService>()
          .operatorCreateDriverCode(widget.uid);
      if (!mounted) return;
      showSuccess(context,
          tr('أُنشئ كود الدعوة: ${code.code}', 'Invite code created: ${code.code}'));
    } catch (_) {
      if (mounted) {
        showError(context,
            tr('تعذّر إنشاء الكود — حاول مجدداً', 'Couldn\'t create the code — try again'));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  String _inviteText(String code) => tr(
      'انضمّ لأسطولي على تطبيق زاد جو للكباتن: حمّل تطبيق الكابتن، قدّم '
          '«طلب انضمام كابتن» بمستنداتك، وأدخل كود الدعوة «$code» في خانة '
          'كود المشغّل (صالح ٧ أيام) — تعتمدك الإدارة فتلتحق بأسطولي. 🛵',
      'Join my fleet on the ZadGo captain app: download the captain app, '
          'submit the captain application with your documents, and enter '
          'invite code "$code" in the fleet-operator field (valid 7 days) — '
          'once admin approves, you join my fleet. 🛵');

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.person_add_alt_1_rounded,
                color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(tr('أضف كابتناً لأسطولك', 'Add a captain to your fleet'),
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.bold)),
            ),
            FilledButton.icon(
              onPressed: _creating ? null : _createCode,
              icon: _creating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.dark))
                  : const Icon(Icons.qr_code_2_rounded, size: 18),
              label: Text(tr('كود دعوة', 'Invite code')),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                tr('يقدّم الكابتن طلب انضمام في تطبيق الكباتن ويُدخل الكود فيه، '
                        'وبعد اعتماد الإدارة لمستنداته يلتحق بأسطولك.',
                    'The captain submits the join application in the captain app with your code; '
                        'once admin approves their documents they join your fleet.'),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textGray)),
          ),
          // أكواد الدعوة الحيّة: نسخ/مشاركة/حذف، وحالة المستهلَك باسم من.
          StreamBuilder<List<RegistrationCode>>(
            stream: service.streamOperatorCodes(widget.uid),
            builder: (ctx, snap) {
              final codes = snap.data ?? const <RegistrationCode>[];
              if (codes.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  const Divider(height: 18),
                  ...codes.take(5).map((c) => Row(children: [
                        Icon(
                            c.isUsed
                                ? Icons.check_circle_rounded
                                : (c.isExpired
                                    ? Icons.timer_off_outlined
                                    : Icons.vpn_key_outlined),
                            size: 16,
                            color: c.isUsed
                                ? AppColors.success
                                : (c.isExpired
                                    ? AppColors.error
                                    : AppColors.primary)),
                        const SizedBox(width: 6),
                        Text(c.code,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                letterSpacing: 1.5)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              c.isUsed
                                  ? tr('استُخدم — ${c.usedByName ?? ''}',
                                      'Used — ${c.usedByName ?? ''}')
                                  : (c.isExpired
                                      ? tr('منتهٍ', 'Expired')
                                      : tr('بانتظار الطلب واعتماد الإدارة',
                                          'Awaiting application & admin approval')),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppColors.textGray)),
                        ),
                        if (!c.isUsed) ...[
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: tr('نسخ', 'Copy'),
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            onPressed: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: c.code));
                              if (ctx.mounted) {
                                showSuccess(
                                    ctx, tr('نُسخ الكود', 'Code copied'));
                              }
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: tr('مشاركة', 'Share'),
                            icon: const Icon(Icons.share_rounded, size: 16),
                            onPressed: () => Share.share(_inviteText(c.code)),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: tr('حذف', 'Delete'),
                            icon: const Icon(Icons.delete_outline,
                                size: 16, color: AppColors.error),
                            onPressed: () =>
                                service.operatorDeleteCode(c.code),
                          ),
                        ],
                      ])),
                ],
              );
            },
          ),
        ]),
      ),
    );
  }
}

class _CaptainCard extends StatelessWidget {
  final Driver driver;
  const _CaptainCard({required this.driver});

  Future<void> _toggleActive(BuildContext context) async {
    final d = driver;
    final service = context.read<FirebaseService>();
    final blocking = d.isActive;
    final ok = await showConfirmDialog(context,
        title: blocking
            ? tr('حظر ${d.name}؟', 'Suspend ${d.name}?')
            : tr('إعادة تفعيل ${d.name}؟', 'Reactivate ${d.name}?'),
        content: blocking
            ? tr('لن تصله عروض طلبات حتى تعيد تفعيله.',
                'They will stop receiving order offers until you reactivate them.')
            : tr('سيعود لاستقبال عروض الطلبات.',
                'They will start receiving order offers again.'),
        confirmLabel: blocking ? tr('حظر', 'Suspend') : tr('تفعيل', 'Activate'),
        confirmColor: blocking ? AppColors.error : AppColors.success);
    if (ok != true || !context.mounted) return;
    try {
      await service.operatorSetDriverActive(d.id, !blocking);
      if (context.mounted) {
        showSuccess(
            context,
            blocking
                ? tr('حُظر الكابتن', 'Captain suspended')
                : tr('أُعيد تفعيل الكابتن', 'Captain reactivated'));
      }
    } catch (_) {
      if (context.mounted) {
        showError(context, tr('تعذّر التغيير', 'Couldn\'t apply the change'));
      }
    }
  }

  Future<void> _release(BuildContext context) async {
    final d = driver;
    final service = context.read<FirebaseService>();
    final ok = await showConfirmDialog(context,
        title: tr('فصل ${d.name} عن أسطولك؟', 'Remove ${d.name} from your fleet?'),
        content: tr(
            'يخرج من أسطولك ويصير كابتناً مستقلاً — حسابه ودفاتره تبقى، '
                'ولا يعود إليك إلا بكود دعوة جديد أو بإسناد المدير.',
            'They leave your fleet and become independent — their account and '
                'ledger remain, and they only return via a new invite code or admin assignment.'),
        confirmLabel: tr('فصل', 'Remove'),
        confirmColor: AppColors.error);
    if (ok != true || !context.mounted) return;
    try {
      await service.operatorReleaseDriver(d.id);
      if (context.mounted) {
        showSuccess(context, tr('فُصل عن أسطولك', 'Removed from your fleet'));
      }
    } catch (_) {
      if (context.mounted) {
        showError(context, tr('تعذّر الفصل', 'Couldn\'t remove'));
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final d = driver;
    final statusColor = !d.isActive
        ? AppColors.error
        : d.isOnline
            ? AppColors.success
            : (d.isAvailable ? AppColors.warning : AppColors.textGray);
    final statusText = !d.isActive
        ? tr('محظور', 'Suspended')
        : d.isOnline
            ? tr('متصل', 'Online')
            : (d.isAvailable
                ? tr('متاح', 'Available')
                : tr('غير متاح', 'Unavailable'));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(
                      d.name.isEmpty ? tr('(بلا اسم)', '(no name)') : d.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(statusText,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: statusColor)),
                ),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 10, runSpacing: 4, children: [
                _chip(Icons.local_shipping_outlined,
                    tr('${d.totalDeliveries} توصيلة', '${d.totalDeliveries} deliveries')),
                _chip(
                    Icons.star_rounded,
                    d.ratingCount <= 0
                        ? tr('جديد', 'New')
                        : d.rating.toStringAsFixed(1)),
                _chip(Icons.account_balance_wallet_outlined,
                    formatCurrency(d.balance),
                    color:
                        d.balance < 0 ? AppColors.error : AppColors.success),
                if (d.warningCount > 0)
                  _chip(Icons.warning_amber_rounded,
                      tr('${d.warningCount} إنذار', '${d.warningCount} warnings'),
                      color: AppColors.error),
              ]),
            ]),
          ),
          if (d.phone.isNotEmpty)
            IconButton(
              tooltip: tr('اتصال', 'Call'),
              icon: const Icon(Icons.call_outlined, color: AppColors.success),
              onPressed: () => callPhone(context, d.phone),
            ),
          PopupMenuButton<String>(
            tooltip: tr('إجراءات', 'Actions'),
            onSelected: (v) {
              switch (v) {
                case 'toggle':
                  _toggleActive(context);
                case 'release':
                  _release(context);
              }
            },
            // التشغيل فقط — التسوية والدفتر في تبويب «المال» حصراً
            // (ملاحظة المالك 2026-08-22: تكرارهما في تبويبين يشوّش).
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'toggle',
                  child: Text(d.isActive
                      ? tr('حظر مؤقت', 'Suspend')
                      : tr('إعادة تفعيل', 'Reactivate'))),
              PopupMenuItem(
                  value: 'release',
                  child: Text(tr('فصل عن أسطولي', 'Remove from fleet'),
                      style: const TextStyle(color: AppColors.error))),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label, {Color? color}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppColors.textGray),
          const SizedBox(width: 3),
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: color ?? AppColors.textDark)),
        ],
      );
}

/// دفتر حركات الكابتن — يُفتح من سطر الكابتن في تبويب «المال».
void showDriverLedgerSheet(BuildContext context, Driver driver) {
  final service = context.read<FirebaseService>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (ctx, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
              tr('دفتر ${driver.name}', '${driver.name}\'s ledger'),
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: AppStreamBuilder<List<DriverTransaction>>(
            stream: () => service.streamDriverTransactions(driver.id),
            builder: (ctx, txs) {
              if (txs.isEmpty) {
                return AppEmpty(
                    emoji: '📒',
                    title: tr('لا حركات بعد', 'No transactions yet'));
              }
              return ListView.builder(
                controller: scroll,
                itemCount: txs.length,
                itemBuilder: (_, i) {
                  final t = txs[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(t.type.icon,
                        size: 20,
                        color: t.amount >= 0
                            ? AppColors.success
                            : AppColors.error),
                    title: Text(t.type.label,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: (t.note ?? '').isEmpty
                        ? null
                        : Text(t.note!,
                            style: const TextStyle(fontSize: 11.5)),
                    trailing: Text(formatCurrency(t.amount),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: t.amount >= 0
                                ? AppColors.success
                                : AppColors.error)),
                  );
                },
              );
            },
          ),
        ),
      ]),
    ),
  );
}

/// حوار التسوية المالية — يُفتح من تبويب «المال» حصراً.
///
/// الاتجاهان صريحان بلا إشارات جبرية تُغلط: «استلمتُ نقداً من الكابتن»
/// يرفع رصيده (يسدّد دَينه)، و«دفعتُ للكابتن» ينقصه (صرف مستحقّه) —
/// نفس دلالة إشارة رصيد الكابتن في المنصّة (سالب = نقد بيده).
Future<void> showOperatorSettleDialog(
    BuildContext context, Driver driver) async {
  final service = context.read<FirebaseService>();
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  var received = true; // true = استلمت نقداً منه (+)، false = دفعت له (−)
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(tr('تسوية مع ${driver.name}', 'Settle with ${driver.name}')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              tr('رصيده الحالي: ${formatCurrency(driver.balance)}',
                  'Current balance: ${formatCurrency(driver.balance)}'),
              style:
                  const TextStyle(fontSize: 12.5, color: AppColors.textGray)),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                  value: true,
                  label: Text(tr('استلمتُ نقداً منه', 'Received cash'),
                      style: const TextStyle(fontSize: 11.5))),
              ButtonSegment(
                  value: false,
                  label: Text(tr('دفعتُ له', 'Paid captain'),
                      style: const TextStyle(fontSize: 11.5))),
            ],
            selected: {received},
            onSelectionChanged: (s) => setState(() => received = s.first),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: tr('المبلغ (ر.س)', 'Amount (SAR)'), isDense: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: noteCtrl,
            decoration: InputDecoration(
                labelText: tr('ملاحظة (اختياري)', 'Note (optional)'),
                isDense: true),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('إلغاء', 'Cancel'))),
          FilledButton(
            onPressed: () async {
              final raw = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (raw <= 0) {
                showError(ctx,
                    tr('أدخل مبلغاً أكبر من صفر', 'Enter an amount greater than zero'));
                return;
              }
              Navigator.pop(ctx);
              try {
                await service.operatorSettleDriver(
                  driverId: driver.id,
                  amount: received ? raw : -raw,
                  note: noteCtrl.text.trim(),
                );
                if (context.mounted) {
                  showSuccess(
                      context, tr('سُجّلت التسوية', 'Settlement recorded'));
                }
              } catch (_) {
                if (context.mounted) {
                  showError(context,
                      tr('تعذّرت التسوية — حاول مجدداً', 'Settlement failed — try again'));
                }
              }
            },
            child: Text(tr('تسجيل', 'Record')),
          ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// تبويب «الخريطة»: كباتنه أحياءً على الخريطة + طلباتهم الجارية.
// ═══════════════════════════════════════════════════════════════════════

class _FleetMapTab extends StatelessWidget {
  final List<Driver> drivers;
  final List<Order> orders;
  const _FleetMapTab({required this.drivers, required this.orders});

  @override
  Widget build(BuildContext context) {
    final located =
        drivers.where((d) => d.lat != null && d.lng != null).toList();
    final active = orders.where((o) => o.status.isActive).toList();

    if (located.isEmpty) {
      return AppEmpty(
          emoji: '🗺️',
          title: tr('لا مواقع بعد', 'No locations yet'),
          subtitle: tr(
              'تظهر مواقع كباتنك هنا حين يتصلون ويشاركون مواقعهم.',
              'Your captains appear here once they go online and share their location.'));
    }

    final center = LatLng(
      located.map((d) => d.lat!).reduce((a, b) => a + b) / located.length,
      located.map((d) => d.lng!).reduce((a, b) => a + b) / located.length,
    );

    return Column(children: [
      Expanded(
        child: FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 12),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.zadam.delivery',
            ),
            MarkerLayer(
              markers: [
                for (final d in located)
                  Marker(
                    point: LatLng(d.lat!, d.lng!),
                    width: 46,
                    height: 46,
                    child: GestureDetector(
                      onTap: () => _showCaptainSheet(context, d, active),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: d.isOnline
                                ? AppColors.success
                                : AppColors.textGray,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.delivery_dining,
                              color: Colors.white, size: 20),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
            const OsmAttribution(),
          ],
        ),
      ),
      // شريط الطلبات الجارية أسفل الخريطة — فتحه ختمُ التبعية عند الإسناد.
      if (active.isNotEmpty)
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            itemCount: active.length,
            itemBuilder: (_, i) => _ActiveOrderCard(order: active[i]),
          ),
        ),
    ]);
  }

  void _showCaptainSheet(
      BuildContext context, Driver d, List<Order> active) {
    final his = active.where((o) => o.driverId == d.id).toList();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Icon(Icons.delivery_dining,
                  color:
                      d.isOnline ? AppColors.success : AppColors.textGray),
              const SizedBox(width: 8),
              Expanded(
                child: Text(d.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              if (d.phone.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => callPhone(ctx, d.phone),
                  icon: const Icon(Icons.call_outlined, size: 16),
                  label: Text(tr('اتصال', 'Call')),
                ),
            ]),
            const SizedBox(height: 10),
            if (his.isEmpty)
              Text(tr('لا طلب جارٍ بيده الآن', 'No active order right now'),
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textGray))
            else
              ...his.map((o) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(
                        tr('طلب #${o.orderNumber} — ${o.status.label}',
                            'Order #${o.orderNumber} — ${o.status.label}'),
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(o.restaurantName,
                        style: const TextStyle(fontSize: 11.5)),
                    trailing: o.customerPhone.isEmpty
                        ? null
                        : IconButton(
                            tooltip: tr('اتصال بالعميل', 'Call customer'),
                            icon: const Icon(Icons.support_agent_rounded,
                                color: AppColors.primary),
                            onPressed: () =>
                                callPhone(ctx, o.customerPhone),
                          ),
                  )),
          ]),
        ),
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final Order order;
  const _ActiveOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Card(
      margin: const EdgeInsets.only(left: 8, right: 0),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(10),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('#${o.orderNumber} — ${o.driverName ?? ''}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(o.status.label,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textGray)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: Text(o.restaurantName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5)),
                ),
                if (o.customerPhone.isNotEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: tr('اتصال بالعميل', 'Call customer'),
                    icon: const Icon(Icons.call_outlined,
                        size: 18, color: AppColors.success),
                    onPressed: () => callPhone(context, o.customerPhone),
                  ),
              ]),
            ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// تبويب «المال»: المستحقّ المتراكم + دفتر المشغّل + أرصدة كباتنه.
// ═══════════════════════════════════════════════════════════════════════

class _MoneyTab extends StatelessWidget {
  final String uid;
  final FleetOperator? fleetOp;
  final List<Driver> drivers;
  final List<Order> orders;
  const _MoneyTab(
      {required this.uid,
      required this.fleetOp,
      required this.drivers,
      required this.orders});

  @override
  Widget build(BuildContext context) {
    final delivered =
        orders.where((o) => o.status == OrderStatus.delivered).toList();
    final earned =
        delivered.fold<double>(0, (sum, o) => sum + o.operatorShare);
    final ledger = fleetOp?.balance ?? 0;
    final share = fleetOp?.driverSharePerDelivery ?? 0;

    return ListView(padding: const EdgeInsets.all(12), children: [
      Card(
        margin: EdgeInsets.zero,
        color: AppColors.primary.withOpacity(0.06),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('إجمالي مستحقّاتك المتراكمة', 'Your total accumulated earnings'),
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textGray)),
            const SizedBox(height: 2),
            Text(formatCurrency(earned),
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark)),
            if (ledger != 0)
              Text(
                  ledger > 0
                      ? tr('رصيد دفترك: ${formatCurrency(ledger)}',
                          'Ledger balance: ${formatCurrency(ledger)}')
                      : tr('صُرف لك: ${formatCurrency(-ledger)}',
                          'Paid out to you: ${formatCurrency(-ledger)}'),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textGray)),
            const Divider(height: 20),
            Row(children: [
              _stat(tr('كباتنك', 'Your captains'), '${drivers.length}'),
              const SizedBox(width: 20),
              _stat(
                  tr('حصّة الكابتن/توصيلة', 'Captain share per delivery'),
                  share > 0
                      ? formatCurrency(share)
                      : tr('يحدّدها المدير', 'Set by the admin')),
              const SizedBox(width: 20),
              _stat(tr('طلبات مسلَّمة', 'Delivered orders'),
                  '${delivered.length}'),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(tr('أرصدة كباتنك', 'Captain balances'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 6, right: 4, left: 4),
        child: Text(
            tr('سالبٌ = نقدٌ بيد الكابتن تحصّله منه، موجبٌ = مستحقٌّ له.',
                'Negative = cash the captain owes you, positive = owed to the captain.'),
            style:
                const TextStyle(fontSize: 11.5, color: AppColors.textGray)),
      ),
      if (drivers.isEmpty)
        AppEmpty(emoji: '📒', title: tr('لا كباتن بعد', 'No captains yet'))
      else
        ...drivers.map((d) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => showDriverLedgerSheet(context, d),
                title: Text(d.name,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: Text(
                    tr('${d.totalDeliveries} توصيلة — اضغط لدفتر الحركات',
                        '${d.totalDeliveries} deliveries — tap for the ledger'),
                    style: const TextStyle(fontSize: 11.5)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(formatCurrency(d.balance),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: d.balance < 0
                              ? AppColors.error
                              : AppColors.success)),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: tr('تسوية', 'Settle'),
                    icon: const Icon(Icons.handshake_outlined,
                        color: AppColors.primary),
                    onPressed: () => showOperatorSettleDialog(context, d),
                  ),
                ]),
              ),
            )),
      const SizedBox(height: 24),
    ]);
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textGray)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
