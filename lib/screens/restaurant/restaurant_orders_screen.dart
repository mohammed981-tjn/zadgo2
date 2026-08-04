import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_service.dart';
import '../../models/models.dart';

class RestaurantOrdersScreen extends StatelessWidget {
  const RestaurantOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirebaseService>(context, listen: false);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("طلبات المطعم"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "نشطة"),
              Tab(text: "منتهية"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OrdersList(service, active: true),
            _OrdersList(service, active: false),
          ],
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final FirebaseService service;
  final bool active;

  const _OrdersList(this.service, {required this.active});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: service.streamAllOrders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data!.where((o) {
          if (active) {
            return o.status.isActive;
          } else {
            return !o.status.isActive;
          }
        }).toList();

        if (orders.isEmpty) {
          return const Center(child: Text("لا توجد طلبات"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, i) => _OrderCard(order: orders[i]),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "طلب #${order.orderNumber}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  order.status.label,
                  style: TextStyle(
                    color: order.status.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text("العميل: ${order.customerPhone}"),
            Text("العنوان: ${order.deliveryAddress}"),

            const Divider(),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: order.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    "${item.emoji} ${item.name} ×${item.quantity}",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}