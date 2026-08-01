// lib/screens/restaurant/restaurant_manager_home.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../auth/login_screen.dart';
import '../auth/change_password_screen.dart';
import '../admin/admin_restaurants_tab.dart' show MenuManagerScreen;
import '../customer/order_chat_screen.dart';

/// Home screen for a restaurant-branch manager account. Access is restricted
/// to the single branch/restaurant ([restaurantId]) the account was created
/// for via its invite code — this is the "restaurant app integration" branch
/// mentioned in the requirements: a manager treated like a driver in terms of
/// account creation (invite code), but scoped to managing their own branch's
/// orders and menu instead of delivering.
class RestaurantManagerHome extends StatefulWidget {
  final String restaurantId;
  const RestaurantManagerHome({super.key, required this.restaurantId});

  @override
  State<RestaurantManagerHome> createState() => _RestaurantManagerHomeState();
}

class _RestaurantManagerHomeState extends State<RestaurantManagerHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    final service = context.read<FirebaseService>();

    return StreamBuilder<List<Restaurant>>(
      stream: service.streamRestaurants(),
      builder: (ctx, snap) {
        final restaurant = (snap.data ?? [])
            .where((r) => r.id == widget.restaurantId)
            .cast<Restaurant?>()
            .firstWhere((r) => true, orElse: () => null);

        return Scaffold(
          appBar: AppBar(
            title: Text(restaurant != null ? restaurant.name : 'فرعي'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'change_password') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
                  } else if (value == 'logout') {
                    await auth.logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'change_password',
                      child: Row(children: [Icon(Icons.lock_reset_outlined, size: 20), SizedBox(width: 8), Text('تغيير كلمة المرور')])),
                  PopupMenuItem(value: 'logout',
                      child: Row(children: [Icon(Icons.logout, size: 20), SizedBox(width: 8), Text('تسجيل الخروج')])),
                ],
              ),
            ],
          ),
          body: !snap.hasData
              ? const AppLoading()
              : IndexedStack(index: _tab, children: [
                  _BranchOrdersTab(restaurantId: widget.restaurantId),
                  restaurant != null
                      ? MenuManagerScreen(restaurant: restaurant)
                      : const AppEmpty(emoji: '🍽️', title: 'لم يتم العثور على الفرع'),
                ]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'الطلبات'),
              NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'القائمة'),
            ],
          ),
        );
      },
    );
  }
}

/// Orders list scoped to a single branch — same information an admin sees in
/// the general orders tab, but filtered to [restaurantId] only.
class _BranchOrdersTab extends StatelessWidget {
  final String restaurantId;
  const _BranchOrdersTab({required this.restaurantId});

  Future<void> _markReady(BuildContext context, Order o) async {
    final service = context.read<FirebaseService>();
    await service.updateOrderStatus(o.id, OrderStatus.readyForPickup);
    if (o.driverId != null) {
      final auth = context.read<app_auth.AuthProvider>();
      final user = auth.user!;
      await service.sendChatMessage(ChatMessage(
        id: const Uuid().v4(),
        orderId: o.id,
        senderId: user.uid,
        senderName: user.name,
        senderRole: 'restaurantManager',
        text: 'الطلب #${o.orderNumber} جاهز للاستلام 📦',
        createdAt: DateTime.now(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return StreamBuilder<List<Order>>(
      stream: service.streamRestaurantOrders(restaurantId),
      builder: (ctx, snap) {
        if (!snap.hasData) return const AppLoading();
        final orders = snap.data!;
        if (orders.isEmpty) return const AppEmpty(emoji: '📦', title: 'لا يوجد طلبات لهذا الفرع بعد');
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
                    if (o.driverId != null)
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, size: 20, color: AppColors.primary),
                        tooltip: 'مراسلة السائق',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => OrderChatScreen(order: o)),
                        ),
                      ),
                    StatusBadge(label: o.status.label, color: o.status.color, icon: o.status.icon),
                  ]),
                  InfoRow(icon: Icons.person_outline, text: '${o.customerName} — ${o.customerPhone}'),
                  InfoRow(icon: Icons.location_on_outlined, text: o.deliveryAddress),
                  if (o.driverName != null)
                    InfoRow(icon: Icons.two_wheeler_outlined, text: 'السائق: ${o.driverName}'),
                  const Divider(height: 16),
                  Text(formatCurrency(o.grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  if (o.status == OrderStatus.pending)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(children: [
                        Expanded(child: ElevatedButton(
                            onPressed: () => service.updateOrderStatus(o.id, OrderStatus.confirmed),
                            child: const Text('تأكيد'))),
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton(
                            onPressed: () => service.cancelOrder(o.id),
                            child: const Text('رفض'))),
                      ]),
                    ),
                  if (o.status == OrderStatus.confirmed)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: SizedBox(width: double.infinity, child: ElevatedButton(
                          onPressed: () => service.updateOrderStatus(o.id, OrderStatus.preparing),
                          child: const Text('بدأ التحضير'))),
                    ),
                  if (o.status == OrderStatus.preparing)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: SizedBox(width: double.infinity, child: ElevatedButton(
                          onPressed: () => _markReady(context, o),
                          child: const Text('جاهز للاستلام'))),
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
