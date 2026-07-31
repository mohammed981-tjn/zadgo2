import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/cart_provider.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import '../auth/login_screen.dart';
import '../auth/change_password_screen.dart';
import 'restaurant_detail_screen.dart';
import 'cart_screen.dart';
import 'my_orders_screen.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});
  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: Text('مرحباً ${auth.user?.name ?? ""}'), actions: [
        badges.Badge(showBadge: cart.itemCount > 0,
          badgeContent: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 10)),
          child: IconButton(icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())))),
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'change_password') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
            } else if (value == 'logout') {
              await auth.logout();
              if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'change_password',
                child: Row(children: [Icon(Icons.lock_reset_outlined, size: 20), SizedBox(width: 8), Text('تغيير كلمة المرور')])),
            PopupMenuItem(value: 'logout',
                child: Row(children: [Icon(Icons.logout, size: 20), SizedBox(width: 8), Text('تسجيل الخروج')])),
          ],
        ),
      ]),
      body: IndexedStack(index: _tab, children: const [_RestaurantsPage(), MyOrdersScreen()]),
      bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), label: 'المطاعم'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'طلباتي'),
        ]),
    );
  }
}

class _RestaurantsPage extends StatelessWidget {
  const _RestaurantsPage();
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    return StreamBuilder<List<Restaurant>>(stream: service.streamRestaurants(), builder: (ctx, snap) {
      if (!snap.hasData) return const AppLoading();
      final list = snap.data!;
      if (list.isEmpty) return const AppEmpty(emoji: '🍽️', title: 'لا يوجد مطاعم');
      return ListView.builder(padding: const EdgeInsets.all(16), itemCount: list.length, itemBuilder: (_, i) {
        final r = list[i];
        return Card(margin: const EdgeInsets.only(bottom: 12), child: InkWell(
          onTap: r.isOpen ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantDetailScreen(restaurant: r))) : null,
          child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            Text(r.emoji, style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                  StatusBadge(label: r.isOpen ? 'مفتوح' : 'مغلق', color: r.isOpen ? AppColors.success : Colors.grey)]),
              Text(r.description, maxLines: 1, style: const TextStyle(color: AppColors.textGray, fontSize: 12)),
            ])),
          ]))));
      });
    });
  }
}
