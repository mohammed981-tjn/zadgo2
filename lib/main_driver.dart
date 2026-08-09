// نقطة دخول مستقلة تماماً لتطبيق "السائق" (flavor: driver) — شجرة الاستيراد
// هنا تقتصر على DriverHome وشاشات التسجيل العامة (تسجيل الدخول/التفعيل
// برمز)؛ لا AdminHome ولا CustomerHome ولا RestaurantHome ولا شاشة التسجيل
// المفتوح (register_screen.dart، مخصصة للعملاء فقط). أي حساب ليس بدور سائق
// يُرفض ويُسجَّل خروجه تلقائياً.
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
import 'screens/driver/driver_home.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_with_code_screen.dart';
import 'utils/theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyBuU7g3vG5enxaebwxGdGgavG5U8cftwd4',
      appId: '1:653081498334:android:7901e624143b1abf20684f',
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
      appId: '1:653081498334:android:7901e624143b1abf20684f',
      messagingSenderId: '653081498334',
      projectId: 'restaurant-app-ed699',
      storageBucket: 'restaurant-app-ed699.firebasestorage.app',
    ),
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  AppFlavorConfig.flavor = AppFlavor.driver;
  AppFlavorConfig.flavorLabel = 'السائق';
  AppFlavorConfig.flavorColor = const Color(0xFF1976D2);
  AppFlavorConfig.flavorIcon = Icons.two_wheeler_rounded;
  AppFlavorConfig.flavorTagline = 'انطلق، وصّل، واكسب';
  AppFlavorConfig.flavorLoginTitle = 'دخول الكباتن';
  AppFlavorConfig.restrictToRole = UserRole.driver;
  AppFlavorConfig.restrictedMessage = 'هذا التطبيق مخصص لحسابات السائقين فقط';
  AppFlavorConfig.allowGuestBrowsing = false;
  AppFlavorConfig.buildHomeForRole = (role) => const DriverHome();
  AppFlavorConfig.buildLoginScreen = ({fromCheckout = false}) => const LoginScreen();
  AppFlavorConfig.buildRegisterScreen = null;
  AppFlavorConfig.buildRegisterWithCodeScreen = () => const RegisterWithCodeScreen();

  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

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
        title: 'ZadGo سائق',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(palette: FlavorPalette.driver),
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
