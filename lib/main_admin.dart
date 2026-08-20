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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'app_flavor.dart';
import 'crash_reporting.dart';
import 'providers/app_check_service.dart';
import 'navigator_key.dart';
import 'widgets/connectivity_banner.dart';
import 'widgets/min_version_gate.dart';
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

  // تسجيل الانهيارات يُوصَّل **قبل** أي شيفرة أخرى بعد تهيئة Firebase:
  // ما ينهار في أثناء الإقلاع نفسه هو أعصى ما يُشخَّص بلا تقرير.
  await initCrashReporting(flavor: 'admin');

  // App Check شرط تشغيل الذكاء (فرضه على AI Logic لا يُعطَّل) — مزوّد
  // التصحيح لأن التوزيع مباشر لا عبر المتجر؛ التفصيل في app_check_service.
  // في تطبيق الإدارة وحده: الذكاء هنا فقط، ورموز التصحيح تُدار يدوياً.
  await AppCheckService.activateDebug();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  AppFlavorConfig.flavor = AppFlavor.admin;
  AppFlavorConfig.flavorLabel = 'المدير العام';
  AppFlavorConfig.flavorColor = const Color(0xFF5E35B1);
  AppFlavorConfig.flavorIcon = Icons.admin_panel_settings_rounded;
  AppFlavorConfig.flavorTagline = 'غرفة التحكم الكاملة لمنصتك';
  AppFlavorConfig.flavorLoginTitle = 'دخول المدير العام';
  AppFlavorConfig.restrictToRole = UserRole.admin;
  // موظف الدعم يدخل تطبيق الإدارة نفسه (لا تطبيق سادس): اللوحة تنكمش
  // له إلى الشكاوى والمتابعة وسجلّ الطلبات، والقواعد تحرس الباقي.
  AppFlavorConfig.extraAllowedRoles = {UserRole.support};
  AppFlavorConfig.restrictedMessage = 'هذا التطبيق مخصص لحسابات الإدارة والدعم فقط';
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
        scaffoldMessengerKey: messengerKey,
        // رسائل الشاشة السابقة تُمسح عند الدخول لشاشة جديدة.
        navigatorObservers: [ClearMessagesOnPush()],
        title: 'ZadGo إدارة',
        debugShowCheckedModeBanner: false,
        // تعريب حوارات النظام (منتقيا التاريخ والوقت): كانت تظهر إنجليزية
        // («Select date» وأسبوع يبدأ الأحد الأمريكي) داخل تطبيق عربي
        // بالكامل — بلاغ المالك بالصور 2026-08-15. القفل على العربية
        // يجعلها عربية RTL بأيام وشهور عربية.
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: AppTheme.build(palette: FlavorPalette.admin),
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