import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/firebase_service.dart';
import 'screens/restaurant/RestaurantMain.dart';

void main() {
  runApp(const ZadGoApp());
}

class ZadGoApp extends StatelessWidget {
  const ZadGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FirebaseService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "ZadGo",
        theme: ThemeData(
          primarySwatch: Colors.red,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
        home: const AppEntry(),
      ),
    );
  }
}

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    const restaurantId = "RESTAURANT_1";
    return RestaurantMain(restaurantId: restaurantId);
  }
}