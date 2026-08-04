import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';

class FirebaseService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Restaurant>> streamRestaurants() {
    return _db.collection("restaurants").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Restaurant.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Stream<List<Order>> streamAllOrders() {
    return _db.collection("orders").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Order.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Future<void> toggleRestaurant(String id, bool isOpen) async {
    await _db.collection("restaurants").doc(id).update({
      "isOpen": isOpen,
    });
  }

  Future<void> updateOrderStatus(String id, OrderStatus status) async {
    await _db.collection("orders").doc(id).update({
      "status": status.name,
    });
  }
}