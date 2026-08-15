// نقطة دخول مخصصة لتطبيق "العميل" المستقل (flavor: customer) — يشارك نفس
// الكود ومشروع Firebase مع بقية النكهات، لكن شجرة الاستيراد هنا تقتصر على
// شاشات العميل فقط (لا AdminHome/DriverHome/RestaurantHome ولا مسار
// "تسجيل الموظفين برمز" إطلاقاً)، فلا تُشحن شيفرة الأدوار الأخرى في حزمة
// هذا التطبيق أصلاً (فصل على مستوى الحزمة، لا مجرد إخفاء في الواجهة).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'app_flavor.dart';
import 'crash_reporting.dart';
import 'navigator_key.dart';
import 'widgets/connectivity_banner.dart';
import 'widgets/min_version_gate.dart';
import 'models/models.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'providers/cart_provider.dart';
import 'providers/firebase_service.dart';
import 'screens/splash_screen.dart';
import 'screens/customer/customer_home.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'utils/theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyBuU7g3vG5enxaebwxGdGgavG5U8cftwd4',
      appId: '1:653081498334:android:4b14b35fde7540e220684f',
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
      appId: '1:653081498334:android:4b14b35fde7540e220684f',
      messagingSenderId: '653081498334',
      projectId: 'restaurant-app-ed699',
      storageBucket: 'restaurant-app-ed699.firebasestorage.app',
    ),
  );

  // تسجيل الانهيارات يُوصَّل **قبل** أي شيفرة أخرى بعد تهيئة Firebase:
  // ما ينهار في أثناء الإقلاع نفسه هو أعصى ما يُشخَّص بلا تقرير.
  await initCrashReporting(flavor: 'customer');

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  AppFlavorConfig.flavor = AppFlavor.customer;
  AppFlavorConfig.flavorLabel = 'العميل';
  AppFlavorConfig.flavorColor = const Color(0xFFD4A017);
  AppFlavorConfig.flavorIcon = Icons.shopping_bag_rounded;
  AppFlavorConfig.flavorTagline = 'أشهى المطاعم توصلك أينما كنت';
  AppFlavorConfig.flavorLoginTitle = 'تسجيل دخول العميل';
  AppFlavorConfig.restrictToRole = UserRole.customer;
  AppFlavorConfig.restrictedMessage = 'هذا التطبيق مخصص لحسابات العملاء فقط';
  AppFlavorConfig.allowGuestBrowsing = true;
  AppFlavorConfig.buildHomeForRole = (role) => const CustomerHome();
  AppFlavorConfig.buildLoginScreen = ({fromCheckout = false}) => LoginScreen(fromCheckout: fromCheckout);
  AppFlavorConfig.buildRegisterScreen = ({fromCheckout = false}) => RegisterScreen(fromCheckout: fromCheckout);
  AppFlavorConfig.buildRegisterWithCodeScreen = null;

  runApp(const CustomerApp());
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

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
        title: 'ZadGo عميل',
        debugShowCheckedModeBanner: false,
        // تعريب حوارات النظام (منتقيا التاريخ والوقت): كانت تظهر إنجليزية
        // («Select date» وأسبوع يبدأ الأحد الأمريكي) داخل تطبيق عربي
        // بالكامل — بلاغ المالك بالصور 2026-08-15. القفل على العربية
        // يجعلها عربية RTL بأيام وشهور عربية.
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: AppTheme.build(palette: FlavorPalette.customer),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          // بوابة الإصدار أولاً ثم شريط انقطاع الاتصال — نسخة محجوبة لا
          // معنى لعرض حالة شبكتها.
          child: MinVersionGate(child: ConnectivityBanner(child: child!)),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
