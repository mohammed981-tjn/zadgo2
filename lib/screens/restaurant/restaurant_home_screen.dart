import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_service.dart';
import '../../models/models.dart';

class RestaurantHomeScreen extends StatelessWidget {
  final String restaurantId;
  const RestaurantHomeScreen({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirebaseService>(context, listen: false);

    return StreamBuilder<Restaurant?>(
      stream: service
          .streamRestaurants()
          .map((list) => list.firstWhere((r) => r.id == restaurantId)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final restaurant = snapshot.data!;
        final isOpen = restaurant.isOpen;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  service.toggleRestaurant(restaurantId, !isOpen);
                },
                child: Text(isOpen ? "إغلاق المطعم" : "فتح المطعم"),
              ),

              const SizedBox(height: 20),

              Card(
                child: ListTile(
                  title: const Text("حالة المطعم"),
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
        );
      },
    );
  }
}