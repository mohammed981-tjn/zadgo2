class RestaurantHomeScreen extends StatelessWidget {
  const RestaurantHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirebaseService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text("لوحة المطعم")),
      body: StreamBuilder<List<Order>>(
        stream: service.streamAllOrders(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final orders = snapshot.data!;

          final newOrders = orders.where((o) => o.status == OrderStatus.pending).length;
          final preparing = orders.where((o) => o.status == OrderStatus.preparing).length;
          final ready = orders.where((o) => o.status == OrderStatus.readyForPickup).length;
          final finished = orders.where((o) => o.status == OrderStatus.delivered).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildCounter("طلبات جديدة", newOrders),
              _buildCounter("قيد التحضير", preparing),
              _buildCounter("جاهزة", ready),
              _buildCounter("اكتملت اليوم", finished),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCounter(String title, int count) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text("$count"),
      ),
    );
  }
}