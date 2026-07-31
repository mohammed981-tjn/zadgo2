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
        IconButton(icon: const Icon(Icons.logout), onPressed: () async {
          await auth.logout();
          if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
        }),
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
      final openCount = list.where((restaurant) => restaurant.isOpen).length;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'أهلاً بك في DineGo',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$openCount مطعم مفتوح',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'اختر وجبتك المفضلة واطلبها بسرعة مع التوصيل السريع.',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _InfoChip(icon: Icons.delivery_dining_rounded, label: 'توصيل سريع'),
                    _InfoChip(icon: Icons.local_fire_department_rounded, label: 'وجبات ساخنة'),
                    _InfoChip(icon: Icons.star_rounded, label: 'تقييمات ممتازة'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('المطاعم المتاحة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...list.map((restaurant) => _RestaurantCard(restaurant: restaurant)),
        ],
      );
    });
  }
}

class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;

  const _RestaurantCard({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: restaurant.isOpen
            ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RestaurantDetailScreen(restaurant: restaurant)),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(restaurant.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        StatusBadge(
                          label: restaurant.isOpen ? 'مفتوح' : 'مغلق',
                          color: restaurant.isOpen ? AppColors.restaurantAccent : Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      restaurant.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textGray, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.delivery_dining_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${restaurant.estimatedTimeMin} دقيقة',
                          style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.attach_money_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'توصيل ${restaurant.deliveryFee.toInt()} ر.س',
                          style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
