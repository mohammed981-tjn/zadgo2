import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'app_flavor.dart';
import 'navigator_key.dart';
import 'widgets/connectivity_banner.dart';
import 'models/models.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'providers/cart_provider.dart';
import 'providers/firebase_service.dart';
import 'screens/splash_screen.dart';
import 'screens/admin/admin_home.dart';
import 'screens/customer/customer_home.dart';
import 'screens/driver/driver_home.dart';
import 'screens/restaurant/restaurant_home.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/register_with_code_screen.dart';
import 'utils/theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyBuU7g3vG5enxaebwxGdGgavG5U8cftwd4',
      appId: '1:653081498334:android:4e220e3299ffd87c20684f',
      messagingSenderId: '653081498334',
      projectId: 'restaurant-app-ed699',
      storageBucket: 'restaurant-app-ed699.firebasestorage.app',
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyBuU7g3vG5enxaebwxGdGgavG5U8cftwd4',
      appId: '1:653081498334:android:4e220e3299ffd87c20684f',
      messagingSenderId: '653081498334',
      projectId: 'restaurant-app-ed699',
      storageBucket: 'restaurant-app-ed699.firebasestorage.app',
    ),
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // النكهة الكاملة (full) هي الوحيدة التي تحتوي شيفرة كل الأدوار الأربعة —
  // بقية النكهات (main_customer.dart/main_driver.dart/main_restaurant.dart/
  // main_admin.dart) لا تستورد هذا الملف إطلاقاً، ولكل منها شجرة استيراد
  // مستقلة تقتصر على شاشات دورها فقط.
  AppFlavorConfig.flavor = AppFlavor.full;
  AppFlavorConfig.restrictToRole = null;
  AppFlavorConfig.allowGuestBrowsing = false;
  AppFlavorConfig.buildHomeForRole = (role) {
    switch (role) {
      case UserRole.admin:
        return const AdminHome();
      case UserRole.customer:
        return const CustomerHome();
      case UserRole.driver:
        return const DriverHome();
      case UserRole.restaurantManager:
        return const RestaurantHome();
    }
  };
  AppFlavorConfig.buildLoginScreen = ({fromCheckout = false}) => LoginScreen(fromCheckout: fromCheckout);
  AppFlavorConfig.buildRegisterScreen = ({fromCheckout = false}) => RegisterScreen(fromCheckout: fromCheckout);
  AppFlavorConfig.buildRegisterWithCodeScreen = () => const RegisterWithCodeScreen();

  runApp(const ZadGoApp());
}

class ZadGoApp extends StatelessWidget {
  const ZadGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirebaseService();
    return MultiProvider(
      providers: [
        Provider<FirebaseService>(create: (_) => service),
        ChangeNotifierProvider<app_auth.AuthProvider>(
          create: (_) => app_auth.AuthProvider(service),
        ),
        ChangeNotifierProvider<CartProvider>(
          create: (_) => CartProvider(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: messengerKey,
        // رسائل الشاشة السابقة تُمسح عند الدخول لشاشة جديدة.
        navigatorObservers: [ClearMessagesOnPush()],
        title: 'ZadGo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          // شريط انقطاع الاتصال يلتف حول كل الشاشات من هنا.
          child: ConnectivityBanner(child: child!),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
