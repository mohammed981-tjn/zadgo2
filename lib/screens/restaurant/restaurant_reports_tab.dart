// lib/screens/restaurant/restaurant_reports_tab.dart
//
// شاشة "التقارير والحسابات" لمدير المطعم — تقتصر على ما يخصّ المطعم وحده:
// حالة كل طلب وقيمة وجباته، وإجمالي قيمة الوجبات المباعة. أجرة التوصيل لا
// علاقة للمطعم بها إطلاقاً، فلا تظهر هنا ولا يُشار إليها في أي نص.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/app_lang.dart';
import '../../widgets/common_widgets.dart';
import 'restaurant_reports_export.dart';

class RestaurantReportsTab extends StatefulWidget {
  final String restaurantId;
  const RestaurantReportsTab({super.key, required this.restaurantId});

  @override
  State<RestaurantReportsTab> createState() => _RestaurantReportsTabState();
}

class _RestaurantReportsTabState extends State<RestaurantReportsTab> {
  bool _exporting = false;

  Future<void> _export(Future<void> Function() run) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await run();
    } catch (_) {
      // المعالجة الموحّدة للخطأ (showError) بدل SnackBar خام: تعطي النمط
      // البصري نفسه المستخدَم في كل الشاشات بدل صندوقٍ افتراضي شاذّ.
      if (mounted) {
        showError(
            context, tr('تعذّر تصدير التقرير', 'Failed to export the report'));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<List<Order>>(
      stream: () => service.streamRestaurantOrders(widget.restaurantId),
      builder: (ctx, orders) {
        if (orders.isEmpty) {
          return AppEmpty(
              emoji: '📊',
              title: tr('لا يوجد طلبات لعرض تقاريرها بعد',
                  'No orders to report yet'));
        }
        final sold = orders.where((o) => o.status == OrderStatus.delivered).toList();
        final totalMealsValue = sold.fold(0.0, (s, o) => s + o.itemsTotal);
        final sorted = [...orders]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final restaurantName = context.read<app_auth.AuthProvider>().user?.restaurantName ??
            tr('المطعم', 'Restaurant');

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [context.flavorColors.primary, context.flavorColors.primaryDark]),
                borderRadius: BorderRadius.circular(16),
              ),
              // ألوان النص من رمز الثيم (onPrimary) لا أبيض مثبَّت: يحترم قرار
              // الثيم فلا يكسر لو صار لون النكهة فاتحاً مستقبلاً.
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('إجمالي قيمة الوجبات المباعة', 'Total food sales'),
                    style: TextStyle(color: context.flavorColors.onPrimary.withOpacity(0.7))),
                Text(formatCurrency(totalMealsValue),
                    style: TextStyle(
                        color: context.flavorColors.onPrimary, fontSize: 30, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(tr('${sold.length} طلب مكتمل',
                        '${sold.length} completed orders'),
                    style: TextStyle(color: context.flavorColors.onPrimary.withOpacity(0.7), fontSize: 12.5)),
              ]),
            ),
            const SizedBox(height: 12),

            // دفتر المستحقّات: مبيعاتك − عمولة المنصّة − ما استلمته فعلاً.
            // شفافية كاملة تُغني عن المراجعة الهاتفية عند كل تسوية.
            //
            // **كامل التاريخ لا نافذة الشاشة** (الإنقاذ السلوكي 2026-08-20):
            // كان الصافي يُحسب من أحدث ٢٠٠ طلبٍ فقط بينما «استلمته» تجمع
            // كل التاريخ — طرفا معادلةٍ من عمرين، فينقلب «المتبقي لك»
            // رقماً وهمياً فور تجاوز الـ٢٠٠ ويهدم ثقة التسوية كلها.
            FutureBuilder<
                ({
                  double meals,
                  double commission,
                  double compensations,
                  double chargebacks,
                  double paid,
                  int deliveredCount,
                })>(
              future: service.restaurantLedgerBalance(widget.restaurantId),
              builder: (ctx, snap) {
                final led = snap.data;
                if (led == null) return const SizedBox.shrink();
                final net = led.meals -
                    led.commission +
                    led.compensations -
                    led.chargebacks;
                final remaining = net - led.paid;
                return AppStreamBuilder<List<RestaurantSettlement>>(
                  stream: () =>
                      service.streamRestaurantSettlements(widget.restaurantId),
                  loading: const SizedBox.shrink(),
                  builder: (ctx, settlements) {
                    return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Row(children: [
                            Text(tr('دفتر المستحقّات', 'Payout ledger'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5)),
                            const Spacer(),
                            Text(
                                tr('كامل التاريخ — ${led.deliveredCount} طلب',
                                    'All-time — ${led.deliveredCount} orders'),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textGray)),
                          ]),
                        ),
                        const SizedBox(height: 6),
                        PriceRow(
                            label: tr('مبيعات الوجبات', 'Food sales'),
                            value: formatCurrency(led.meals)),
                        PriceRow(
                            label: tr('عمولة المنصّة', 'Platform commission'),
                            value: '- ${formatCurrency(led.commission)}'),
                        if (led.compensations > 0)
                          PriceRow(
                              label: tr('تعويض طلبات أُلغيت بعد التحضير',
                                  'Compensation for orders canceled after preparation'),
                              value:
                                  '+ ${formatCurrency(led.compensations)}'),
                        if (led.chargebacks > 0)
                          PriceRow(
                              label: tr('خصومات شكاوى جودة (لصالح العملاء)',
                                  'Quality-complaint deductions (refunded to customers)'),
                              value: '- ${formatCurrency(led.chargebacks)}'),
                        // «صافي المستحق» بارز كـ«المتبقّي لك»: هو الرقم الذي
                        // يقرأه المطعم قبل غيره، فلا يصحّ أن يحمل وزن البنود
                        // الخام فوقه — دفاتر التجار العالمية تُبرز الصافي والمدفوع.
                        PriceRow(
                            label: tr('صافي المستحق', 'Net payable'),
                            value: formatCurrency(net),
                            bold: true),
                        PriceRow(
                            label: tr('استلمته', 'Received'),
                            value: '- ${formatCurrency(led.paid)}'),
                        const Divider(),
                        PriceRow(
                            label: remaining >= 0
                                ? tr('المتبقّي لك', 'Balance due to you')
                                : tr('مدفوع لك زيادةً', 'Overpaid to you'),
                            value: formatCurrency(remaining.abs()),
                            bold: true),
                        if (settlements.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(tr('آخر الدفعات', 'Recent payouts'),
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textGray)),
                          ),
                          ...settlements.take(5).map((x) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(children: [
                                  const Icon(Icons.south_west_rounded,
                                      size: 14, color: AppColors.success),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                        '${x.createdAt.year}/${x.createdAt.month}/${x.createdAt.day}'
                                        '${x.method.isEmpty ? '' : ' — ${x.method}'}',
                                        style: const TextStyle(fontSize: 12.5)),
                                  ),
                                  Text(formatCurrency(x.amount),
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600)),
                                ]),
                              )),
                        ],
                      ]),
                    ),
                  );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.table_chart_outlined),
                  label: Text(tr('تصدير Excel', 'Export Excel')),
                  onPressed: _exporting
                      ? null
                      : () => _export(() => exportRestaurantReportExcel(
                            restaurantName: restaurantName,
                            orders: sorted,
                            totalMealsValue: totalMealsValue,
                          )),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(tr('تصدير PDF', 'Export PDF')),
                  onPressed: _exporting
                      ? null
                      : () => _export(() => exportRestaurantReportPdf(
                            restaurantName: restaurantName,
                            orders: sorted,
                            totalMealsValue: totalMealsValue,
                          )),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            SectionHeader(title: tr('تفاصيل الطلبات', 'Order details')),
            // تفصيل سطري قابل للتدقيق (بطلب المالك بعد شكّه في أساس
            // العمولة): كل طلب يعرض أصنافه وقيمة وجباته وعمولته وصافيه —
            // فمجموع الأعمدة يطابق الدفتر أعلاه رقماً رقماً، وأي طلبٍ
            // «قيمة وجباته» تشمل توصيلاً بالخطأ ينكشف من سطر أصنافه فوراً.
            ...sorted.map((o) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('#${o.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        StatusBadge(label: o.status.label, color: o.status.color),
                      ]),
                      if (o.items.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          o.items
                              .map((i) => '${i.name} ×${i.quantity}')
                              .join(tr('، ', ', ')),
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.textGray),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      PriceRow(
                          label: tr('قيمة الوجبات', 'Food value'),
                          value: formatCurrency(o.itemsTotal),
                          bold: true),
                      if (o.status == OrderStatus.delivered) ...[
                        PriceRow(
                            label: tr('عمولة المنصّة', 'Platform commission'),
                            value: '- ${formatCurrency(o.effectiveCommission)}'),
                        PriceRow(
                            label: tr('صافيك من الطلب',
                                'Your net from this order'),
                            value: formatCurrency(
                                o.itemsTotal - o.effectiveCommission)),
                      ],
                      // طلبٌ أُلغي بعد طبخه: يُعوَّض كاملاً بلا عمولة.
                      if (o.restaurantCompensation > 0)
                        PriceRow(
                            label: tr('تعويض إلغاء بعد التحضير',
                                'Compensation for cancellation after preparation'),
                            value:
                                '+ ${formatCurrency(o.restaurantCompensation)}',
                            bold: true),
                      if (o.restaurantChargeback > 0)
                        PriceRow(
                            label: tr('خصم شكوى جودة (لصالح العميل)',
                                'Quality-complaint deduction (to customer)'),
                            value:
                                '- ${formatCurrency(o.restaurantChargeback)}',
                            bold: true),
                    ]),
                  ),
                )),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                tr(
                    'قيمة الوجبات = مجموع الأصناف فقط — أجرة التوصيل لا تدخل في '
                        'مبيعاتك ولا تُحتسب عليها عمولة.',
                    'Food value = the sum of items only — the delivery fee is not '
                        'part of your sales and no commission is charged on it.'),
                style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
              ),
            ),
          ],
        );
      },
    );
  }
}
