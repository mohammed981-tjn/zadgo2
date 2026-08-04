import 'package:flutter/material.dart';

class RestaurantHome extends StatelessWidget {
  const RestaurantHome({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("لوحة المطعم"),
        backgroundColor: Colors.deepPurple,
      ),
      body: const Center(
        child: Text(
          "هنا تظهر طلبات المطعم",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}