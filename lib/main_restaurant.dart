// نقطة دخول مستقلة تماماً لتطبيق "مدير المطعم" (flavor: restaurant) — شجرة
// الاستيراد هنا تقتصر على RestaurantHome وشاشات التسجيل العامة؛ لا AdminHome
// ولا CustomerHome ولا DriverHome ولا شاشة التسجيل المفتوح. أي حساب ليس
// بدور مدير مطعم يُرفض ويُسجَّل خروجه تلقائياً.
//
// [هوية لونية]: يستخدم AppTheme.build(palette: FlavorPalette.restaurant)
// بدل AppTheme.light الافتراضي، فتظهر كل أزرار وعناصر واجهة هذا التطبيق
// بالبرتقالي الناري الخاص بنكهة المطعم (حرارة المطبخ) — بعيد عمداً عن
// ذهبي العميل الذي كان قريباً منه سابقاً فيسبب الالتباس.
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'app_flavor.dart';
import 'navigator_key.dart';
import 'widgets/connectivity_banner.dart';
import 'models/models.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'providers/firebase_service.dart';
import 'screens/splash_screen.dart';
import 'screens/restaurant/restaurant_home.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_with_code_screen.dart';
import 'utils/theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyBuU7g3vG5enxaebwxGdGgavG5U8cftwd4',
      appId: '1:653081498334:android:6f1df2a0b7335a5620684f',
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
      appId: '1:653081498334:android:6f1df2a0b7335a5620684f',
      messagingSenderId: '653081498334',
      projectId: 'restaurant-app-ed699',
      storageBucket: 'restaurant-app-ed699.firebasestorage.app',
    ),
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  AppFlavorConfig.flavor = AppFlavor.restaurant;
  AppFlavorConfig.flavorLabel = 'المطعم';
  AppFlavorConfig.flavorColor = const Color(0xFFE8590C);
  AppFlavorConfig.flavorIcon = Icons.storefront_rounded;
  AppFlavorConfig.flavorTagline = 'إدارة مطبخك بذكاء';
  AppFlavorConfig.flavorLoginTitle = 'بوابة شركاء المطاعم';
  AppFlavorConfig.restrictToRole = UserRole.restaurantManager;
  AppFlavorConfig.restrictedMessage = 'هذا التطبيق مخصص لحسابات مديري المطاعم فقط';
  AppFlavorConfig.allowGuestBrowsing = false;
  AppFlavorConfig.buildHomeForRole = (role) => const RestaurantHome();
  AppFlavorConfig.buildLoginScreen = ({fromCheckout = false}) => const LoginScreen();
  AppFlavorConfig.buildRegisterScreen = null;
  AppFlavorConfig.buildRegisterWithCodeScreen = () => const RegisterWithCodeScreen();

  runApp(const RestaurantApp());
}

class RestaurantApp extends StatelessWidget {
  const RestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirebaseService();
    return MultiProvider(
      providers: [
        Provider<FirebaseService>(create: (_) => service),
        ChangeNotifierProvider<app_auth.AuthProvider>(
          create: (_) => app_auth.AuthProvider(service),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'ZadGo مطعم',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(palette: FlavorPalette.restaurant),
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