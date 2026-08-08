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
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
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
