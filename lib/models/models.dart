import 'package:flutter/material.dart';

class Restaurant {
  final String id;
  final String name;
  final bool isOpen;

  Restaurant({
    required this.id,
    required this.name,
    required this.isOpen,
  });

  factory Restaurant.fromMap(String id, Map<String, dynamic> data) {
    return Restaurant(
      id: id,
      name: data["name"] ?? "",
      isOpen: data["isOpen"] ?? false,
    );
  }
}

enum OrderStatus {
  pending,
  preparing,
  onTheWay,
  completed,
  cancelled,
}

extension OrderStatusExtension on OrderStatus {
  bool get isActive =>
      this == OrderStatus.pending ||
      this == OrderStatus.preparing ||
      this == OrderStatus.onTheWay;

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return "قيد الانتظار";
      case OrderStatus.preparing:
        return "قيد التحضير";
      case OrderStatus.onTheWay:
        return "في الطريق";
      case OrderStatus.completed:
        return "مكتمل";
      case OrderStatus.cancelled:
        return "ملغي";
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.preparing:
        return Colors.blue;
      case OrderStatus.onTheWay:
        return Colors.purple;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }
}

class OrderItem {
  final String name;
  final int quantity;
  final String emoji;

  OrderItem({
    required this.name,
    required this.quantity,
    required this.emoji,
  });

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      name: data["name"] ?? "",
      quantity: data["quantity"] ?? 1,
      emoji: data["emoji"] ?? "🍽️",
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final String customerPhone;
  final String deliveryAddress;
  final OrderStatus status;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.orderNumber,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.status,
    required this.items,
  });

  factory Order.fromMap(String id, Map<String, dynamic> data) {
    return Order(
      id: id,
      orderNumber: data["orderNumber"] ?? "",
      customerPhone: data["customerPhone"] ?? "",
      deliveryAddress: data["deliveryAddress"] ?? "",
      status: OrderStatus.values.firstWhere(
        (e) => e.name == data["status"],
        orElse: () => OrderStatus.pending,
      ),
      items: (data["items"] as List<dynamic>)
          .map((item) => OrderItem.fromMap(item))
          .toList(),
    );
  }
}