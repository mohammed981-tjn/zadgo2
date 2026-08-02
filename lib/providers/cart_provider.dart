import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// سلة العميل — تُحفظ محلياً في SharedPreferences بشكل تلقائي في كل تغيير
/// كي لا تُفقد أثناء تصفح الزائر (قبل تسجيل الدخول) أو عند إغلاق التطبيق
/// وإعادة فتحه، وتُستكمل بعد نجاح التسجيل من نفس النقطة تماماً.
class CartProvider extends ChangeNotifier {
  static const _prefsKey = 'zadgo_guest_cart_v1';

  final List<CartItem> _items = [];
  String? _restaurantId, _restaurantName, _restaurantEmoji;
  double _driverShare = 5.0;
  double _appShare = 0.0;
  bool _restored = false;

  CartProvider() {
    _restore();
  }

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
    _persist();
    notifyListeners();
  }

  void remove(String itemId) {
    final idx = _items.indexWhere((i) => i.item.id == itemId);
    if (idx < 0) return;
    if (_items[idx].quantity > 1) { _items[idx].quantity--; }
    else { _items.removeAt(idx); if (_items.isEmpty) _clearRestaurant(); }
    _persist();
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _clearRestaurant();
    _persist();
    notifyListeners();
  }

  void _clearRestaurant() { _restaurantId = null; _restaurantName = null; _restaurantEmoji = null; }

  List<OrderItem> toOrderItems() => _items.map((ci) => OrderItem(
        menuItemId: ci.item.id, name: ci.item.name, price: ci.item.price,
        emoji: ci.item.emoji, quantity: ci.quantity,
      )).toList();

  // ---------------------------------------------------------------------
  // الحفظ/الاستعادة المحلية: تسمح للزائر غير المسجَّل بتصفح المطاعم وبناء
  // سلته دون أي حساب، ثم تُستأنف تلقائياً بعد تسجيل الدخول/إنشاء الحساب.
  // ---------------------------------------------------------------------
  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) { _restored = true; return; }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _restaurantId = map['restaurantId'] as String?;
      _restaurantName = map['restaurantName'] as String?;
      _restaurantEmoji = map['restaurantEmoji'] as String?;
      _driverShare = (map['driverShare'] as num?)?.toDouble() ?? 5.0;
      _appShare = (map['appShare'] as num?)?.toDouble() ?? 0.0;
      final rawItems = (map['items'] as List?) ?? [];
      _items
        ..clear()
        ..addAll(rawItems.map((e) {
          final entry = e as Map<String, dynamic>;
          final itemMap = (entry['item'] as Map).cast<String, dynamic>();
          final item = MenuItem.fromMap(itemMap, itemMap['id'] as String? ?? '');
          return CartItem(item: item, quantity: (entry['quantity'] as num?)?.toInt() ?? 1);
        }));
      _restored = true;
      notifyListeners();
    } catch (_) {
      _restored = true;
    }
  }

  Future<void> _persist() async {
    if (!_restored) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_items.isEmpty || _restaurantId == null) {
        await prefs.remove(_prefsKey);
        return;
      }
      final map = {
        'restaurantId': _restaurantId,
        'restaurantName': _restaurantName,
        'restaurantEmoji': _restaurantEmoji,
        'driverShare': _driverShare,
        'appShare': _appShare,
        'items': _items.map((ci) {
          final itemMap = ci.item.toMap();
          itemMap['id'] = ci.item.id;
          return {'item': itemMap, 'quantity': ci.quantity};
        }).toList(),
      };
      await prefs.setString(_prefsKey, jsonEncode(map));
    } catch (_) {
      // فشل الحفظ المحلي لا يجب أن يوقف تجربة السلة داخل الجلسة الحالية.
    }
  }
}
