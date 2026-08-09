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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذّر تصدير التقرير')));
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
          return const AppEmpty(emoji: '📊', title: 'لا يوجد طلبات لعرض تقاريرها بعد');
        }
        final sold = orders.where((o) => o.status == OrderStatus.delivered).toList();
        final totalMealsValue = sold.fold(0.0, (s, o) => s + o.itemsTotal);
        final sorted = [...orders]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final restaurantName = context.read<app_auth.AuthProvider>().user?.restaurantName ??
            'المطعم';

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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('إجمالي قيمة الوجبات المباعة',
                    style: TextStyle(color: Colors.white70)),
                Text(formatCurrency(totalMealsValue),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('${sold.length} طلب مكتمل',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 12),

            // دفتر المستحقّات: مبيعاتك − عمولة المنصّة − ما استلمته فعلاً.
            // شفافية كاملة تُغني عن المراجعة الهاتفية عند كل تسوية.
            Builder(builder: (ctx) {
              final commission =
                  sold.fold(0.0, (s, o) => s + o.effectiveCommission);
              final net = totalMealsValue - commission;
              return AppStreamBuilder<List<RestaurantSettlement>>(
                stream: () =>
                    service.streamRestaurantSettlements(widget.restaurantId),
                loading: const SizedBox.shrink(),
                builder: (ctx, settlements) {
                  final paid = settlements.fold(0.0, (s, x) => s + x.amount);
                  final remaining = net - paid;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(children: [
                        const Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text('دفتر المستحقّات',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        const SizedBox(height: 6),
                        PriceRow(
                            label: 'مبيعات الوجبات',
                            value: formatCurrency(totalMealsValue)),
                        PriceRow(
                            label: 'عمولة المنصّة (15%)',
                            value: '- ${formatCurrency(commission)}'),
                        PriceRow(
                            label: 'صافي المستحق',
                            value: formatCurrency(net)),
                        PriceRow(
                            label: 'استلمته',
                            value: '- ${formatCurrency(paid)}'),
                        const Divider(),
                        PriceRow(
                            label: remaining >= 0
                                ? 'المتبقّي لك'
                                : 'مدفوع لك زيادةً',
                            value: formatCurrency(remaining.abs()),
                            bold: true),
                        if (settlements.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text('آخر الدفعات',
                                style: TextStyle(
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
                                        style: const TextStyle(fontSize: 12)),
                                  ),
                                  Text(formatCurrency(x.amount),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ]),
                              )),
                        ],
                      ]),
                    ),
                  );
                },
              );
            }),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('تصدير Excel'),
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
                  label: const Text('تصدير PDF'),
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
            const SectionHeader(title: 'تفاصيل الطلبات'),
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
                      const SizedBox(height: 6),
                      PriceRow(label: 'قيمة الوجبات', value: formatCurrency(o.itemsTotal), bold: true),
                    ]),
                  ),
                )),
          ],
        );
      },
    );
  }
}
