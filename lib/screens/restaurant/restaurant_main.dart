import 'package:flutter/material.dart';
import 'restaurant_home_screen.dart';
import 'restaurant_orders_screen.dart';

class RestaurantMain extends StatelessWidget {
  final String restaurantId;
  const RestaurantMain({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("لوحة المطعم"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "الرئيسية"),
              Tab(text: "الطلبات"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RestaurantHomeScreen(restaurantId: restaurantId),
            const RestaurantOrdersScreen(),
          ],
        ),
      ),
    );
  }
}