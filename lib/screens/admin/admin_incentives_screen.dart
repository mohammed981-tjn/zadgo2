// lib/screens/admin/admin_incentives_screen.dart
//
// الحوافز: برنامج الإحالة وتحدي نهاية الأسبوع — إعداداً وصرفاً.
//
// كل مبلغ وكل شرط يُضبط من هنا لا من الكود: المالك يرفع مكافأة الإحالة في
// موسم يحتاج فيه سائقين، ويخفضها حين يكتفي، دون إصدار جديد للتطبيق.
//
// الصرف بضغطة المدير لا آلياً: التطبيق بلا Cloud Functions بعد، وقواعد
// الأمان تمنع السائق من سكّ حركة «مكافأة» لنفسه (وهو الصواب). فالشاشة
// تحسب المستحقّين وتعرضهم جاهزين، والمدير يصرف بضغطة — أثرٌ موثّق بيد
// بشرية بدل أتمتة تكتب في دفتر مالي بلا رقيب.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class AdminIncentivesScreen extends StatelessWidget {
  const AdminIncentivesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<IncentiveSettings>(
      stream: service.streamIncentiveSettings,
      builder: (ctx, settings) => AppStreamBuilder<List<Driver>>(
        stream: service.streamDrivers,
        builder: (ctx2, drivers) => AppStreamBuilder<List<Order>>(
          stream: service.streamAllOrders,
          builder: (ctx3, orders) => _Body(
            settings: settings,
            drivers: drivers,
            orders: orders,
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final IncentiveSettings settings;
  final List<Driver> drivers;
  final List<Order> orders;

  const _Body({
    required this.settings,
    required this.drivers,
    required this.orders,
  });

  @override
  Widget build(BuildContext context) {
    final delivered =
        orders.where((o) => o.status == OrderStatus.delivered).toList();

    return ListView(padding: const EdgeInsets.all(12), children: [
      _SettingsCard(settings: settings),
      const SizedBox(height: 14),
      _ReferralsSection(
          settings: settings, drivers: drivers, delivered: delivered),
      const SizedBox(height: 14),
      _ChallengeSection(
          settings: settings, drivers: drivers, delivered: delivered),
      const SizedBox(height: 24),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// الإعدادات
// ═══════════════════════════════════════════════════════════════════════

class _SettingsCard extends StatelessWidget {
  final IncentiveSettings settings;
  const _SettingsCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    final s = settings;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text('إعدادات الحوافز',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => _SettingsForm(initial: s),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('تعديل', style: TextStyle(fontSize: 12.5)),
            ),
          ]),
          const Divider(height: 18),
          _row('برنامج الإحالة', s.referralEnabled ? 'مفعّل' : 'موقوف',
              highlight: !s.referralEnabled),
          _row('مكافأة الداعي', formatCurrency(s.referrerBonus)),
          _row('مكافأة المدعوّ', formatCurrency(s.refereeBonus)),
          _row('الشرط',
              '${s.referralDeliveries} توصيلة خلال ${s.referralWindowDays} يوماً'),
          _row('سقف الداعي شهرياً', '${s.referralMonthlyCap} إحالات'),
          const Divider(height: 18),
          _row('تحدي نهاية الأسبوع',
              s.challengeEnabled ? 'مفعّل — ${s.weekdaysLabel}' : 'موقوف',
              highlight: !s.challengeEnabled),
          ...s.tiers.map((t) => _row('  ${t.deliveries} توصيلة',
              formatCurrency(t.bonus))),
        ]),
      ),
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textGray))),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: highlight ? AppColors.error : AppColors.textDark)),
        ]),
      );
}

class _SettingsForm extends StatefulWidget {
  final IncentiveSettings initial;
  const _SettingsForm({required this.initial});

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  late bool _referralOn, _challengeOn;
  late final TextEditingController _referrer, _referee, _deliveries,
      _windowDays, _cap;
  late List<int> _days;
  late List<({TextEditingController d, TextEditingController b})> _tiers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _referralOn = s.referralEnabled;
    _challengeOn = s.challengeEnabled;
    _referrer = TextEditingController(text: s.referrerBonus.toStringAsFixed(0));
    _referee = TextEditingController(text: s.refereeBonus.toStringAsFixed(0));
    _deliveries = TextEditingController(text: '${s.referralDeliveries}');
    _windowDays = TextEditingController(text: '${s.referralWindowDays}');
    _cap = TextEditingController(text: '${s.referralMonthlyCap}');
    _days = [...s.challengeWeekdays];
    _tiers = s.tiers
        .map((t) => (
              d: TextEditingController(text: '${t.deliveries}'),
              b: TextEditingController(text: t.bonus.toStringAsFixed(0)),
            ))
        .toList();
  }

  @override
  void dispose() {
    for (final c in [_referrer, _referee, _deliveries, _windowDays, _cap]) {
      c.dispose();
    }
    for (final t in _tiers) {
      t.d.dispose();
      t.b.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final tiers = <ChallengeTier>[];
    for (final t in _tiers) {
      final d = int.tryParse(t.d.text.trim()) ?? 0;
      final b = double.tryParse(t.b.text.trim()) ?? 0;
      if (d > 0 && b > 0) tiers.add(ChallengeTier(deliveries: d, bonus: b));
    }
    tiers.sort((a, b) => a.deliveries.compareTo(b.deliveries));

    if (_challengeOn && tiers.isEmpty) {
      showError(context, 'أضف مستوى واحداً على الأقل للتحدي أو أوقفه');
      return;
    }
    if (_challengeOn && _days.isEmpty) {
      showError(context, 'اختر يوماً واحداً على الأقل للتحدي');
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<FirebaseService>().saveIncentiveSettings(
            widget.initial.copyWith(
              referralEnabled: _referralOn,
              referrerBonus: double.tryParse(_referrer.text.trim()) ?? 0,
              refereeBonus: double.tryParse(_referee.text.trim()) ?? 0,
              referralDeliveries: int.tryParse(_deliveries.text.trim()) ?? 1,
              referralWindowDays: int.tryParse(_windowDays.text.trim()) ?? 30,
              referralMonthlyCap: int.tryParse(_cap.text.trim()) ?? 3,
              challengeEnabled: _challengeOn,
              challengeWeekdays: _days,
              tiers: tiers,
            ),
          );
      if (mounted) {
        showSuccess(context, 'حُفظت الإعدادات');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showError(context, 'تعذّر الحفظ');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const names = {
      DateTime.saturday: 'السبت',
      DateTime.sunday: 'الأحد',
      DateTime.monday: 'الاثنين',
      DateTime.tuesday: 'الثلاثاء',
      DateTime.wednesday: 'الأربعاء',
      DateTime.thursday: 'الخميس',
      DateTime.friday: 'الجمعة',
    };

    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('إعدادات الحوافز',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _referralOn,
            onChanged: (v) => setState(() => _referralOn = v),
            title: const Text('برنامج الإحالة',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          Row(children: [
            Expanded(child: _num(_referrer, 'مكافأة الداعي (ر.س)')),
            const SizedBox(width: 10),
            Expanded(child: _num(_referee, 'مكافأة المدعوّ (ر.س)')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _num(_deliveries, 'التوصيلات المطلوبة')),
            const SizedBox(width: 10),
            Expanded(child: _num(_windowDays, 'خلال (يوم)')),
          ]),
          const SizedBox(height: 10),
          _num(_cap, 'سقف إحالات الداعي شهرياً'),

          const Divider(height: 26),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _challengeOn,
            onChanged: (v) => setState(() => _challengeOn = v),
            title: const Text('تحدي نهاية الأسبوع',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text('أيام التحدي',
                style: TextStyle(
                    fontSize: 12.5, color: AppColors.textGray)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: names.entries.map((e) {
              final on = _days.contains(e.key);
              return FilterChip(
                label: Text(e.value, style: const TextStyle(fontSize: 12)),
                selected: on,
                onSelected: (v) => setState(() {
                  if (v) {
                    _days.add(e.key);
                  } else {
                    _days.remove(e.key);
                  }
                  _days.sort();
                }),
                labelStyle: TextStyle(
                    color: on ? Colors.white : AppColors.textDark,
                    fontSize: 12),
                selectedColor: AppColors.primary,
                checkmarkColor: Colors.white,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text('المستويات — يُصرف أعلى مستوى بلغه السائق',
                style: TextStyle(fontSize: 12.5, color: AppColors.textGray)),
          ),
          const SizedBox(height: 6),
          ..._tiers.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(child: _num(e.value.d, 'توصيلات')),
                  const SizedBox(width: 10),
                  Expanded(child: _num(e.value.b, 'مكافأة (ر.س)')),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        size: 20, color: AppColors.error),
                    onPressed: () => setState(() {
                      _tiers[e.key].d.dispose();
                      _tiers[e.key].b.dispose();
                      _tiers.removeAt(e.key);
                    }),
                  ),
                ]),
              )),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _tiers.add((
                    d: TextEditingController(),
                    b: TextEditingController(),
                  ))),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('إضافة مستوى', style: TextStyle(fontSize: 12.5)),
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _num(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
            labelText: label, isDense: true, border: const OutlineInputBorder()),
      );
}

// ═══════════════════════════════════════════════════════════════════════
// الإحالات
// ═══════════════════════════════════════════════════════════════════════

class _ReferralsSection extends StatelessWidget {
  final IncentiveSettings settings;
  final List<Driver> drivers;
  final List<Order> delivered;

  const _ReferralsSection({
    required this.settings,
    required this.drivers,
    required this.delivered,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final byCode = {for (final d in drivers) d.referralCode: d};
    final now = DateTime.now();

    // كل سائق أدخل كود داعٍ ولم تُصرف إحالته بعد.
    final pending = drivers
        .where((d) => d.referredByCode.isNotEmpty && !d.referralRewarded)
        .toList();

    final rows = <_ReferralRow>[];
    for (final referee in pending) {
      final referrer = byCode[referee.referredByCode];
      // كود لا يطابق أي سائق (خطأ إدخال) أو سائق يدّعي دعوة نفسه.
      if (referrer == null || referrer.id == referee.id) continue;

      final joined = referee.createdAt;
      final deadline =
          joined?.add(Duration(days: settings.referralWindowDays));
      final count = delivered
          .where((o) =>
              o.driverId == referee.id &&
              (joined == null || !o.createdAt.isBefore(joined)) &&
              (deadline == null || !o.createdAt.isAfter(deadline)))
          .length;

      rows.add(_ReferralRow(
        referrer: referrer,
        referee: referee,
        count: count,
        expired: deadline != null && now.isAfter(deadline),
      ));
    }
    rows.sort((a, b) => b.count.compareTo(a.count));

    final eligible = rows
        .where((r) => !r.expired && r.count >= settings.referralDeliveries)
        .toList();
    final inProgress = rows.where((r) => !eligible.contains(r)).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.group_add_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text('الإحالات (${eligible.length} مستحقّة)',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          if (rows.isEmpty) ...[
            const SizedBox(height: 10),
            const Text('لا إحالات بعد — يشارك الكابتن كوده من تطبيقه',
                style: TextStyle(fontSize: 12.5, color: AppColors.textGray)),
          ],
          ...eligible.map((r) => _tile(context, service, r, ready: true)),
          ...inProgress.map((r) => _tile(context, service, r, ready: false)),
        ]),
      ),
    );
  }

  Widget _tile(BuildContext context, FirebaseService service, _ReferralRow r,
      {required bool ready}) {
    final target = settings.referralDeliveries;
    final progress = (r.count / target).clamp(0.0, 1.0);
    // سقف الداعي الشهري تنبيهٌ للمدير لا منعٌ آلي: قد يريد تجاوزه لسببٍ
    // يعرفه، والقرار المالي يبقى بيده.
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${r.referrer.name}  ←  ${r.referee.name}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          if (r.expired)
            const StatusChip(label: 'انقضت المهلة', color: AppColors.textGray)
          else if (ready)
            const StatusChip(label: 'مستحقّة', color: AppColors.success)
          else
            StatusChip(label: '${r.count}/$target', color: AppColors.warning),
        ]),
        const SizedBox(height: 4),
        if (!r.expired)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              color: ready ? AppColors.success : AppColors.primary,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          r.expired
              ? 'أنجز ${r.count} من $target قبل انقضاء المهلة — لا تُصرف'
              : 'أنجز ${r.count} من $target توصيلة',
          style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
        ),
        if (ready)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: Text(
                  'صرف ${formatCurrency(settings.referrerBonus)} للداعي '
                  'و${formatCurrency(settings.refereeBonus)} للمدعوّ',
                  style: const TextStyle(fontSize: 12)),
              onPressed: () async {
                final ok = await showConfirmDialog(context,
                    title: 'صرف مكافأة الإحالة',
                    content:
                        'تُضاف ${formatCurrency(settings.referrerBonus)} لدفتر '
                        '${r.referrer.name} و${formatCurrency(settings.refereeBonus)} '
                        'لدفتر ${r.referee.name}.',
                    confirmLabel: 'صرف');
                if (ok != true) return;
                try {
                  await service.payReferralBonus(
                    referrer: r.referrer,
                    referee: r.referee,
                    referrerAmount: settings.referrerBonus,
                    refereeAmount: settings.refereeBonus,
                  );
                  if (context.mounted) showSuccess(context, 'صُرفت المكافأة');
                } catch (_) {
                  if (context.mounted) showError(context, 'تعذّر الصرف');
                }
              },
            ),
          ),
      ]),
    );
  }
}

class _ReferralRow {
  final Driver referrer;
  final Driver referee;
  final int count;
  final bool expired;
  const _ReferralRow({
    required this.referrer,
    required this.referee,
    required this.count,
    required this.expired,
  });
}

// ═══════════════════════════════════════════════════════════════════════
// تحدي نهاية الأسبوع
// ═══════════════════════════════════════════════════════════════════════

class _ChallengeSection extends StatelessWidget {
  final IncentiveSettings settings;
  final List<Driver> drivers;
  final List<Order> delivered;

  const _ChallengeSection({
    required this.settings,
    required this.drivers,
    required this.delivered,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final now = DateTime.now();
    final window = settings.currentWindow(now);

    if (!settings.challengeEnabled) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('تحدي نهاية الأسبوع موقوف',
              style: TextStyle(fontSize: 13, color: AppColors.textGray)),
        ),
      );
    }

    if (window == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.emoji_events_outlined,
                color: AppColors.textGray, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  'التحدي يعمل ${settings.weekdaysLabel} — لا نافذة جارية الآن',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textGray)),
            ),
          ]),
        ),
      );
    }

    final (start, end) = window;
    final counts = <String, int>{};
    for (final o in delivered) {
      if (o.driverId == null) continue;
      if (o.createdAt.isBefore(start) || o.createdAt.isAfter(end)) continue;
      counts[o.driverId!] = (counts[o.driverId!] ?? 0) + 1;
    }

    final achieved = drivers
        .map((d) => (driver: d, count: counts[d.id] ?? 0))
        .where((e) => settings.tierFor(e.count) != null)
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.emoji_events_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text('تحدي نهاية الأسبوع',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 4),
          Text(
              'النافذة الجارية: ${start.day}/${start.month} — '
              '${end.day}/${end.month}',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textGray)),
          if (achieved.isEmpty) ...[
            const SizedBox(height: 10),
            const Text('لم يبلغ أحد أدنى مستوى بعد',
                style: TextStyle(fontSize: 12.5, color: AppColors.textGray)),
          ],
          ...achieved.map((e) {
            final tier = settings.tierFor(e.count)!;
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.driver.name,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        Text('${e.count} توصيلة • بلغ مستوى '
                            '${tier.deliveries}',
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.textGray)),
                      ]),
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await showConfirmDialog(context,
                        title: 'صرف مكافأة التحدي',
                        content:
                            'تُضاف ${formatCurrency(tier.bonus)} لدفتر '
                            '${e.driver.name} عن ${e.count} توصيلة في هذه '
                            'النافذة. راجع دفتره أولاً حتى لا تُصرف مرتين.',
                        confirmLabel: 'صرف');
                    if (ok != true) return;
                    try {
                      await service.payChallengeBonus(
                        driverId: e.driver.id,
                        amount: tier.bonus,
                        deliveries: e.count,
                        windowStart: start,
                      );
                      if (context.mounted) {
                        showSuccess(context, 'صُرفت المكافأة');
                      }
                    } catch (_) {
                      if (context.mounted) showError(context, 'تعذّر الصرف');
                    }
                  },
                  child: Text('صرف ${formatCurrency(tier.bonus)}',
                      style: const TextStyle(fontSize: 12.5)),
                ),
              ]),
            );
          }),
        ]),
      ),
    );
  }
}

/// بطاقة صغيرة تعرض كود إحالة سائق للمدير — ليرسله لمن يسأل عنه.
class DriverReferralCodeChip extends StatelessWidget {
  final Driver driver;
  const DriverReferralCodeChip({super.key, required this.driver});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: driver.referralCode));
          if (context.mounted) showSuccess(context, 'نُسخ كود الإحالة');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('كود الإحالة: ${driver.referralCode}',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ),
      );
}
