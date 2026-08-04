import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_service.dart';
import '../../models/models.dart';
import '../../utils/alerts.dart';

class RestaurantMain extends StatelessWidget {
  final String restaurantId;
  const RestaurantMain({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirebaseService>(context, listen: false);

    return StreamBuilder<Restaurant?>(
      stream: service
          .streamRestaurants()
          .map((list) => list.firstWhere(
                (r) => r.id == restaurantId,
                orElse: () => Restaurant(
                  id: restaurantId,
                  name: "",
                  isOpen: false,
                ),
              )),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showAlert(context, "المطعم غير موجود", AlertType.error);
          });

          return const Scaffold(
            body: Center(child: Text("المطعم غير موجود")),
          );
        }

        final restaurant = snapshot.data!;
        final isOpen = restaurant.isOpen;

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
                // شاشة الرئيسية
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          await service.toggleRestaurant(
                              restaurantId, !isOpen);

                          showAlert(
                            context,
                            !isOpen ? "تم فتح المطعم" : "تم إغلاق المطعم",
                            AlertType.success,
                          );
                        },
                        child: Text(
                          isOpen ? "إغلاق المطعم" : "فتح المطعم",
                        ),
                      ),

                      const SizedBox(height: 20),

                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: Icon(
                            isOpen ? Icons.store : Icons.storefront,
                            color: isOpen ? Colors.green : Colors.red,
                          ),
                          title: const Text(
                            "حالة المطعم",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Text(
                            isOpen ? "مفتوح" : "مغلق",
                            style: TextStyle(
                              color: isOpen ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // شاشة الطلبات
                RestaurantOrders(service: service),
              ],
            ),
          ),
        );
      },
    );
  }
}

class RestaurantOrders extends StatelessWidget {
  final FirebaseService service;
  const RestaurantOrders({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            tabs: [
              Tab(text: "نشطة"),
              Tab(text: "منتهية"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OrdersList(service, true),
            _OrdersList(service, false),
          ],
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final FirebaseService service;
  final bool active;

  const _OrdersList(this.service, this.active);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: service.streamAllOrders(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showAlert(context, "خطأ أثناء تحميل الطلبات", AlertType.error);
          });
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data!.where((o) {
          return active ? o.status.isActive : !o.status.isActive;
        }).toList();

        if (orders.isEmpty) {
          return const Center(child: Text("لا توجد طلبات"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, i) {
            final order = orders[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            await service.updateOrderStatus(
                              order.id,
                              OrderStatus.cancelled,
                            );

                            showAlert(
                              context,
                              "تم إلغاء الطلب",
                              AlertType.warning,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text("إلغاء"),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await service.updateOrderStatus(
                              order.id,
                              OrderStatus.pending,
                            );

                            showAlert(
                              context,
                              "تم إعادة الطلب",
                              AlertType.info,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          child: const Text("إعادة"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}