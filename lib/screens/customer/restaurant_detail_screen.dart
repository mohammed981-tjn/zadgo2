import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../providers/cart_provider.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common_widgets.dart';
import 'cart_screen.dart';

class RestaurantDetailScreen extends StatelessWidget {
  final Restaurant restaurant;
  const RestaurantDetailScreen({super.key, required this.restaurant});
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(restaurant.name)),
      body: StreamBuilder<List<MenuCategory>>(stream: service.streamCategories(restaurant.id), builder: (ctx, catSnap) {
        return StreamBuilder<List<MenuItem>>(stream: service.streamMenuItems(restaurant.id), builder: (ctx2, itemSnap) {
          if (!catSnap.hasData || !itemSnap.hasData) return const AppLoading();
          final cats = catSnap.data!;
          final items = itemSnap.data!;
          return ListView(children: cats.map((cat) {
            final catItems = items.where((i) => i.categoryId == cat.id && i.canOrder).toList();
            if (catItems.isEmpty) return const SizedBox.shrink();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(cat.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              ...catItems.map((item) => _ItemTile(item: item, restaurant: restaurant)),
            ]);
          }).toList());
        });
      }),
      bottomNavigationBar: cart.itemCount > 0 ? SafeArea(child: Padding(padding: const EdgeInsets.all(12),
        child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
            child: Text('عرض السلة (${cart.itemCount})')))) : null,
    );
  }
}

class _ItemTile extends StatelessWidget {
  final MenuItem item; final Restaurant restaurant;
  const _ItemTile({required this.item, required this.restaurant});
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.quantityOf(item.id);
    return Container(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Text(item.emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
          Text(formatCurrency(item.price), style: const TextStyle(color: AppColors.primary)),
        ])),
        if (qty == 0)
          ElevatedButton(
            onPressed: () => context.read<CartProvider>().add(item, restaurant.id, restaurant.name, restaurant.emoji, restaurant.deliveryFee),
            child: const Text('أضف'),
          )
        else
          Row(children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary),
              onPressed: () => context.read<CartProvider>().remove(item.id),
            ),
            Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
              onPressed: () => context.read<CartProvider>().add(item, restaurant.id, restaurant.name, restaurant.emoji, restaurant.deliveryFee),
            ),
          ]),
      ]));
  }
}