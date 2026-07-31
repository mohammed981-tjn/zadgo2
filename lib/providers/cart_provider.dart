import 'package:flutter/material.dart';
import '../models/models.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String? _restaurantId, _restaurantName, _restaurantEmoji;
  double _deliveryFee = 5.0;
  double? _restaurantLat, _restaurantLng;

  List<CartItem> get items => List.unmodifiable(_items);
  String? get restaurantId => _restaurantId;
  String? get restaurantName => _restaurantName;
  String? get restaurantEmoji => _restaurantEmoji;
  double? get restaurantLat => _restaurantLat;
  double? get restaurantLng => _restaurantLng;
  double get deliveryFee => _deliveryFee;
  bool get isEmpty => _items.isEmpty;
  double get itemsTotal => _items.fold(0.0, (s, i) => s + i.subtotal);
  double get grandTotal => itemsTotal + _deliveryFee;
  int get itemCount => _items.fold(0, (s, i) => s + i.quantity);
  double get vat => itemsTotal * 0.15;
  double get grandTotalWithVat => grandTotal + vat;
  double get platformCommission => itemsTotal * 0.15;

  int quantityOf(String itemId) {
    try { return _items.firstWhere((i) => i.item.id == itemId).quantity; }
    catch (_) { return 0; }
  }

  void add(
    MenuItem item,
    String rId,
    String rName,
    String rEmoji,
    double fee, [
    double? restaurantLat,
    double? restaurantLng,
  ]) {
    if (_restaurantId != null && _restaurantId != rId) _items.clear();
    _restaurantId = rId;
    _restaurantName = rName;
    _restaurantEmoji = rEmoji;
    _deliveryFee = fee;
    _restaurantLat = restaurantLat;
    _restaurantLng = restaurantLng;
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
  void _clearRestaurant() {
    _restaurantId = null;
    _restaurantName = null;
    _restaurantEmoji = null;
    _restaurantLat = null;
    _restaurantLng = null;
  }

  List<OrderItem> toOrderItems() => _items.map((ci) => OrderItem(
        menuItemId: ci.item.id, name: ci.item.name, price: ci.item.price,
        emoji: ci.item.emoji, quantity: ci.quantity,
      )).toList();
}
