import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_service.dart';
import '../../models/models.dart';

class RestaurantOrdersScreen extends StatelessWidget {
  const RestaurantOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirebaseService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text("طلبات المطعم"),
      ),
      body: StreamBuilder<List<Order>>(
        stream: service.streamAllOrders(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return const Center(child: Text("لا توجد طلبات حالياً"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, i) {
              final order = orders[i];
              return _OrderCard(order: order);
            },
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  String _waitingTime() {
    final diff = DateTime.now().difference(order.createdAt);
    final m = diff.inMinutes;
    final s = diff.inSeconds % 60;
    return "$m دقيقة و $s ثانية";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رقم الطلب + الحالة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "طلب #${order.orderNumber}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Icon(order.status.icon, color: order.status.color),
                    const SizedBox(width: 6),
                    Text(
                      order.status.label,
                      style: TextStyle(
                        color: order.status.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // وقت الوصول + الانتظار
            Text("وقت الوصول: ${order.createdAt}"),
            Text(
              "ينتظر منذ: ${_waitingTime()}",
              style: const TextStyle(color: Colors.red),
            ),

            const Divider(),

            // الأصناف
            const Text(
              "الأصناف:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: order.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "${item.emoji} ${item.name} ×${item.quantity}",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (item.extras != null && item.extras!.isNotEmpty)
                        Text(
                          item.extras!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),

            const Divider(),

            // العميل
            Row(
              children: [
                Text("العميل: ${order.customerPhone}"),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.phone, color: Colors.green),
                  onPressed: () {
                    // الاتصال بالعميل
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}