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
import 'restaurant_reports_tab.dart';
import 'restaurant_menu_prices_tab.dart';

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
        title: Text(switch (_tab) {
          0 => 'طلبات ${auth.user?.restaurantName ?? "المطعم"}',
          1 => 'التقارير والحسابات',
          _ => 'أسعار القائمة',
        }),
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
              RestaurantMenuPricesTab(restaurantId: restaurantId),
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
                NavigationDestination(
                    icon: Icon(Icons.sell_outlined), label: 'الأسعار'),
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
    return AppStreamBuilder<List<Order>>(
      stream: () => service.streamRestaurantOrders(restaurantId),
      builder: (ctx, orders) {
        if (orders.isEmpty) return const AppEmpty(emoji: '📦', title: 'لا يوجد طلبات لمطعمك حتى الآن');
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (_, i) => _RestaurantOrderCard(order: orders[i], service: service),
        );
      },
    );
  }
}

/// بطاقة طلب واحدة بتصميم مقتبس من شاشة "الطلبات" السابقة في لوحة المدير:
/// شارة حالة بارزة أعلى البطاقة، وزر إجراء واحد بلون مميز أسفلها بدل زر
/// ElevatedButton عادي. القيود على صلاحيات المطعم كما هي دون أي تغيير: لا
/// تتبع سائق، لا إلغاء، لا تأكيد توصيل — تتوقف الإجراءات عند "الطلب جاهز".
class _RestaurantOrderCard extends StatelessWidget {
  final Order order;
  final FirebaseService service;
  const _RestaurantOrderCard({required this.order, required this.service});

  /// نص وأيقونة الشارة العلوية حسب حالة الطلب — بلغة موجّهة للمطعم بدل
  /// النص التقني العام لكل الأدوار (order.status.label).
  (String, Color, IconData) get _bannerInfo {
    switch (order.status) {
      case OrderStatus.restaurantPending:
        return ('طلب جديد بانتظار التأكيد', AppColors.warning, Icons.fiber_new_rounded);
      case OrderStatus.restaurantAccepted:
        return ('تم الاستلام — جاري التجهيز', AppColors.primary, Icons.hourglass_top_rounded);
      case OrderStatus.preparing:
        return ('قيد التحضير', AppColors.primary, Icons.restaurant_rounded);
      case OrderStatus.readyForPickup:
        return ('جاهز للاستلام', Colors.teal, Icons.shopping_bag_rounded);
      case OrderStatus.searchingDriver:
        return ('بانتظار سائق', Colors.deepPurple, Icons.manage_search_rounded);
      case OrderStatus.driverAssigned:
      case OrderStatus.pickedUp:
      case OrderStatus.onTheWay:
        return ('في الطريق إلى العميل', Colors.deepPurple, Icons.delivery_dining_rounded);
      default:
        return (order.status.label, order.status.color, Icons.info_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bannerLabel, bannerColor, bannerIcon) = _bannerInfo;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // الشارة العلوية البارزة (بديل StatusBadge الصغير السابق).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bannerColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(bannerIcon, size: 16, color: bannerColor),
              const SizedBox(width: 6),
              Text(bannerLabel,
                  style: TextStyle(color: bannerColor, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Text('#${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Text(formatCurrency(order.grandTotal),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 15)),
          ]),
          const SizedBox(height: 4),
          InfoRow(icon: Icons.person_outline, text: order.customerName),
          // ملاحظة: تم إزالة زر "رفض/إلغاء الطلب" نهائياً من شاشة المطعم بناءً على
          // طلب المنصة — إلغاء الطلب لا يظهر إلا في شاشة الطلبات بلوحة المدير العام.
          // كذلك تتبع السائق وتأكيد إغلاق/تسليم الطلب ليسا من اختصاص المطعم؛ دور
          // المطعم يقتصر على تأكيد الاستلام وتجهيز الطلب وتعليمه جاهزاً، ثم يتولى
          // السائق ولوحة المدير العام بقية دورة الطلب (تتبع الموقع والتسليم).
          if (order.status == OrderStatus.restaurantPending) ...[
            const SizedBox(height: 10),
            _ActionButton(
              label: 'تأكيد استلام الطلب',
              color: AppColors.primary,
              onPressed: () => service.updateOrderStatus(order.id, OrderStatus.restaurantAccepted),
            ),
          ],
          if (order.status == OrderStatus.restaurantAccepted) ...[
            const SizedBox(height: 10),
            _ActionButton(
              label: 'تجهيز الطلب',
              color: AppColors.primary,
              onPressed: () => service.updateOrderStatus(order.id, OrderStatus.preparing),
            ),
          ],
          if (order.status == OrderStatus.preparing) ...[
            const SizedBox(height: 10),
            _ActionButton(
              label: 'الطلب جاهز',
              color: AppColors.success,
              onPressed: () => service.updateOrderStatus(order.id, OrderStatus.readyForPickup),
            ),
          ],
        ]),
      ),
    );
  }
}

/// زر إجراء بارز بخلفية ملوّنة كاملة العرض — بديل ElevatedButton الافتراضي
/// ليطابق الطابع البصري لزر "تأكيد التوصيل" الأخضر في التصميم المرجعي.
class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _ActionButton({required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onPressed,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
}