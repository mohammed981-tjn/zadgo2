// نقطة دخول مستقلة تماماً لتطبيق "المدير العام" (flavor: admin) — شجرة
// الاستيراد هنا تقتصر على AdminHome وشاشات التسجيل العامة؛ لا CustomerHome
// ولا DriverHome ولا RestaurantHome ولا شاشة التسجيل المفتوح. أي حساب ليس
// بدور مدير عام يُرفض ويُسجَّل خروجه تلقائياً.
//
// [هوية لونية]: يستخدم AppTheme.build(palette: FlavorPalette.admin) بدل
// AppTheme.light الافتراضي، فتظهر كل عناصر واجهة هذا التطبيق بالبنفسجي
// الملكي الخاص بنكهة المدير («غرفة التحكم») — متمايز بوضوح عن النكهات
// التشغيلية الثلاث حتى لا يُخلَط بينها بصرياً.
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'app_flavor.dart';
import 'navigator_key.dart';
import 'models/models.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'providers/firebase_service.dart';
import 'screens/splash_screen.dart';
import 'screens/admin/admin_home.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_with_code_screen.dart';
import 'utils/theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyBuU7g3vG5enxaebwxGdGgavG5U8cftwd4',
      appId: '1:653081498334:android:8795624d947fdb0820684f',
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
      appId: '1:653081498334:android:8795624d947fdb0820684f',
      messagingSenderId: '653081498334',
      projectId: 'restaurant-app-ed699',
      storageBucket: 'restaurant-app-ed699.firebasestorage.app',
    ),
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  AppFlavorConfig.flavor = AppFlavor.admin;
  AppFlavorConfig.flavorLabel = 'المدير العام';
  AppFlavorConfig.flavorColor = const Color(0xFF5E35B1);
  AppFlavorConfig.flavorIcon = Icons.admin_panel_settings_rounded;
  AppFlavorConfig.flavorTagline = 'غرفة التحكم الكاملة لمنصتك';
  AppFlavorConfig.flavorLoginTitle = 'دخول المدير العام';
  AppFlavorConfig.restrictToRole = UserRole.admin;
  AppFlavorConfig.restrictedMessage = 'هذا التطبيق مخصص لحسابات المدير العام فقط';
  AppFlavorConfig.allowGuestBrowsing = false;
  AppFlavorConfig.buildHomeForRole = (role) => const AdminHome();
  AppFlavorConfig.buildLoginScreen = ({fromCheckout = false}) => const LoginScreen();
  AppFlavorConfig.buildRegisterScreen = null;
  AppFlavorConfig.buildRegisterWithCodeScreen = () => const RegisterWithCodeScreen();

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

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
        title: 'ZadGo إدارة',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(palette: FlavorPalette.admin),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}