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
import '../../utils/app_lang.dart';
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
          // نافذة زمنية كاملة لا «أحدث ٥٠٠»: الإحالة تُحسب على توصيلات
          // المدعوّ خلال نافذتها والتحدي على توصيلات أيامه — والصرف
          // التلقائي يمسح هذه القائمة نفسها، فنافذةٌ مقصوصة عند ازدحام
          // الطلبات كانت ستُنقص عدّ الكابتن **فتبخس مكافأته** بصمت.
          // مدى التاريخ يضمن العدّ الكامل (نافذة الإحالة أطول النافذتين،
          // ويوم هامش للمناطق الزمنية وطلبٍ يكتمل بعد منتصف الليل).
          key: ValueKey(settings.referralWindowDays),
          stream: () => service.streamOrdersSince(DateTime.now().subtract(
              Duration(
                  days: (settings.referralWindowDays < 7
                          ? 7
                          : settings.referralWindowDays) +
                      1))),
          builder: (ctx3, orders) => AppStreamBuilder<List<AppUser>>(
            stream: service.streamUsers,
            builder: (ctx4, users) => _Body(
              settings: settings,
              drivers: drivers,
              orders: orders,
              customers:
                  users.where((u) => u.role == UserRole.customer).toList(),
            ),
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
  final List<AppUser> customers;

  const _Body({
    required this.settings,
    required this.drivers,
    required this.orders,
    required this.customers,
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
      const SizedBox(height: 14),
      _CustomerGrowthSection(
          settings: widget.settings,
          customers: widget.customers,
          delivered: delivered,
          onPaySweep: () => _sweep(delivered)),
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
      // إحالة العميل (دفعة ٥): نفس مبدأ إحالة السائق — ختمٌ ذرّي يمنع
      // الصرف المزدوج، وtry لكل مستحقّ.
      if (s.customerReferralEnabled &&
          (s.customerReferrerBonus > 0 || s.customerRefereeBonus > 0)) {
        for (final r
            in eligibleCustomerReferrals(s, widget.customers, delivered)) {
          try {
            await service.payCustomerReferralBonus(
              referrer: r.referrer,
              referee: r.referee,
              referrerAmount: s.customerReferrerBonus,
              refereeAmount: s.customerRefereeBonus,
            );
            paid++;
          } catch (_) {}
        }
      }

      // كاش باك (دفعة ٥): يُجلب فهرس المصروف مرّة، ثم يُصرف عن كل طلبٍ مسلَّم
      // لم يُصرف بعد. العلامة الذرّية تمنع التكرار حتى لو تخطّى الفهرسُ صرفاً
      // لتوّه.
      if (s.cashbackPercent > 0) {
        final paidIds = await service.fetchCashbackPaidOrderIds();
        for (final o in delivered) {
          if (paidIds.contains(o.id)) continue;
          var credit = o.itemsTotal * s.cashbackPercent / 100;
          if (s.cashbackMaxPerOrder > 0 && credit > s.cashbackMaxPerOrder) {
            credit = s.cashbackMaxPerOrder;
          }
          if (credit <= 0) continue;
          try {
            await service.accrueCashback(
              customerId: o.customerId,
              orderId: o.id,
              orderNumber: o.orderNumber,
              amount: double.parse(credit.toStringAsFixed(2)),
            );
            paid++;
          } catch (_) {}
        }
      }

      if (paid > 0 && mounted) {
        showSuccess(context,
            tr('صُرفت $paid مكافأة تلقائياً', '$paid rewards paid automatically'));
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

// ————— إحالة العميل (دفعة ٥) — نظير دوال السائق تماماً، لكن على العملاء
// وطلباتهم (customerId) بدل السائقين (driverId). قائمة واحدة للعرض والمسح
// فلا يختلف ما يراه المدير عمّا يُصرف آلياً.

class _CustomerReferralRow {
  final AppUser referrer;
  final AppUser referee;
  final int count;
  final bool expired;
  const _CustomerReferralRow(
      {required this.referrer,
      required this.referee,
      required this.count,
      required this.expired});
}

List<_CustomerReferralRow> customerReferralRows(
    IncentiveSettings s, List<AppUser> customers, List<Order> delivered) {
  final byCode = {for (final c in customers) c.referralCode: c};
  final now = DateTime.now();
  final rows = <_CustomerReferralRow>[];

  for (final referee in customers
      .where((c) => c.referredByCode.isNotEmpty && !c.referralRewarded)) {
    final referrer = byCode[referee.referredByCode];
    if (referrer == null || referrer.uid == referee.uid) continue;

    final joined = referee.createdAt;
    final deadline = joined.add(Duration(days: s.customerReferralWindowDays));
    final count = delivered
        .where((o) =>
            o.customerId == referee.uid &&
            !o.createdAt.isBefore(joined) &&
            !o.createdAt.isAfter(deadline))
        .length;

    rows.add(_CustomerReferralRow(
      referrer: referrer,
      referee: referee,
      count: count,
      expired: now.isAfter(deadline),
    ));
  }
  rows.sort((a, b) => b.count.compareTo(a.count));
  return rows;
}

List<_CustomerReferralRow> eligibleCustomerReferrals(
        IncentiveSettings s, List<AppUser> customers, List<Order> delivered) =>
    customerReferralRows(s, customers, delivered)
        .where((r) =>
            !r.expired &&
            s.customerReferralOrders > 0 &&
            r.count >= s.customerReferralOrders)
        .toList();

/// قسم نموّ العميل في لوحة الحوافز — حالة الإحالة والكاش باك وعدد المستحقّين،
/// وزرّ صرفٍ يدوي (يستدعي الكنس نفسه) لمن أوقف الصرف التلقائي.
class _CustomerGrowthSection extends StatelessWidget {
  final IncentiveSettings settings;
  final List<AppUser> customers;
  final List<Order> delivered;
  final VoidCallback onPaySweep;
  const _CustomerGrowthSection({
    required this.settings,
    required this.customers,
    required this.delivered,
    required this.onPaySweep,
  });

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final referralOn = s.customerReferralEnabled &&
        (s.customerReferrerBonus > 0 || s.customerRefereeBonus > 0);
    final cashbackOn = s.cashbackPercent > 0;
    if (!referralOn && !cashbackOn) return const SizedBox.shrink();

    final pendingReferrals =
        referralOn ? eligibleCustomerReferrals(s, customers, delivered).length : 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.volunteer_activism_rounded,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(tr('نموّ العميل', 'Customer growth'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          if (referralOn)
            Text(
                pendingReferrals == 0
                    ? tr('لا إحالات عميل مستحقّة الآن',
                        'No customer referrals due right now')
                    : tr('$pendingReferrals إحالة عميل مستحقّة الصرف',
                        '$pendingReferrals customer referrals due for payout'),
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: pendingReferrals == 0
                        ? AppColors.textGray
                        : AppColors.dark)),
          if (cashbackOn)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  tr('الكاش باك ${s.cashbackPercent.toStringAsFixed(1)}٪ يُصرف عن '
                          'كل طلبٍ مسلَّم عند الكنس',
                      'Cashback of ${s.cashbackPercent.toStringAsFixed(1)}% is '
                          'paid for every delivered order during the sweep'),
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textGray)),
            ),
          const SizedBox(height: 12),
          if (!s.autoPay)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: Text(tr('صرف المستحقّين الآن', 'Pay eligible now')),
                onPressed: onPaySweep,
              ),
            ),
          if (s.autoPay)
            Text(
                tr('الصرف التلقائي مفعّل — يُصرف ما دامت اللوحة مفتوحة',
                    'Auto payout is on — pays while this dashboard stays open'),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textGray)),
        ]),
      ),
    );
  }
}

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
            Text(tr('إعدادات الحوافز', 'Incentive settings'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14.5)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => _SettingsForm(initial: s),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(tr('تعديل', 'Edit'),
                  style: const TextStyle(fontSize: 12.5)),
            ),
          ]),
          const Divider(height: 18),
          _row(tr('برنامج الإحالة', 'Referral program'),
              s.referralEnabled ? tr('مفعّل', 'On') : tr('موقوف', 'Off'),
              highlight: !s.referralEnabled),
          _row(tr('مكافأة الداعي', 'Referrer bonus'),
              formatCurrency(s.referrerBonus)),
          _row(tr('مكافأة المدعوّ', 'Referee bonus'),
              formatCurrency(s.refereeBonus)),
          _row(
              tr('الشرط', 'Requirement'),
              tr('${s.referralDeliveries} توصيلة خلال ${s.referralWindowDays} يوماً',
                  '${s.referralDeliveries} deliveries within ${s.referralWindowDays} days')),
          _row(tr('سقف الداعي شهرياً', 'Monthly referrer cap'),
              tr('${s.referralMonthlyCap} إحالات',
                  '${s.referralMonthlyCap} referrals')),
          _row(tr('رابط الدعوة', 'Invite link'), s.joinUrl),
          const Divider(height: 18),
          _row(
              tr('تحدي نهاية الأسبوع', 'Weekend challenge'),
              s.challengeEnabled
                  ? tr('مفعّل — ${s.weekdaysLabel}', 'On — ${s.weekdaysLabel}')
                  : tr('موقوف', 'Off'),
              highlight: !s.challengeEnabled),
          ...s.tiers.map((t) => _row(
              tr('  ${t.deliveries} توصيلة', '  ${t.deliveries} deliveries'),
              formatCurrency(t.bonus))),
          const Divider(height: 18),
          _row(
              tr('درع النقد', 'Cash shield'),
              (s.firstCashOrderCap > 0 ||
                      s.maxConcurrentCashOrders > 0 ||
                      s.cashNoShowLimit > 0)
                  ? tr('سقف ${s.firstCashOrderCap.toStringAsFixed(0)} · تزامن ${s.maxConcurrentCashOrders} · رفض ${s.cashNoShowLimit}',
                      'Cap ${s.firstCashOrderCap.toStringAsFixed(0)} · concurrent ${s.maxConcurrentCashOrders} · no-show ${s.cashNoShowLimit}')
                  : tr('معطّل — كل المقابض صفر', 'Off — all knobs at zero'),
              highlight: s.firstCashOrderCap == 0 &&
                  s.maxConcurrentCashOrders == 0 &&
                  s.cashNoShowLimit == 0),
          _row(
              tr('نقطة التعادل اليومية', 'Daily break-even'),
              s.dailyOrdersTarget > 0
                  ? tr('${s.dailyOrdersTarget} طلباً/يوم',
                      '${s.dailyOrdersTarget} orders/day')
                  : tr('غير محددة — البطاقة مخفية', 'Not set — card hidden'),
              highlight: s.dailyOrdersTarget == 0),
          const Divider(height: 18),
          _row(tr('إحالة العميل', 'Customer referral'),
              s.customerReferralEnabled && s.customerReferrerBonus > 0
                  ? tr(
                      'داعٍ ${formatCurrency(s.customerReferrerBonus)} · '
                          'مدعوّ ${formatCurrency(s.customerRefereeBonus)} · '
                          '${s.customerReferralOrders} طلب',
                      'Referrer ${formatCurrency(s.customerReferrerBonus)} · '
                          'referee ${formatCurrency(s.customerRefereeBonus)} · '
                          '${s.customerReferralOrders} orders')
                  : tr('معطّلة', 'Off'),
              highlight: !s.customerReferralEnabled),
          _row(tr('الكاش باك', 'Cashback'),
              s.cashbackPercent > 0
                  ? tr(
                      '${s.cashbackPercent.toStringAsFixed(1)}٪'
                          '${s.cashbackMaxPerOrder > 0 ? ' · سقف ${formatCurrency(s.cashbackMaxPerOrder)}' : ''}',
                      '${s.cashbackPercent.toStringAsFixed(1)}%'
                          '${s.cashbackMaxPerOrder > 0 ? ' · cap ${formatCurrency(s.cashbackMaxPerOrder)}' : ''}')
                  : tr('معطّل', 'Off'),
              highlight: s.cashbackPercent == 0),
          const Divider(height: 18),
          _row(
              tr('الصرف التلقائي', 'Auto payout'),
              s.autoPay
                  ? tr('مفعّل — يصرف فور تحقّق الشرط',
                      'On — pays as soon as the condition is met')
                  : tr('يدوي بضغطة', 'Manual, one tap')),
          if (s.autoPay)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  tr('يعمل ما دامت هذه الشاشة مفتوحة — الأتمتة على الخادم مع ترقية Blaze',
                      'Runs while this screen stays open — server automation comes with the Blaze upgrade'),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textGray)),
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
                      fontSize: 13.5, color: AppColors.textGray))),
          Text(value,
              style: TextStyle(
                  fontSize: 13.5,
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
  late bool _referralOn, _challengeOn, _custRefOn;
  late final TextEditingController _referrer, _referee, _deliveries,
      _windowDays, _cap, _joinUrl, _maxLoad, _stackKm, _compPct, _tipOptions,
      _delivBase, _delivKm, _delivPerKm, _delivAppCut, _maxDist, _dailyTarget,
      _cashCap, _cashConcurrent, _noShowLimit, _maxItemsTotal,
      _custReferrer, _custReferee, _custRefOrders, _custRefWindow,
      _cashbackPct, _cashbackMax;
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
    _tipOptions = TextEditingController(
        text: s.tipOptions.map((v) => v.toStringAsFixed(0)).join(tr('، ', ', ')));
    _delivBase = TextEditingController(text: s.deliveryBaseFee.toStringAsFixed(0));
    _delivKm = TextEditingController(text: s.deliveryBaseKm.toStringAsFixed(0));
    _delivPerKm =
        TextEditingController(text: s.deliveryPerKmFee.toStringAsFixed(1));
    _delivAppCut =
        TextEditingController(text: s.deliveryAppCut.toStringAsFixed(0));
    _maxDist =
        TextEditingController(text: s.maxDeliveryDistanceKm.toStringAsFixed(0));
    _dailyTarget = TextEditingController(text: '${s.dailyOrdersTarget}');
    _cashCap =
        TextEditingController(text: s.firstCashOrderCap.toStringAsFixed(0));
    _cashConcurrent =
        TextEditingController(text: '${s.maxConcurrentCashOrders}');
    _noShowLimit = TextEditingController(text: '${s.cashNoShowLimit}');
    _maxItemsTotal =
        TextEditingController(text: s.maxOrderItemsTotal.toStringAsFixed(0));
    _custRefOn = s.customerReferralEnabled;
    _custReferrer =
        TextEditingController(text: s.customerReferrerBonus.toStringAsFixed(0));
    _custReferee =
        TextEditingController(text: s.customerRefereeBonus.toStringAsFixed(0));
    _custRefOrders =
        TextEditingController(text: '${s.customerReferralOrders}');
    _custRefWindow =
        TextEditingController(text: '${s.customerReferralWindowDays}');
    _cashbackPct =
        TextEditingController(text: s.cashbackPercent.toStringAsFixed(1));
    _cashbackMax =
        TextEditingController(text: s.cashbackMaxPerOrder.toStringAsFixed(0));
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
      _maxLoad, _stackKm, _compPct, _tipOptions,
      _delivBase, _delivKm, _delivPerKm, _delivAppCut, _maxDist, _dailyTarget,
      _cashCap, _cashConcurrent, _noShowLimit, _maxItemsTotal,
      _custReferrer, _custReferee, _custRefOrders, _custRefWindow,
      _cashbackPct, _cashbackMax,
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
      showError(
          context,
          tr('أضف مستوى واحداً على الأقل للتحدي أو أوقفه',
              'Add at least one challenge tier, or turn the challenge off'));
      return;
    }
    if (_challengeOn && _days.isEmpty) {
      showError(
          context,
          tr('اختر يوماً واحداً على الأقل للتحدي',
              'Pick at least one challenge day'));
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
              tipOptions: _parseTips(_tipOptions.text),
              // أجرة التوصيل — بحرّاس مدى تمنع رقماً يشلّ التسعير بغلطة
              // إدخال (أساس/كم/زائد ≥ صفر، والمسافة القصوى ≥ ١ كم).
              deliveryBaseFee:
                  (double.tryParse(_delivBase.text.trim()) ?? 9).clamp(0.0, 500.0),
              deliveryBaseKm:
                  (double.tryParse(_delivKm.text.trim()) ?? 7).clamp(0.0, 100.0),
              deliveryPerKmFee: (double.tryParse(_delivPerKm.text.trim()) ?? 1)
                  .clamp(0.0, 100.0),
              deliveryAppCut: (double.tryParse(_delivAppCut.text.trim()) ?? 3)
                  .clamp(0.0, 500.0),
              maxDeliveryDistanceKm: (double.tryParse(_maxDist.text.trim()) ?? 25)
                  .clamp(1.0, 500.0),
              // صفر مقصود = إخفاء بطاقة التعادل، فلا حارس أدنى فوقه.
              dailyOrdersTarget:
                  (int.tryParse(_dailyTarget.text.trim()) ?? 0).clamp(0, 100000),
              // درع النقد — صفر يعطّل كل مقبض (ج١: الأرقام من اللوحة).
              firstCashOrderCap:
                  (double.tryParse(_cashCap.text.trim()) ?? 0).clamp(0.0, 10000.0),
              maxConcurrentCashOrders:
                  (int.tryParse(_cashConcurrent.text.trim()) ?? 0).clamp(0, 20),
              cashNoShowLimit:
                  (int.tryParse(_noShowLimit.text.trim()) ?? 0).clamp(0, 50),
              // ح٥: سقف قيمة وجبات الطلب — تحرسه القاعدة، صفر يعطّله.
              maxOrderItemsTotal:
                  (double.tryParse(_maxItemsTotal.text.trim()) ?? 0)
                      .clamp(0.0, 100000.0),
              // نموّ العميل (دفعة ٥) — صفر/تعطيل يوقفه (ج١)، وحرّاس مدى:
              // نسبة الكاش باك ٠..٥٠٪ (فوقها خطأ إدخال يستنزف)، والسقف ≥ صفر.
              customerReferralEnabled: _custRefOn,
              customerReferrerBonus:
                  (double.tryParse(_custReferrer.text.trim()) ?? 0)
                      .clamp(0.0, 10000.0),
              customerRefereeBonus:
                  (double.tryParse(_custReferee.text.trim()) ?? 0)
                      .clamp(0.0, 10000.0),
              customerReferralOrders:
                  (int.tryParse(_custRefOrders.text.trim()) ?? 0).clamp(0, 100),
              customerReferralWindowDays:
                  (int.tryParse(_custRefWindow.text.trim()) ?? 30).clamp(1, 365),
              cashbackPercent:
                  (double.tryParse(_cashbackPct.text.trim()) ?? 0)
                      .clamp(0.0, 50.0),
              cashbackMaxPerOrder:
                  (double.tryParse(_cashbackMax.text.trim()) ?? 0)
                      .clamp(0.0, 10000.0),
            ),
          );
      if (mounted) {
        showSuccess(context, tr('حُفظت الإعدادات', 'Settings saved'));
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showError(context, tr('تعذّر الحفظ', 'Could not save'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = {
      DateTime.saturday: tr('السبت', 'Saturday'),
      DateTime.sunday: tr('الأحد', 'Sunday'),
      DateTime.monday: tr('الاثنين', 'Monday'),
      DateTime.tuesday: tr('الثلاثاء', 'Tuesday'),
      DateTime.wednesday: tr('الأربعاء', 'Wednesday'),
      DateTime.thursday: tr('الخميس', 'Thursday'),
      DateTime.friday: tr('الجمعة', 'Friday'),
    };

    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('إعدادات الحوافز', 'Incentive settings'),
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _referralOn,
            onChanged: (v) => setState(() => _referralOn = v),
            title: Text(tr('برنامج الإحالة', 'Referral program'),
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700)),
          ),
          Row(children: [
            Expanded(
                child: _num(
                    _referrer, tr('مكافأة الداعي (ر.س)', 'Referrer bonus (SAR)'))),
            const SizedBox(width: 10),
            Expanded(
                child: _num(
                    _referee, tr('مكافأة المدعوّ (ر.س)', 'Referee bonus (SAR)'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _num(_deliveries,
                    tr('التوصيلات المطلوبة', 'Required deliveries'))),
            const SizedBox(width: 10),
            Expanded(child: _num(_windowDays, tr('خلال (يوم)', 'Within (days)'))),
          ]),
          const SizedBox(height: 10),
          _num(_cap,
              tr('سقف إحالات الداعي شهرياً', 'Monthly referral cap per referrer')),
          const SizedBox(height: 10),
          TextField(
            controller: _joinUrl,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: tr('رابط صفحة التسجيل', 'Sign-up page link'),
              helperText: tr('يُلحَق به ?ref=كود الداعي — صفحة رفع المستندات',
                  "?ref=referrer's code is appended — the document-upload page"),
              helperMaxLines: 2,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),

          const Divider(height: 26),
          // نموّ العميل (دفعة ٥): إحالة العميل + الكاش باك. كل رقمٍ من هنا،
          // وتعطيلها/تصفيرها يوقفها (ج١)، والصرف بيد المدير (كنس اللوحة) لأن
          // القواعد تمنع العميل من زيادة رصيده.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _custRefOn,
            onChanged: (v) => setState(() => _custRefOn = v),
            title: Text(tr('إحالة العميل', 'Customer referral'),
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700)),
          ),
          Row(children: [
            Expanded(
                child: _num(_custReferrer,
                    tr('مكافأة الداعي (ر.س)', 'Referrer bonus (SAR)'))),
            const SizedBox(width: 10),
            Expanded(
                child: _num(_custReferee,
                    tr('مكافأة المدعوّ (ر.س)', 'Referee bonus (SAR)'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _num(_custRefOrders,
                    tr('طلبات المدعوّ المطلوبة', "Referee's required orders"))),
            const SizedBox(width: 10),
            Expanded(
                child: _num(_custRefWindow, tr('خلال (يوم)', 'Within (days)'))),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                tr('المدعوّ يكتب كود الداعي عند التسجيل. حين يُكمل عدد الطلبات '
                        'المسلَّمة خلال المدّة، تُضاف المكافأتان لمحفظتَيهما.',
                    "The referee enters the referrer's code at sign-up. Once they "
                        'complete the required delivered orders within the window, '
                        'both bonuses go to their wallets.'),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textGray)),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(tr('الكاش باك', 'Cashback'),
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _num(
                    _cashbackPct, tr('نسبة الكاش باك (٪)', 'Cashback rate (%)'))),
            const SizedBox(width: 10),
            Expanded(
                child: _num(_cashbackMax,
                    tr('سقف للطلب (ر.س، صفر=بلا)', 'Cap per order (SAR, 0 = none)'))),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                tr('نسبةٌ من قيمة كل طلبٍ مسلَّم تُضاف لمحفظة العميل (تُخصم من '
                        'طلبه القادم). صفر = معطّل.',
                    'A share of every delivered order credited to the customer '
                        'wallet (deducted from their next order). 0 = off.'),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textGray)),
          ),

          const Divider(height: 26),
          // سقف الإسناد المتزامن — ليس حافزاً، لكنه يسكن هنا لأن هذا
          // المستند وحده يقرؤه تطبيقا المطعم والكابتن (القواعد تقصر
          // `delivery_settings/config` على المدير).
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
                tr('الطلبات المتزامنة للكابتن', 'Simultaneous orders per captain'),
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _num(
                    _maxLoad, tr('أقصى طلبات معاً', 'Max orders at once'))),
            const SizedBox(width: 10),
            Expanded(
                child: _num(_stackKm,
                    tr('تقارب المطاعم (كم)', 'Restaurant proximity (km)'))),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                tr('الكابتن لا يحمل أكثر من العدد أعلاه، ولا يُضمّ إليه طلب '
                        'إلا إذا كان مطعمه ضمن مسافة التقارب من مطعم أول طلب بيده.',
                    'A captain never carries more than the number above, and an '
                        'order is only stacked if its restaurant is within the '
                        "proximity distance of the first order's restaurant."),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textGray)),
          ),

          const Divider(height: 26),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
                tr('تعويض المطعم عند الإلغاء',
                    'Restaurant compensation on cancellation'),
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          _num(
              _compPct,
              tr('نسبة التعويض بعد بدء التحضير (٪)',
                  'Compensation after prep starts (%)')),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(tr('إكرامية الكابتن', 'Captain tips'),
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tipOptions,
            decoration: InputDecoration(
              labelText: tr('خيارات الإكرامية (ريال، مفصولة بفواصل)',
                  'Tip options (SAR, comma-separated)'),
              hintText: tr('2، 5، 10', '2, 5, 10'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                tr('تظهر للعميل في السلة وتصل الكابتن كاملة بلا اقتطاع — '
                        'نقديّها بيده مع التحصيل، وإلكترونيّها يُقيَّد له مع أجرته.',
                    'Shown to the customer at checkout and passed to the captain '
                        'in full — cash tips in hand on collection, electronic '
                        'tips credited with their fee.'),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textGray)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                tr('طلبٌ أُلغي بعد «جاري التحضير» يُقيَّد للمطعم بهذه النسبة من '
                        'قيمة وجباته وبلا عمولة. ١٠٠٪ هو المعيار العالمي، وصفر يعني '
                        'لا تعويض. الإلغاء قبل التحضير لا يُعوَّض أصلاً.',
                    'An order cancelled after "Preparing" is credited to the '
                        'restaurant at this share of its food value, commission-free. '
                        '100% is the global standard; zero means no compensation. '
                        'Cancellations before prep are never compensated.'),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textGray)),
          ),

          const Divider(height: 26),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
                tr('أجرة التوصيل (موحّدة لكل السائقين)',
                    'Delivery fee (same for all drivers)'),
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _num(_delivBase, tr('أجرة الأساس (ر.س)', 'Base fee (SAR)'))),
            const SizedBox(width: 10),
            Expanded(
                child: _num(
                    _delivKm, tr('كم مشمولة بالأساس', 'Km included in base'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _num(_delivPerKm,
                    tr('لكل كم إضافي (ر.س)', 'Per extra km (SAR)'))),
            const SizedBox(width: 10),
            Expanded(
                child: _num(
                    _delivAppCut, tr('رسم المنصّة الثابت', 'Fixed platform fee'))),
          ]),
          const SizedBox(height: 10),
          _num(_maxDist, tr('أقصى مسافة توصيل (كم)', 'Max delivery distance (km)')),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                tr('مثال: ٩ ر.س لأول ٧ كم + ١ لكل كم إضافي، ورسم منصّة ثابت ٣. '
                        'تُطبَّق على كل السائقين بالتساوي — لتمييز سائقٍ مميّز استخدم '
                        'الحوافز لا أجرة أساس مختلفة. تسري على الطلبات الجديدة فقط.',
                    'Example: SAR 9 for the first 7 km + 1 per extra km, and a '
                        'fixed platform fee of 3. Applied to all drivers equally — '
                        'to reward a standout driver use incentives, not a '
                        'different base fee. Applies to new orders only.'),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textGray)),
          ),

          const Divider(height: 26),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(tr('درع النقد', 'Cash shield'),
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _num(_cashCap,
                    tr('سقف أول طلب نقدي (ر.س)', 'First cash order cap (SAR)'))),
            const SizedBox(width: 10),
            Expanded(
                child: _num(_cashConcurrent,
                    tr('حد النقدي المتزامن', 'Concurrent cash limit'))),
          ]),
          const SizedBox(height: 8),
          _num(_maxItemsTotal,
              tr('سقف قيمة وجبات الطلب الواحد (ر.س — صفر يعطّل)',
                  'Max items total per order (SAR — 0 disables)')),
          const SizedBox(height: 10),
          _num(
              _noShowLimit,
              tr('حد رفض الاستلام قبل حظر النقدي',
                  'No-show limit before blocking cash')),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                tr('صفر يعطّل أي مقبض. السقف يسري على من لم يُسلَّم له طلب بعد '
                        '(تحرسه القواعد نفسها)، والحد المتزامن تفحصه السلة، وحد '
                        'الرفض يُحظر به النقدي تلقائياً مع فتح المتابعة الحية — '
                        'ورفع الحظر من تبويب المستخدمين.',
                    'Zero disables any knob. The cap applies to customers with no '
                        'delivered order yet (enforced by the security rules), the '
                        'concurrent limit is checked at checkout, and the no-show '
                        'limit auto-blocks cash and opens live tracking — unblock '
                        'from the users tab.'),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textGray)),
          ),

          const Divider(height: 26),
          _num(
              _dailyTarget,
              tr('نقطة التعادل اليومية (طلبات/يوم)',
                  'Daily break-even (orders/day)')),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                tr('من الدراسة المالية — عدد الطلبات المكتملة يومياً الذي يغطي '
                        'مصاريف التشغيل. يظهر قياسه بطاقةً في رئيسة الإدارة (عرض '
                        '«اليوم»). صفر = إخفاء البطاقة. حدِّثه مع كل تغيير على '
                        'العمولة أو الرسم الثابت.',
                    'From the financial study — the completed orders per day that '
                        'cover operating costs. Tracked as a card on the admin home '
                        '("Today" view). 0 = hide the card. Update it whenever the '
                        'commission or fixed fee changes.'),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textGray)),
          ),

          const Divider(height: 26),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _challengeOn,
            onChanged: (v) => setState(() => _challengeOn = v),
            title: Text(tr('تحدي نهاية الأسبوع', 'Weekend challenge'),
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700)),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(tr('أيام التحدي', 'Challenge days'),
                style: TextStyle(
                    fontSize: 12.5, color: AppColors.textGray)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: names.entries.map((e) {
              final on = _days.contains(e.key);
              return FilterChip(
                label: Text(e.value, style: const TextStyle(fontSize: 12.5)),
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
                    fontSize: 12.5),
                selectedColor: AppColors.primary,
                checkmarkColor: Colors.white,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
                tr('المستويات — يُصرف أعلى مستوى بلغه السائق',
                    'Tiers — the highest tier the driver reaches is paid'),
                style: TextStyle(fontSize: 12.5, color: AppColors.textGray)),
          ),
          const SizedBox(height: 6),
          ..._tiers.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(child: _num(e.value.d, tr('توصيلات', 'Deliveries'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _num(e.value.b, tr('مكافأة (ر.س)', 'Bonus (SAR)'))),
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
              label: Text(tr('إضافة مستوى', 'Add tier'),
                  style: const TextStyle(fontSize: 12.5)),
            ),
          ),

          const Divider(height: 26),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _autoPay,
            onChanged: (v) => setState(() => _autoPay = v),
            title: Text(tr('الصرف التلقائي', 'Auto payout'),
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700)),
            subtitle: Text(
                tr('تُصرف المكافأة فور تحقّق الشرط بلا ضغطة — ما دامت شاشة '
                        'الحوافز مفتوحة (الأتمتة على الخادم تنتظر ترقية Blaze)',
                    'Bonuses are paid the moment the condition is met, no tap '
                        'needed — while the incentives screen stays open (server '
                        'automation awaits the Blaze upgrade)'),
                style: const TextStyle(fontSize: 11.5)),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving
                  ? tr('جارٍ الحفظ...', 'Saving...')
                  : tr('حفظ', 'Save')),
            ),
          ),
        ]),
      ),
    );
  }

  /// خيارات الإكرامية من نص «٢، ٥، ١٠»: الصفر والسالب يُهملان، ثلاثة
  /// تكفي شاشة السلة، وقائمة فارغة تعيد الافتراضي فلا يُعطَّل الخيار
  /// كله بغلطة إدخال.
  static List<double> _parseTips(String raw) {
    final vals = raw
        .split(RegExp(r'[،,]'))
        .map((e) => double.tryParse(e.trim()) ?? 0)
        .where((v) => v > 0)
        .take(3)
        .toList();
    return vals.isEmpty ? const [2, 5, 10] : vals;
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
              child: Text(
                  tr('الإحالات (${eligible.length} مستحقّة)',
                      'Referrals (${eligible.length} due)'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14.5)),
            ),
            // الصرف الجماعي: مستحقّون كثر يعني ضغطات كثيرة، وكلٌّ منها
            // نافذة تأكيد. زرٌّ واحد بتأكيد واحد يذكر العدد والمبلغ.
            if (eligible.length > 1)
              TextButton(
                onPressed: () async {
                  final total = eligible.length *
                      (settings.referrerBonus + settings.refereeBonus);
                  final ok = await showConfirmDialog(context,
                      title: tr('صرف كل المستحقّين', 'Pay all eligible'),
                      content: tr(
                          '${eligible.length} إحالة — إجمالي '
                              '${formatCurrency(total)} تُوزَّع على الطرفين.',
                          '${eligible.length} referrals — a total of '
                              '${formatCurrency(total)} split between both sides.'),
                      confirmLabel: tr('صرف الكل', 'Pay all'));
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
                    showSuccess(
                        context,
                        tr('صُرفت $done من ${eligible.length}',
                            'Paid $done of ${eligible.length}'));
                  }
                },
                child: Text(tr('صرف الكل', 'Pay all'),
                    style: const TextStyle(fontSize: 12.5)),
              ),
          ]),
          if (rows.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
                tr('لا إحالات بعد — يشارك الكابتن كوده من تطبيقه',
                    'No referrals yet — captains share their code from their app'),
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textGray)),
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
                    fontSize: 13.5, fontWeight: FontWeight.w700)),
          ),
          if (r.expired)
            StatusChip(
                label: tr('انقضت المهلة', 'Window expired'),
                color: AppColors.textGray)
          else if (ready)
            StatusChip(label: tr('مستحقّة', 'Due'), color: AppColors.success)
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
              ? tr('أنجز ${r.count} من $target قبل انقضاء المهلة — لا تُصرف',
                  'Completed ${r.count} of $target before the window expired — not paid')
              : tr('أنجز ${r.count} من $target توصيلة',
                  'Completed ${r.count} of $target deliveries'),
          style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
        ),
        if (ready)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: Text(
                  tr('صرف ${formatCurrency(settings.referrerBonus)} للداعي '
                          'و${formatCurrency(settings.refereeBonus)} للمدعوّ',
                      'Pay ${formatCurrency(settings.referrerBonus)} to the referrer '
                          'and ${formatCurrency(settings.refereeBonus)} to the referee'),
                  style: const TextStyle(fontSize: 12.5)),
              onPressed: () async {
                final ok = await showConfirmDialog(context,
                    title: tr('صرف مكافأة الإحالة', 'Pay referral bonus'),
                    content: tr(
                        'تُضاف ${formatCurrency(settings.referrerBonus)} لدفتر '
                            '${r.referrer.name} و${formatCurrency(settings.refereeBonus)} '
                            'لدفتر ${r.referee.name}.',
                        '${formatCurrency(settings.referrerBonus)} is added to '
                            "${r.referrer.name}'s ledger and "
                            '${formatCurrency(settings.refereeBonus)} to '
                            "${r.referee.name}'s."),
                    confirmLabel: tr('صرف', 'Pay'));
                if (ok != true) return;
                try {
                  await service.payReferralBonus(
                    referrer: r.referrer,
                    referee: r.referee,
                    referrerAmount: settings.referrerBonus,
                    refereeAmount: settings.refereeBonus,
                  );
                  if (context.mounted) showSuccess(context, tr('صُرفت المكافأة', 'Bonus paid'));
                } catch (_) {
                  if (context.mounted) {
                    showError(context, tr('تعذّر الصرف', 'Payout failed'));
                  }
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
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
              tr('تحدي نهاية الأسبوع موقوف', 'Weekend challenge is off'),
              style:
                  const TextStyle(fontSize: 13.5, color: AppColors.textGray)),
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
                  tr('التحدي يعمل ${settings.weekdaysLabel} — لا نافذة جارية الآن',
                      'The challenge runs ${settings.weekdaysLabel} — no window is active now'),
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
            Expanded(
              child: Text(tr('تحدي نهاية الأسبوع', 'Weekend challenge'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14.5)),
            ),
            if (unpaid.length > 1)
              TextButton(
                onPressed: () async {
                  final total =
                      unpaid.fold<double>(0, (s, e) => s + e.tier.bonus);
                  final ok = await showConfirmDialog(context,
                      title: tr('صرف كل المستحقّين', 'Pay all eligible'),
                      content: tr(
                          '${unpaid.length} كابتن — إجمالي '
                              '${formatCurrency(total)}.',
                          '${unpaid.length} captains — a total of '
                              '${formatCurrency(total)}.'),
                      confirmLabel: tr('صرف الكل', 'Pay all'));
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
                    showSuccess(
                        context,
                        tr('صُرفت $done من ${unpaid.length}',
                            'Paid $done of ${unpaid.length}'));
                  }
                },
                child: Text(tr('صرف الكل', 'Pay all'),
                    style: const TextStyle(fontSize: 12.5)),
              ),
          ]),
          const SizedBox(height: 4),
          Text(
              tr('النافذة الجارية: ${start.day}/${start.month} — '
                      '${end.day}/${end.month}',
                  'Current window: ${start.day}/${start.month} — '
                      '${end.day}/${end.month}'),
              style:
                  const TextStyle(fontSize: 12.5, color: AppColors.textGray)),
          if (achieved.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
                tr('لم يبلغ أحد أدنى مستوى بعد',
                    'No one has reached the lowest tier yet'),
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textGray)),
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
                                fontSize: 13.5, fontWeight: FontWeight.w700)),
                        Text(
                            tr('${e.count} توصيلة • بلغ مستوى '
                                    '${e.tier.deliveries}',
                                '${e.count} deliveries • reached the '
                                    '${e.tier.deliveries} tier'),
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.textGray)),
                      ]),
                ),
                if (done)
                  StatusChip(label: tr('صُرفت', 'Paid'), color: AppColors.success)
                else
                  TextButton(
                    onPressed: () async {
                      final ok = await showConfirmDialog(context,
                          title: tr('صرف مكافأة التحدي', 'Pay challenge bonus'),
                          content: tr(
                              'تُضاف ${formatCurrency(e.tier.bonus)} لدفتر '
                                  '${e.driver.name} عن ${e.count} توصيلة في هذه '
                                  'النافذة.',
                              '${formatCurrency(e.tier.bonus)} is added to '
                                  "${e.driver.name}'s ledger for ${e.count} "
                                  'deliveries in this window.'),
                          confirmLabel: tr('صرف', 'Pay'));
                      if (ok != true) return;
                      try {
                        await service.payChallengeBonus(
                          driverId: e.driver.id,
                          amount: e.tier.bonus,
                          deliveries: e.count,
                          windowStart: start,
                        );
                        if (context.mounted) {
                          showSuccess(context, tr('صُرفت المكافأة', 'Bonus paid'));
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
                    child: Text(
                        tr('صرف ${formatCurrency(e.tier.bonus)}',
                            'Pay ${formatCurrency(e.tier.bonus)}'),
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
          if (context.mounted) {
            showSuccess(context, tr('نُسخ كود الإحالة', 'Referral code copied'));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
              tr('كود الإحالة: ${driver.referralCode}',
                  'Referral code: ${driver.referralCode}'),
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700,
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
                    Expanded(
                      child: Text(
                          tr('أدنى إصدار مسموح', 'Minimum allowed version'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14.5)),
                    ),
                    Text(
                        tr('نسخة هذا الجهاز $kAppVersion',
                            'This device runs $kAppVersion'),
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textGray)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                      active
                          ? tr('النسخ الأقدم من ${snap.data} محجوبة الآن',
                              'Versions older than ${snap.data} are blocked now')
                          : tr('لا حجب — كل النسخ تعمل',
                              'No block — all versions work'),
                      style: TextStyle(
                          fontSize: 12.5,
                          color: active
                              ? AppColors.warning
                              : AppColors.textGray)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: tr(
                              'مثال 4.0.0 — واتركه فارغاً لإلغاء الحجب',
                              'e.g. 4.0.0 — leave empty to lift the block'),
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _saving ? null : () => _save(service),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 46)),
                      child: Text(tr('حفظ', 'Save')),
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
          title: tr('تحذير — سيحجبك أنت أيضاً',
              'Warning — this will block you too'),
          content: tr(
              'نسخة جهازك $kAppVersion أقدم من $value، فستُحجب هذه '
                  'الشاشة نفسها بعد الحفظ ولن تستطيع التراجع إلا من كونسول '
                  'Firestore. تابع؟',
              'Your device runs $kAppVersion, older than $value, so this very '
                  'screen will be blocked after saving and you can only undo it '
                  'from the Firestore console. Continue?'),
          confirmLabel: tr('أفهم — احفظ', 'I understand — save'),
          confirmColor: AppColors.error);
      if (ok != true) return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await service.setMinAppVersion(value);
      if (mounted) {
        showSuccess(
            context,
            value.isEmpty
                ? tr('أُلغي الحجب', 'Block lifted')
                : tr('أدنى إصدار مسموح: $value',
                    'Minimum allowed version: $value'));
      }
    } catch (_) {
      if (mounted) showError(context, tr('تعذّر الحفظ', 'Could not save'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
