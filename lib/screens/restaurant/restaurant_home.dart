// lib/screens/restaurant/restaurant_home.dart
//
// شاشة "مدير المطعم" — أساس أُعيد استخدامه من شاشة الطلبات في لوحة المدير
// (admin_home.dart) مع فلترة تلقائية على restaurantId الخاص بالمستخدم فقط.
// هذه الشاشة هي نقطة الانطلاق التي سيُبنى فوقها تطبيق المطعم المنفصل مستقبلاً.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../auth/login_screen.dart';
import '../customer/order_map_screen.dart';
import 'restaurant_reports_tab.dart';

class RestaurantHome extends StatefulWidget {
  const RestaurantHome({super.key});

  @override
  State<RestaurantHome> createState() => _RestaurantHomeState();
}

class _RestaurantHomeState extends State<RestaurantHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    final restaurantId = auth.user?.restaurantId;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0
            ? 'طلبات ${auth.user?.restaurantName ?? "المطعم"}'
            : 'التقارير والحسابات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
              }
            },
          ),
        ],
      ),
      body: restaurantId == null || restaurantId.isEmpty
          ? const AppEmpty(
              emoji: '⚠️',
              title: 'حسابك غير مرتبط بمطعم',
              subtitle: 'يرجى مراجعة إدارة المنصة لربط الحساب بمطعم.',
            )
          : IndexedStack(index: _tab, children: [
              _RestaurantOrdersList(restaurantId: restaurantId),
              RestaurantReportsTab(restaurantId: restaurantId),
            ]),
      bottomNavigationBar: restaurantId == null || restaurantId.isEmpty
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined), label: 'الطلبات'),
                NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined), label: 'التقارير والحسابات'),
              ],
            ),
    );
  }
}

class _RestaurantOrdersList extends StatelessWidget {
  final String restaurantId;
  const _RestaurantOrdersList({required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return StreamBuilder<List<Order>>(
      stream: service.streamRestaurantOrders(restaurantId),
      builder: (ctx, snap) {
        if (!snap.hasData) return const AppLoading();
        final orders = snap.data!;
        if (orders.isEmpty) return const AppEmpty(emoji: '📦', title: 'لا يوجد طلبات لمطعمك حتى الآن');
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (_, i) {
            final o = orders[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('#${o.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    StatusBadge(label: o.status.label, color: o.status.color),
                  ]),
                  InfoRow(icon: Icons.person, text: o.customerName),
                  Text(formatCurrency(o.grandTotal),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  // ملاحظة: تم إزالة زر "رفض/إلغاء الطلب" نهائياً من شاشة المطعم بناءً على
                  // طلب المنصة — إلغاء الطلب لا يظهر إلا في شاشة الطلبات بلوحة المدير العام.
                  if (o.status == OrderStatus.pending)
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            onPressed: () => service.updateOrderStatus(o.id, OrderStatus.confirmed),
                            child: const Text('تأكيد'))),
                  if (o.status == OrderStatus.confirmed)
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            onPressed: () => service.updateOrderStatus(o.id, OrderStatus.preparing),
                            child: const Text('بدأ التحضير'))),
                  if (o.status == OrderStatus.preparing)
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            onPressed: () => service.updateOrderStatus(o.id, OrderStatus.readyForPickup),
                            child: const Text('جاهز للاستلام'))),
                  // خريطة تتبع السائق فقط (بدون أي زر لإلغاء الطلب أو تأكيد التوصيل)
                  if (o.driverId != null && o.driverId!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('تتبع موقع السائق'),
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => OrderMapScreen(order: o))),
                        ),
                      ),
                    ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}
