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

class AdminReportsTab extends StatelessWidget {
  const AdminReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return AppStreamBuilder<List<Order>>(
      stream: service.streamAllOrders,
      builder: (ctx, orders) {
        // التقارير المالية تُبنى على الطلبات المكتملة فقط — الطلبات الجارية
        // أو الملغاة لم تتحقّق إيراداً بعد.
        final sold =
            orders.where((o) => o.status == OrderStatus.delivered).toList();

        if (sold.isEmpty) {
          return const AppEmpty(
              emoji: '📊', title: 'لا توجد طلبات مكتملة لعرض تقاريرها بعد');
        }

        final totalMeals = sold.fold(0.0, (s, o) => s + o.itemsTotal);
        final totalDelivery = sold.fold(0.0, (s, o) => s + o.driverShare);
        final mealsCommission =
            sold.fold(0.0, (s, o) => s + o.platformCommission);
        final deliveryCommission = sold.fold(0.0, (s, o) => s + o.appShare);
        final totalCommission = mealsCommission + deliveryCommission;
        final vatInMeals = Pricing.vatIncludedIn(totalMeals);

        // تجميع المبيعات لكل مطعم على حدة.
        final byRestaurant = <String, _RestaurantTotals>{};
        for (final o in sold) {
          final entry = byRestaurant.putIfAbsent(
            o.restaurantId,
            () => _RestaurantTotals(name: o.restaurantName),
          );
          entry.orders += 1;
          entry.meals += o.itemsTotal;
          entry.commission += o.platformCommission;
        }
        final restaurants = byRestaurant.values.toList()
          ..sort((a, b) => b.meals.compareTo(a.meals));

        return ListView(
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
                  const Text('إجمالي مبيعات الوجبات — كل المطاعم',
                      style: TextStyle(color: Colors.white70)),
                  Text(formatCurrency(totalMeals),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('${sold.length} طلب مكتمل • ${restaurants.length} مطعم',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
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
                      style: TextStyle(fontSize: 11, color: AppColors.textGray),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const SectionHeader(title: 'تفصيل المبيعات لكل مطعم'),
            ...restaurants.map((r) => _RestaurantReportCard(totals: r)),
          ],
        );
      },
    );
  }
}

/// تجميعة مبيعات مطعم واحد عبر كل طلباته المكتملة.
class _RestaurantTotals {
  final String name;
  int orders = 0;
  double meals = 0;
  double commission = 0;

  _RestaurantTotals({required this.name});

  double get net => meals - commission;
}

class _RestaurantReportCard extends StatelessWidget {
  final _RestaurantTotals totals;
  const _RestaurantReportCard({required this.totals});

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
                      fontSize: 12, color: AppColors.textGray)),
            ]),
            const SizedBox(height: 8),
            PriceRow(
                label: 'مبيعات الوجبات', value: formatCurrency(totals.meals)),
            PriceRow(
                label: 'عمولة التطبيق (15%)',
                value: '- ${formatCurrency(totals.commission)}'),
            const Divider(),
            PriceRow(
                label: 'صافي مستحقّات المطعم',
                value: formatCurrency(totals.net),
                bold: true),
          ],
        ),
      ),
    );
  }
}
