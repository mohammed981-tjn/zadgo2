// lib/screens/restaurant/restaurant_reports_tab.dart
//
// شاشة "التقارير والحسابات" لمدير المطعم — تعرض حالة كل طلب وقيمة الوجبات
// فقط (دون سعر التوصيل)، بالإضافة إلى تقرير مالي إجمالي بقيمة الوجبات
// المباعة من المطعم دون احتساب أجرة التوصيل.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';

class RestaurantReportsTab extends StatelessWidget {
  final String restaurantId;
  const RestaurantReportsTab({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return AppStreamBuilder<List<Order>>(
      stream: () => service.streamRestaurantOrders(restaurantId),
      builder: (ctx, orders) {
        if (orders.isEmpty) {
          return const AppEmpty(emoji: '📊', title: 'لا يوجد طلبات لعرض تقاريرها بعد');
        }
        final sold = orders.where((o) => o.status == OrderStatus.delivered).toList();
        final totalMealsValue = sold.fold(0.0, (s, o) => s + o.itemsTotal);
        final sorted = [...orders]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFFc1121f)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('إجمالي قيمة الوجبات المباعة',
                    style: TextStyle(color: Colors.white70)),
                Text(formatCurrency(totalMealsValue),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('${sold.length} طلب مكتمل • بدون احتساب سعر التوصيل',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
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
