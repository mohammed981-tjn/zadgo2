// lib/screens/admin/admin_reports_tab.dart
//
// تقارير الإدارة المالية — تعرض للمدير العام صورة كاملة عن المبيعات
// والعمولات: إجماليات كل المطاعم في الأعلى، ثم تفصيل لكل مطعم على حدة
// (مبيعات وجباته، عمولة التطبيق 15% المخصومة منه، وصافي مستحقّاته).
//
// ملاحظات محاسبية مهمة:
// - «مبيعات الوجبات» هي ما دفعه العميل مقابل الطعام، وهي نفسها قيمة الطلب
//   عند المطعم (لا فرق بينهما) — عمولة التطبيق تُخصم من المطعم لاحقاً ولا
//   تُضاف على العميل.
// - أجرة التوصيل (حصّة السائق) والرسم الثابت (حصّة التطبيق من التوصيل)
//   لا علاقة للمطعم بهما إطلاقاً، لذا لا يظهران في تفصيل أي مطعم.
// - الأسعار شاملة ضريبة القيمة المضافة، فتُستخرج الضريبة من المبلغ
//   بالمعادلة (المبلغ × 15 ÷ 115) لا بضربه في 15%.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import 'admin_reports_export.dart';

class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  /// مطعم مُنتقى للتقرير — فارغ = كل المطاعم. مع نمو عدد المطاعم صار
  /// التمرير بحثاً عن مطعم واحد متعباً (ملاحظة المالك).
  String _restaurantFilter = '';

  /// نطاق زمني: null = منذ البداية.
  int? _periodDays;

  /// العدد الحقيقي الكامل للطلبات — يُجلب مرة واحدة عند أول اكتشاف قصّ،
  /// ليصارح عنوانُ «الكل» المديرَ بحجم ما لا يراه.
  int? _trueTotal;
  bool _countRequested = false;

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    // الفترات المحددة تُجلب من القاعدة بمدى تاريخ **كاملاً** لا من نافذة
    // الـ٥٠٠ — كانت الفلترة تجري على النافذة المقصوصة فتكذب حتى «آخر ٧
    // أيام» متى تجاوزت الطلباتُ النافذةَ. هامش يومٍ واحد قبل بداية الفترة
    // لأن الفلترة النهائية أدناه بتاريخ اكتمال الطلب لا إنشائه، وطلبٌ
    // أُنشئ قبيل منتصف الليل يكتمل بعده. «الكل» وحدها تبقى على النافذة
    // (تنزيل التاريخ كله في شاشة حيّة غير وارد) لكن بعنوانٍ وتنبيهٍ صادقين.
    final queryCutoff = _periodDays == null
        ? null
        : DateTime.now()
            .subtract(Duration(days: _periodDays! + 1));

    return AppStreamBuilder<List<Order>>(
      key: ValueKey(_periodDays),
      stream: () => queryCutoff == null
          ? service.streamAllOrders()
          : service.streamOrdersSince(queryCutoff),
      builder: (ctx, orders) {
        // اكتشاف القصّ: «الكل» معروضة والنافذة ممتلئة — نجلب العدد الحقيقي
        // مرة واحدة (استعلام تجميع خادمي رخيص) ونعيد الرسم به.
        final windowCapped = _periodDays == null && orders.length >= 500;
        if (windowCapped && !_countRequested) {
          _countRequested = true;
          service.countAllOrders().then((n) {
            if (mounted) setState(() => _trueTotal = n);
          });
        }
        // التقارير المالية تُبنى على الطلبات المكتملة فقط — الطلبات الجارية
        // أو الملغاة لم تتحقّق إيراداً بعد.
        final all =
            orders.where((o) => o.status == OrderStatus.delivered).toList();

        // أسماء المطاعم للمُنتقي تُبنى من كل الطلبات لا من المفلترة، وإلا
        // اختفى بقية المطاعم من القائمة بمجرد اختيار واحد.
        final restaurantNames = <String, String>{
          for (final o in all) o.restaurantId: o.restaurantName
        };

        final cutoff = _periodDays == null
            ? null
            : DateTime.now().subtract(Duration(days: _periodDays!));
        final sold = all.where((o) {
          if (_restaurantFilter.isNotEmpty &&
              o.restaurantId != _restaurantFilter) {
            return false;
          }
          if (cutoff != null) {
            final t = o.statusChangedAt ?? o.updatedAt ?? o.createdAt;
            if (t.isBefore(cutoff)) return false;
          }
          return true;
        }).toList();

        final filters = _FilterBar(
          restaurantNames: restaurantNames,
          selectedRestaurant: _restaurantFilter,
          periodDays: _periodDays,
          onRestaurant: (v) => setState(() => _restaurantFilter = v),
          onPeriod: (v) => setState(() => _periodDays = v),
        );

        if (sold.isEmpty) {
          return Column(children: [
            filters,
            const Expanded(
              child: AppEmpty(
                  emoji: '📊', title: 'لا توجد طلبات مكتملة ضمن هذا النطاق'),
            ),
          ]);
        }

        final totalMeals = sold.fold(0.0, (s, o) => s + o.itemsTotal);
        final totalDelivery = sold.fold(0.0, (s, o) => s + o.driverShare);
        // العمولة والرسم الثابت بالمشتقّ «الفعّال» لا بالمخزَّن وحده: الطلبات
        // القديمة تحمل صفراً فكانت تُظهر دخل المنصّة شبه معدوم.
        final mealsCommission =
            sold.fold(0.0, (s, o) => s + o.effectiveCommission);
        final deliveryCommission =
            sold.fold(0.0, (s, o) => s + o.effectiveAppShare);
        final totalCommission = mealsCommission + deliveryCommission;
        final vatInMeals = Pricing.vatIncludedIn(totalMeals);

        // الدورة المالية الكاملة: كل ريال دفعه العميل يذهب لأحد ثلاثة —
        // المطعم أو السائق أو المنصّة. عرضها معادلةً واحدة يجعل أي خلل
        // (عمولة ناقصة، أجرة مكررة) ظاهراً فوراً بدل أرقام متناثرة.
        final totalRevenue = sold.fold(0.0, (s, o) => s + o.payableTotal);
        final restaurantsNet = totalMeals - mealsCommission;
        final totalWalletUsed = sold.fold(0.0, (s, o) => s + o.walletUsed);
        // خصومات الكوبونات — تسويقٌ تتحمّله المنصّة وحدها، فتُطرح من دخلها.
        final totalDiscounts = sold.fold(0.0, (s, o) => s + o.discountAmount);
        // تعويضات الإلغاء بعد التحضير تُحسب من **كل** الطلبات لا المكتملة
        // وحدها (الملغى ليس مكتملاً بطبيعته)، وتُطرح من دخل المنصّة لأنها
        // تكلفة تتحمّلها كاملة — وإخفاؤها كان سيُظهر دخلاً لم يتحقق.
        final totalCompensations = orders
            .where((o) => _restaurantFilter.isEmpty ||
                o.restaurantId == _restaurantFilter)
            .fold(0.0, (s, o) => s + o.restaurantCompensation);
        // خصومات شكاوى الجودة تُطرح من مستحق المطاعم لا من دخل المنصّة:
        // المنصّة دفعت الاسترداد للعميل واستردّته من المطعم — صفرٌ صافٍ
        // عندها، والعبء كله على من أفسد الطلب (سياسة المالك 2026-08-13).
        final totalChargebacks = orders
            .where((o) => _restaurantFilter.isEmpty ||
                o.restaurantId == _restaurantFilter)
            .fold(0.0, (s, o) => s + o.restaurantChargeback);
        final platformNet =
            totalCommission - totalDiscounts - totalCompensations;
        // مسار التحصيل: النقدي حصّله السائقون من العملاء مباشرة، والباقي
        // قبضته المنصّة (بطاقات + ما خُصم من أرصدة المحافظ).
        final cashCollected = sold
            .where((o) => o.paymentMethod == PaymentMethod.cash)
            .fold(0.0, (s, o) => s + (o.payableTotal - o.walletUsed));

        // تجميع المبيعات لكل مطعم على حدة.
        final byRestaurant = <String, _RestaurantTotals>{};
        for (final o in sold) {
          final entry = byRestaurant.putIfAbsent(
            o.restaurantId,
            () => _RestaurantTotals(id: o.restaurantId, name: o.restaurantName),
          );
          entry.orders += 1;
          entry.meals += o.itemsTotal;
          entry.commission += o.effectiveCommission;
        }
        final restaurants = byRestaurant.values.toList()
          ..sort((a, b) => b.meals.compareTo(a.meals));

        final scopeLabel = _restaurantFilter.isEmpty
            ? 'كل المطاعم'
            : (restaurantNames[_restaurantFilter] ?? 'مطعم');
        // «منذ البداية» تُكتب فقط حين تكون صادقة (النافذة استوعبت كل
        // التاريخ) — وإلا سُمّيت النافذة باسمها، ويمرّ الاسم الصادق نفسه
        // إلى ملفَّي PDF وExcel فلا يرث التصدير ادّعاءً كاذباً.
        final periodLabel = _periodDays != null
            ? 'آخر $_periodDays يوم'
            : windowCapped
                ? 'أحدث ٥٠٠ طلب${_trueTotal != null ? ' من أصل $_trueTotal' : ''}'
                : 'منذ البداية';

        return Column(children: [
          filters,
          if (windowCapped) WindowCapNotice(trueTotal: _trueTotal),
          Expanded(
            child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // بطاقة الإجماليات العامة
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [context.flavorColors.primary, context.flavorColors.primaryDark]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إجمالي مبيعات الوجبات — $scopeLabel',
                      style: const TextStyle(color: Colors.white70)),
                  Text(formatCurrency(totalMeals),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                      '${sold.length} طلب مكتمل • ${restaurants.length} مطعم • $periodLabel',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // تصدير التقرير المعروض (بنفس الفلاتر) — PDF للعرض والأرشفة،
            // Excel للمعالجة المحاسبية.
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => exportAdminReportPdf(
                    scopeLabel: scopeLabel,
                    periodLabel: periodLabel,
                    orders: sold,
                    restaurants: restaurants
                        .map((r) => (r.name, r.orders, r.meals, r.commission, r.net))
                        .toList(),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('تقرير PDF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => exportAdminReportExcel(
                    scopeLabel: scopeLabel,
                    orders: sold,
                    restaurants: restaurants
                        .map((r) => (r.name, r.orders, r.meals, r.commission, r.net))
                        .toList(),
                  ),
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                  label: const Text('Excel'),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // معادلة الدورة المالية — من دفع العميل حتى استقرار كل ريال.
            const SectionHeader(title: 'الدورة المالية الكاملة'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  PriceRow(
                      label: 'دفعه العملاء (شامل التوصيل والرسوم)',
                      value: formatCurrency(totalRevenue),
                      bold: true),
                  const Divider(),
                  PriceRow(
                      label: '← صافي مستحقّات المطاعم',
                      value: formatCurrency(restaurantsNet - totalChargebacks)),
                  if (totalChargebacks > 0)
                    PriceRow(
                        label: '   منها خصومات شكاوى جودة لصالح العملاء',
                        value: '- ${formatCurrency(totalChargebacks)}'),
                  PriceRow(
                      label: '← أجرة السائقين',
                      value: formatCurrency(totalDelivery)),
                  if (totalDiscounts > 0 || totalCompensations > 0) ...[
                    PriceRow(
                        label: '← دخل المنصّة قبل الخصومات',
                        value: formatCurrency(totalCommission)),
                    if (totalDiscounts > 0)
                      PriceRow(
                          label: '← خصومات الكوبونات (تتحمّلها المنصّة)',
                          value: '- ${formatCurrency(totalDiscounts)}'),
                    if (totalCompensations > 0)
                      PriceRow(
                          label: '← تعويض مطاعم عن إلغاء بعد التحضير',
                          value: '- ${formatCurrency(totalCompensations)}'),
                    PriceRow(
                        label: '← صافي دخل المنصّة',
                        value: formatCurrency(platformNet),
                        bold: true),
                  ] else
                    PriceRow(
                        label: '← دخل المنصّة (عمولة 15% + الرسم الثابت)',
                        value: formatCurrency(totalCommission)),
                  const Divider(),
                  PriceRow(
                      label: 'حصّله السائقون نقداً من العملاء',
                      value: formatCurrency(cashCollected)),
                  PriceRow(
                      label: 'قبضته المنصّة (بطاقات + محافظ)',
                      value: formatCurrency(totalRevenue - cashCollected)),
                  if (totalWalletUsed > 0)
                    PriceRow(
                        label: 'منها مدفوع من أرصدة المحافظ',
                        value: formatCurrency(totalWalletUsed)),
                ]),
              ),
            ),
            const SizedBox(height: 8),

            // أين المال الآن؟ أرصدة السائقين الحيّة: السالب نقدٌ بأيديهم
            // (عُهد لم تُسوَّ بعد)، والموجب مستحقّات عليهم للمنصّة صرفها.
            AppStreamBuilder<List<Driver>>(
              stream: () => service.streamDrivers(),
              loading: const SizedBox.shrink(),
              builder: (ctx, drivers) {
                final custodyHeld = drivers
                    .where((d) => d.balance < 0)
                    .fold(0.0, (s, d) => s + d.balance.abs());
                final duesToDrivers = drivers
                    .where((d) => d.balance > 0)
                    .fold(0.0, (s, d) => s + d.balance);
                if (custodyHeld == 0 && duesToDrivers == 0) {
                  return const SizedBox.shrink();
                }
                return Card(
                  color: AppColors.primary.withOpacity(0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('أرصدة السائقين الآن',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13.5)),
                          const SizedBox(height: 6),
                          PriceRow(
                              label: 'نقد بيد السائقين (عُهد لم تُسوَّ)',
                              value: formatCurrency(custodyHeld)),
                          PriceRow(
                              label: 'مستحقّات للسائقين على المنصّة',
                              value: formatCurrency(duesToDrivers)),
                        ]),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            const SectionHeader(title: 'الإيرادات والعمولات'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  PriceRow(
                      label: 'مبيعات الوجبات', value: formatCurrency(totalMeals)),
                  PriceRow(
                      label: 'قيمة التوصيل (حصّة السائقين)',
                      value: formatCurrency(totalDelivery)),
                  const Divider(),
                  PriceRow(
                      label: 'عمولة الوجبات (15% من المطاعم)',
                      value: formatCurrency(mealsCommission)),
                  PriceRow(
                      label: 'عمولة التوصيل (رسم ثابت)',
                      value: formatCurrency(deliveryCommission)),
                  const Divider(),
                  PriceRow(
                      label: 'إجمالي عمولات التطبيق',
                      value: formatCurrency(totalCommission),
                      bold: true),
                ]),
              ),
            ),
            const SizedBox(height: 8),

            // الضريبة — تُعرض للإدارة لأغراض محاسبية، والأسعار شاملة لها.
            Card(
              color: AppColors.warning.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PriceRow(
                        label: 'ضريبة القيمة المضافة ضمن المبيعات (15%)',
                        value: formatCurrency(vatInMeals),
                        bold: true),
                    const SizedBox(height: 4),
                    const Text(
                      'الأسعار المعروضة للعميل شاملة الضريبة، وهذه قيمتها '
                      'المستخرجة منها للأغراض المحاسبية.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textGray),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const SectionHeader(title: 'تفصيل المبيعات لكل مطعم'),
            ...restaurants.map((r) => _RestaurantReportCard(
                  totals: r,
                  ordersOfRestaurant:
                      sold.where((o) => o.restaurantName == r.name).toList(),
                  periodLabel: periodLabel,
                )),
          ],
            ),
          ),
        ]);
      },
    );
  }
}

/// شريط الفلاتر: مطعم + نطاق زمني — يعملان على التقرير والتصدير معاً.
class _FilterBar extends StatelessWidget {
  final Map<String, String> restaurantNames;
  final String selectedRestaurant;
  final int? periodDays;
  final ValueChanged<String> onRestaurant;
  final ValueChanged<int?> onPeriod;

  const _FilterBar({
    required this.restaurantNames,
    required this.selectedRestaurant,
    required this.periodDays,
    required this.onRestaurant,
    required this.onPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final fc = context.flavorColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Colors.white,
      child: Column(children: [
        DropdownButtonFormField<String>(
          value: selectedRestaurant.isEmpty ? '' : selectedRestaurant,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'المطعم',
            prefixIcon: Icon(Icons.storefront_outlined),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('كل المطاعم')),
            ...restaurantNames.entries.map(
                (e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
          ],
          onChanged: (v) => onRestaurant(v ?? ''),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (label, days) in const [
              ('اليوم', 1),
              ('٧ أيام', 7),
              ('٣٠ يوماً', 30),
              ('الكل', 0),
            ])
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: (days == 0 ? null : days) == periodDays,
                  onSelected: (_) => onPeriod(days == 0 ? null : days),
                  backgroundColor: Colors.white,
                  selectedColor: fc.primary.withOpacity(0.15),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    color: (days == 0 ? null : days) == periodDays
                        ? fc.primaryDark
                        : AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// تجميعة مبيعات مطعم واحد عبر كل طلباته المكتملة.
class _RestaurantTotals {
  final String id;
  final String name;
  int orders = 0;
  double meals = 0;
  double commission = 0;

  _RestaurantTotals({required this.id, required this.name});

  double get net => meals - commission;
}

class _RestaurantReportCard extends StatelessWidget {
  final _RestaurantTotals totals;

  /// طلبات هذا المطعم ضمن النطاق المعروض — أساس فاتورة مستحقّاته.
  final List<Order> ordersOfRestaurant;
  final String periodLabel;

  const _RestaurantReportCard({
    required this.totals,
    required this.ordersOfRestaurant,
    required this.periodLabel,
  });

  String get restaurantId => totals.id;

  /// تسجيل دفعة سُلّمت للمطعم — تُخصم من مستحقّاته في الدفتر.
  Future<void> _recordSettlement(BuildContext context) async {
    final amountCtrl = TextEditingController();
    final methodCtrl = TextEditingController(text: 'تحويل بنكي');
    final service = context.read<FirebaseService>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('تسجيل دفعة — ${totals.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'المبلغ المسلَّم (ر.س)'),
          ),
          TextField(
            controller: methodCtrl,
            decoration: const InputDecoration(labelText: 'طريقة السداد'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('تسجيل')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await service.recordRestaurantSettlement(
        restaurantId: restaurantId,
        restaurantName: totals.name,
        amount: double.tryParse(amountCtrl.text.trim()) ?? 0,
        method: methodCtrl.text,
      );
      if (context.mounted) showSuccess(context, 'سُجّلت الدفعة في دفتر المطعم');
    } catch (e) {
      if (context.mounted) {
        showError(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.restaurant_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(totals.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('${totals.orders} طلب',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textGray)),
            ]),
            const SizedBox(height: 8),
            PriceRow(
                label: 'مبيعات الوجبات', value: formatCurrency(totals.meals)),
            PriceRow(
                label: 'عمولة التطبيق',
                value: '- ${formatCurrency(totals.commission)}'),
            const Divider(),
            PriceRow(
                label: 'صافي مستحقّات المطعم',
                value: formatCurrency(totals.net),
                bold: true),
            // الدفتر: المستحق ناقص ما سُلّم فعلاً — الرقم الذي يهم عند
            // التسوية. **كامل التاريخ من الطرفين** (الإنقاذ السلوكي
            // 2026-08-20): السطر السابق كان يطرح مدفوعاتِ كل التاريخ من
            // صافي الفترة المعروضة وحدها — «متبقٍّ» من عمرين مختلفين
            // ينقلب سالباً وهمياً فور وجود تسوية أقدم من الفلتر.
            FutureBuilder<
                ({
                  double meals,
                  double commission,
                  double compensations,
                  double chargebacks,
                  double paid,
                  int deliveredCount,
                })>(
              future: context
                  .read<FirebaseService>()
                  .restaurantLedgerBalance(restaurantId),
              builder: (ctx, snap) {
                final led = snap.data;
                if (led == null || led.paid == 0) {
                  return const SizedBox.shrink();
                }
                final fullNet = led.meals -
                    led.commission +
                    led.compensations -
                    led.chargebacks;
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(children: [
                    PriceRow(
                        label: 'سُلّم للمطعم (كل التاريخ)',
                        value: '- ${formatCurrency(led.paid)}'),
                    PriceRow(
                        label: 'المتبقّي في الدفتر (كل التاريخ)',
                        value: formatCurrency(fullNet - led.paid),
                        bold: true),
                  ]),
                );
              },
            ),
            const SizedBox(height: 4),
            Row(children: [
              TextButton.icon(
                onPressed: () => exportRestaurantInvoicePdf(
                  restaurantName: totals.name,
                  periodLabel: periodLabel,
                  orders: ordersOfRestaurant,
                ),
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('فاتورة PDF',
                    style: TextStyle(fontSize: 12.5)),
              ),
              TextButton.icon(
                onPressed: () => _recordSettlement(context),
                icon: const Icon(Icons.price_check_rounded, size: 16),
                label: const Text('تسجيل دفعة',
                    style: TextStyle(fontSize: 12.5)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
