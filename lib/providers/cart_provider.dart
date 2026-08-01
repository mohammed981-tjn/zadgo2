import 'package:flutter/material.dart';
import '../models/models.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String? _restaurantId, _restaurantName, _restaurantEmoji;
  double _driverShare = 5.0;
  double _appShare = 0.0;

  List<CartItem> get items => List.unmodifiable(_items);
  String? get restaurantId => _restaurantId;
  String? get restaurantName => _restaurantName;
  String? get restaurantEmoji => _restaurantEmoji;
  double get driverShare => _driverShare;
  double get appShare => _appShare;
  double get deliveryFee => _driverShare + _appShare;
  bool get isEmpty => _items.isEmpty;
  double get itemsTotal => _items.fold(0.0, (s, i) => s + i.subtotal);
  double get grandTotal => itemsTotal + deliveryFee;
  int get itemCount => _items.fold(0, (s, i) => s + i.quantity);
  double get vat => itemsTotal * 0.15;
  double get grandTotalWithVat => grandTotal + vat;
  double get platformCommission => itemsTotal * 0.15;

  int quantityOf(String itemId) {
    try { return _items.firstWhere((i) => i.item.id == itemId).quantity; }
    catch (_) { return 0; }
  }

  void add(MenuItem item, String rId, String rName, String rEmoji, double driverShare, [double appShare = 0.0]) {
    if (_restaurantId != null && _restaurantId != rId) _items.clear();
    _restaurantId = rId; _restaurantName = rName; _restaurantEmoji = rEmoji;
    _driverShare = driverShare; _appShare = appShare;
    final idx = _items.indexWhere((i) => i.item.id == item.id);
    if (idx >= 0) { _items[idx].quantity++; } else { _items.add(CartItem(item: item)); }
    notifyListeners();
  }

  void remove(String itemId) {
    final idx = _items.indexWhere((i) => i.item.id == itemId);
    if (idx < 0) return;
    if (_items[idx].quantity > 1) { _items[idx].quantity--; }
    else { _items.removeAt(idx); if (_items.isEmpty) _clearRestaurant(); }
    notifyListeners();
  }

  void clear() { _items.clear(); _clearRestaurant(); notifyListeners(); }
  void _clearRestaurant() { _restaurantId = null; _restaurantName = null; _restaurantEmoji = null; }

  List<OrderItem> toOrderItems() => _items.map((ci) => OrderItem(
        menuItemId: ci.item.id, name: ci.item.name, price: ci.item.price,
        emoji: ci.item.emoji, quantity: ci.quantity,
      )).toList();
}
