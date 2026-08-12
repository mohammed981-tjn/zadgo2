// lib/screens/admin/admin_incentives_screen.dart
//
// الحوافز: برنامج الإحالة وتحدي نهاية الأسبوع — إعداداً وصرفاً.
//
// كل مبلغ وكل شرط يُضبط من هنا لا من الكود: المالك يرفع مكافأة الإحالة في
// موسم يحتاج فيه سائقين، ويخفضها حين يكتفي، دون إصدار جديد للتطبيق.
//
// الصرف: يدويٌّ بضغطة، أو تلقائيٌّ حين يفعّله المدير. والتلقائي هنا يمسح
// المستحقّين ما دامت هذه الشاشة مفتوحة — التطبيق بلا Cloud Functions بعد،
// وقواعد الأمان تمنع السائق من سكّ حركة «مكافأة» لنفسه (وهو الصواب)، فلا
// جهة أخرى تستطيع الكتابة نيابةً. الأتمتة الكاملة على الخادم مع ترقية
// Blaze (المسار د).
//
// الصرف المزدوج ممتنع في الحالتين بختمٍ على مستند السائق لا بانتباه
// المدير: referralRewarded للإحالة، وlastChallengeWindow للتحدي.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/app_version.dart';
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

class _Body extends StatefulWidget {
  final IncentiveSettings settings;
  final List<Driver> drivers;
  final List<Order> orders;

  const _Body({
    required this.settings,
    required this.drivers,
    required this.orders,
  });

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// قفل التزامن: البثّ يعيد البناء عدة مرات قبل أن تصل نتيجة الصرف، فبلا
  /// القفل ينطلق المسح مرات متوازية على نفس المستحقّ. الختم في القاعدة
  /// يمنع الصرف المزدوج فعلياً، والقفل يمنع الضجيج ومحاولات فاشلة.
  bool _sweeping = false;

  @override
  Widget build(BuildContext context) {
    final delivered = widget.orders
        .where((o) => o.status == OrderStatus.delivered)
        .toList();

    if (widget.settings.autoPay && !_sweeping) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sweep(delivered));
    }

    return ListView(padding: const EdgeInsets.all(12), children: [
      _SettingsCard(settings: widget.settings),
      const SizedBox(height: 14),
      const _MinVersionCard(),
      const SizedBox(height: 14),
      _ReferralsSection(
          settings: widget.settings,
          drivers: widget.drivers,
          delivered: delivered),
      const SizedBox(height: 14),
      _ChallengeSection(
          settings: widget.settings,
          drivers: widget.drivers,
          delivered: delivered),
      const SizedBox(height: 24),
    ]);
  }

  /// المسح التلقائي: يصرف لكل مستحقّ لم يُختم بعد. يعمل ما دامت هذه
  /// الشاشة مفتوحة — وهو أقصى ما يمكن بلا خادم؛ الأتمتة الكاملة مع Blaze.
  Future<void> _sweep(List<Order> delivered) async {
    if (!mounted || _sweeping) return;
    _sweeping = true;
    final service = context.read<FirebaseService>();
    final s = widget.settings;
    var paid = 0;

    // ‏try لكل مستحقّ على حدة — نسخة سابقة لفّت الحلقتين بـtry واحدة
    // فكان فشل صرفٍ واحد يُسقط بقية المستحقّين بصمت والتعليق يدّعي
    // العكس. «صُرفت مسبقاً» من الحارس الذرّي تُعدّ تخطياً طبيعياً
    // (سبقنا جهاز آخر إليها) لا فشلاً.
    try {
      if (s.referralEnabled) {
        for (final r in eligibleReferrals(s, widget.drivers, delivered)) {
          try {
            await service.payReferralBonus(
              referrer: r.referrer,
              referee: r.referee,
              referrerAmount: s.referrerBonus,
              refereeAmount: s.refereeBonus,
            );
            paid++;
          } catch (_) {
            // يبقى المستحقّ ظاهراً للصرف اليدوي؛ ونكمل على بقية القائمة.
          }
        }
      }
      final window = s.currentWindow(DateTime.now());
      if (s.challengeEnabled && window != null) {
        final key = IncentiveSettings.windowKey(window.$1);
        for (final a
            in challengeAchievers(s, widget.drivers, delivered, window)) {
          if (a.driver.lastChallengeWindow == key) continue;
          try {
            await service.payChallengeBonus(
              driverId: a.driver.id,
              amount: a.tier.bonus,
              deliveries: a.count,
              windowStart: window.$1,
            );
            paid++;
          } catch (_) {
            // نفس المبدأ: التالي في القائمة لا يدفع ثمن فشل سابقه.
          }
        }
      }
      if (paid > 0 && mounted) {
        showSuccess(context, 'صُرفت $paid مكافأة تلقائياً');
      }
    } finally {
      _sweeping = false;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// حساب المستحقّين — دوال مشتركة بين العرض والمسح التلقائي، فلا يختلف ما
// يراه المدير عمّا يُصرف آلياً.
// ═══════════════════════════════════════════════════════════════════════

List<_ReferralRow> referralRows(
    IncentiveSettings s, List<Driver> drivers, List<Order> delivered) {
  final byCode = {for (final d in drivers) d.referralCode: d};
  final now = DateTime.now();
  final rows = <_ReferralRow>[];

  for (final referee in drivers
      .where((d) => d.referredByCode.isNotEmpty && !d.referralRewarded)) {
    final referrer = byCode[referee.referredByCode];
    // كود لا يطابق أي سائق (خطأ إدخال) أو سائق يدّعي دعوة نفسه.
    if (referrer == null || referrer.id == referee.id) continue;

    final joined = referee.createdAt;
    final deadline = joined?.add(Duration(days: s.referralWindowDays));
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
  return rows;
}

List<_ReferralRow> eligibleReferrals(
        IncentiveSettings s, List<Driver> drivers, List<Order> delivered) =>
    referralRows(s, drivers, delivered)
        .where((r) => !r.expired && r.count >= s.referralDeliveries)
        .toList();

List<({Driver driver, int count, ChallengeTier tier})> challengeAchievers(
  IncentiveSettings s,
  List<Driver> drivers,
  List<Order> delivered,
  (DateTime, DateTime) window,
) {
  final (start, end) = window;
  final counts = <String, int>{};
  for (final o in delivered) {
    final id = o.driverId;
    if (id == null) continue;
    if (o.createdAt.isBefore(start) || o.createdAt.isAfter(end)) continue;
    counts[id] = (counts[id] ?? 0) + 1;
  }
  final out = <({Driver driver, int count, ChallengeTier tier})>[];
  for (final d in drivers) {
    final c = counts[d.id] ?? 0;
    final t = s.tierFor(c);
    if (t != null) out.add((driver: d, count: c, tier: t));
  }
  out.sort((a, b) => b.count.compareTo(a.count));
  return out;
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
          _row('رابط الدعوة', s.joinUrl),
          const Divider(height: 18),
          _row('تحدي نهاية الأسبوع',
              s.challengeEnabled ? 'مفعّل — ${s.weekdaysLabel}' : 'موقوف',
              highlight: !s.challengeEnabled),
          ...s.tiers.map((t) => _row('  ${t.deliveries} توصيلة',
              formatCurrency(t.bonus))),
          const Divider(height: 18),
          _row('الصرف التلقائي',
              s.autoPay ? 'مفعّل — يصرف فور تحقّق الشرط' : 'يدوي بضغطة'),
          if (s.autoPay)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                  'يعمل ما دامت هذه الشاشة مفتوحة — الأتمتة على الخادم مع ترقية Blaze',
                  style: TextStyle(fontSize: 11, color: AppColors.textGray)),
            ),
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
      _windowDays, _cap, _joinUrl, _maxLoad, _stackKm, _compPct;
  late bool _autoPay;
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
    _joinUrl = TextEditingController(text: s.joinUrl);
    _maxLoad = TextEditingController(text: '${s.maxOrdersPerDriver}');
    _stackKm = TextEditingController(text: s.stackRadiusKm.toStringAsFixed(1));
    _compPct = TextEditingController(
        text: s.restaurantCancelCompensationPercent.toStringAsFixed(0));
    _autoPay = s.autoPay;
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
    for (final c in [
      _referrer, _referee, _deliveries, _windowDays, _cap, _joinUrl,
      _maxLoad, _stackKm, _compPct,
    ]) {
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
              autoPay: _autoPay,
              joinUrl: _joinUrl.text.trim(),
              // السقف لا يقلّ عن ١ وإلا توقف الإسناد كلياً، والنطاق لا
              // يقلّ عن صفر — حارسٌ يمنع رقماً يشلّ التشغيل بغلطة إدخال.
              maxOrdersPerDriver:
                  (int.tryParse(_maxLoad.text.trim()) ?? 3).clamp(1, 10),
              stackRadiusKm:
                  (double.tryParse(_stackKm.text.trim()) ?? 2.0).clamp(0.0, 50.0),
              restaurantCancelCompensationPercent:
                  (double.tryParse(_compPct.text.trim()) ?? 100)
                      .clamp(0.0, 100.0),
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
          const SizedBox(height: 10),
          TextField(
            controller: _joinUrl,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رابط صفحة التسجيل',
              helperText: 'يُلحَق به ?ref=كود الداعي — صفحة رفع المستندات',
              helperMaxLines: 2,
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),

          const Divider(height: 26),
          // سقف الإسناد المتزامن — ليس حافزاً، لكنه يسكن هنا لأن هذا
          // المستند وحده يقرؤه تطبيقا المطعم والكابتن (القواعد تقصر
          // `delivery_settings/config` على المدير).
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text('الطلبات المتزامنة للكابتن',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _num(_maxLoad, 'أقصى طلبات معاً')),
            const SizedBox(width: 10),
            Expanded(child: _num(_stackKm, 'تقارب المطاعم (كم)')),
          ]),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
                'الكابتن لا يحمل أكثر من العدد أعلاه، ولا يُضمّ إليه طلب '
                'إلا إذا كان مطعمه ضمن مسافة التقارب من مطعم أول طلب بيده.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textGray)),
          ),

          const Divider(height: 26),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text('تعويض المطعم عند الإلغاء',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          _num(_compPct, 'نسبة التعويض بعد بدء التحضير (٪)'),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
                'طلبٌ أُلغي بعد «جاري التحضير» يُقيَّد للمطعم بهذه النسبة من '
                'قيمة وجباته وبلا عمولة. ١٠٠٪ هو المعيار العالمي، وصفر يعني '
                'لا تعويض. الإلغاء قبل التحضير لا يُعوَّض أصلاً.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textGray)),
          ),

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

          const Divider(height: 26),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _autoPay,
            onChanged: (v) => setState(() => _autoPay = v),
            title: const Text('الصرف التلقائي',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            subtitle: const Text(
                'تُصرف المكافأة فور تحقّق الشرط بلا ضغطة — ما دامت شاشة '
                'الحوافز مفتوحة (الأتمتة على الخادم تنتظر ترقية Blaze)',
                style: TextStyle(fontSize: 11.5)),
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
    final rows = referralRows(settings, drivers, delivered);
    final eligible = eligibleReferrals(settings, drivers, delivered);
    final inProgress = rows.where((r) => !eligible.contains(r)).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.group_add_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('الإحالات (${eligible.length} مستحقّة)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            // الصرف الجماعي: مستحقّون كثر يعني ضغطات كثيرة، وكلٌّ منها
            // نافذة تأكيد. زرٌّ واحد بتأكيد واحد يذكر العدد والمبلغ.
            if (eligible.length > 1)
              TextButton(
                onPressed: () async {
                  final total = eligible.length *
                      (settings.referrerBonus + settings.refereeBonus);
                  final ok = await showConfirmDialog(context,
                      title: 'صرف كل المستحقّين',
                      content: '${eligible.length} إحالة — إجمالي '
                          '${formatCurrency(total)} تُوزَّع على الطرفين.',
                      confirmLabel: 'صرف الكل');
                  if (ok != true) return;
                  var done = 0;
                  for (final r in eligible) {
                    try {
                      await service.payReferralBonus(
                        referrer: r.referrer,
                        referee: r.referee,
                        referrerAmount: settings.referrerBonus,
                        refereeAmount: settings.refereeBonus,
                      );
                      done++;
                    } catch (_) {
                      // يُترك للصرف اليدوي؛ لا يُوقف البقية.
                    }
                  }
                  if (context.mounted) {
                    showSuccess(context, 'صُرفت $done من ${eligible.length}');
                  }
                },
                child: const Text('صرف الكل', style: TextStyle(fontSize: 12.5)),
              ),
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
    final key = IncentiveSettings.windowKey(start);
    final achieved = challengeAchievers(settings, drivers, delivered, window);
    final unpaid =
        achieved.where((e) => e.driver.lastChallengeWindow != key).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.emoji_events_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('تحدي نهاية الأسبوع',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            if (unpaid.length > 1)
              TextButton(
                onPressed: () async {
                  final total =
                      unpaid.fold<double>(0, (s, e) => s + e.tier.bonus);
                  final ok = await showConfirmDialog(context,
                      title: 'صرف كل المستحقّين',
                      content: '${unpaid.length} كابتن — إجمالي '
                          '${formatCurrency(total)}.',
                      confirmLabel: 'صرف الكل');
                  if (ok != true) return;
                  var done = 0;
                  for (final e in unpaid) {
                    try {
                      await service.payChallengeBonus(
                        driverId: e.driver.id,
                        amount: e.tier.bonus,
                        deliveries: e.count,
                        windowStart: start,
                      );
                      done++;
                    } catch (_) {
                      // مصروفة مسبقاً أو فشل شبكة — تبقى ظاهرة.
                    }
                  }
                  if (context.mounted) {
                    showSuccess(context, 'صُرفت $done من ${unpaid.length}');
                  }
                },
                child: const Text('صرف الكل', style: TextStyle(fontSize: 12.5)),
              ),
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
            final done = e.driver.lastChallengeWindow == key;
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
                            '${e.tier.deliveries}',
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.textGray)),
                      ]),
                ),
                if (done)
                  const StatusChip(label: 'صُرفت', color: AppColors.success)
                else
                  TextButton(
                    onPressed: () async {
                      final ok = await showConfirmDialog(context,
                          title: 'صرف مكافأة التحدي',
                          content:
                              'تُضاف ${formatCurrency(e.tier.bonus)} لدفتر '
                              '${e.driver.name} عن ${e.count} توصيلة في هذه '
                              'النافذة.',
                          confirmLabel: 'صرف');
                      if (ok != true) return;
                      try {
                        await service.payChallengeBonus(
                          driverId: e.driver.id,
                          amount: e.tier.bonus,
                          deliveries: e.count,
                          windowStart: start,
                        );
                        if (context.mounted) {
                          showSuccess(context, 'صُرفت المكافأة');
                        }
                      } catch (err) {
                        if (context.mounted) {
                          showError(
                              context,
                              err
                                  .toString()
                                  .replaceFirst('Exception: ', ''));
                        }
                      }
                    },
                    child: Text('صرف ${formatCurrency(e.tier.bonus)}',
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

/// ضابط الحدّ الأدنى لإصدار التطبيق.
///
/// موضعه هنا لا في شاشة مستقلة: المالك يفتح «الحوافز والإحالات» بعد كل
/// إصدار ليضبط أرقامه، فيراه في طريقه. وهو الحقل الوحيد في
/// `delivery_settings/app`.
///
/// ⚠️ رقم أعلى من كل النسخ المثبَّتة يحجب **الجميع بما فيهم أنت** —
/// والإصلاح حينها من كونسول Firestore لا من التطبيق. لذا يُعرض تحذير
/// صريح قبل الحفظ لا بعده.
class _MinVersionCard extends StatefulWidget {
  const _MinVersionCard();

  @override
  State<_MinVersionCard> createState() => _MinVersionCardState();
}

class _MinVersionCardState extends State<_MinVersionCard> {
  final _ctrl = TextEditingController();
  bool _loaded = false, _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return StreamBuilder<String>(
      stream: service.streamMinAppVersion(),
      builder: (context, snap) {
        // يُملأ الحقل مرة واحدة: إعادة ملئه مع كل تحديث للبثّ تمسح ما
        // يكتبه المدير تحت أصابعه.
        if (!_loaded && snap.hasData) {
          _ctrl.text = snap.data!;
          _loaded = true;
        }
        final active = (snap.data ?? '').isNotEmpty;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.system_update_alt_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('أدنى إصدار مسموح',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    Text('نسخة هذا الجهاز $kAppVersion',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textGray)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                      active
                          ? 'النسخ الأقدم من ${snap.data} محجوبة الآن'
                          : 'لا حجب — كل النسخ تعمل',
                      style: TextStyle(
                          fontSize: 12,
                          color: active
                              ? AppColors.warning
                              : AppColors.textGray)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'مثال 4.0.0 — واتركه فارغاً لإلغاء الحجب',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _saving ? null : () => _save(service),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 46)),
                      child: const Text('حفظ'),
                    ),
                  ]),
                ]),
          ),
        );
      },
    );
  }

  Future<void> _save(FirebaseService service) async {
    final value = _ctrl.text.trim();
    // الحجب الذي يشمل جهاز المدير نفسه خطأ يصعب التراجع عنه من التطبيق،
    // فيُستأذن فيه صراحةً بذكر أثره.
    if (value.isNotEmpty && isVersionBelow(kAppVersion, value)) {
      final ok = await showConfirmDialog(context,
          title: 'تحذير — سيحجبك أنت أيضاً',
          content: 'نسخة جهازك $kAppVersion أقدم من $value، فستُحجب هذه '
              'الشاشة نفسها بعد الحفظ ولن تستطيع التراجع إلا من كونسول '
              'Firestore. تابع؟',
          confirmLabel: 'أفهم — احفظ',
          confirmColor: AppColors.error);
      if (ok != true) return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await service.setMinAppVersion(value);
      if (mounted) {
        showSuccess(context,
            value.isEmpty ? 'أُلغي الحجب' : 'أدنى إصدار مسموح: $value');
      }
    } catch (_) {
      if (mounted) showError(context, 'تعذّر الحفظ');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
