// نقطة دخول مستقلة تماماً لتطبيق "السائق" (flavor: driver) — شجرة الاستيراد
// هنا تقتصر على DriverHome وشاشات التسجيل العامة (تسجيل الدخول/التفعيل
// برمز)؛ لا AdminHome ولا CustomerHome ولا RestaurantHome ولا شاشة التسجيل
// المفتوح (register_screen.dart، مخصصة للعملاء فقط). أي حساب ليس بدور سائق
// يُرفض ويُسجَّل خروجه تلقائياً.
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
import 'providers/firebase_service.dart';
import 'screens/splash_screen.dart';
import 'screens/driver/driver_home.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_with_code_screen.dart';
import 'screens/auth/application_gate_screen.dart';
import 'utils/theme.dart';
import 'utils/app_lang.dart';

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

  // تسجيل الانهيارات يُوصَّل **قبل** أي شيفرة أخرى بعد تهيئة Firebase:
  // ما ينهار في أثناء الإقلاع نفسه هو أعصى ما يُشخَّص بلا تقرير.
  await initCrashReporting(flavor: 'driver');

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  AppFlavorConfig.flavor = AppFlavor.driver;
  AppFlavorConfig.flavorLabel = 'السائق';
  AppFlavorConfig.flavorLabelEn = 'Captain';
  AppFlavorConfig.flavorColor = const Color(0xFF12559E);
  AppFlavorConfig.flavorIcon = Icons.two_wheeler_rounded;
  AppFlavorConfig.flavorTagline = 'انطلق، وصّل، واكسب';
  AppFlavorConfig.flavorTaglineEn = 'Drive, deliver, and earn';
  AppFlavorConfig.flavorLoginTitle = 'دخول الكباتن';
  AppFlavorConfig.flavorLoginTitleEn = 'Captain sign in';
  AppFlavorConfig.restrictToRole = UserRole.driver;
  AppFlavorConfig.restrictedMessage = 'هذا التطبيق مخصص لحسابات السائقين فقط';
  AppFlavorConfig.restrictedMessageEn = 'This app is for captain accounts only';
  AppFlavorConfig.allowGuestBrowsing = false;
  AppFlavorConfig.buildHomeForRole = (role) => const DriverHome();
  AppFlavorConfig.buildLoginScreen = ({fromCheckout = false}) => const LoginScreen();
  AppFlavorConfig.buildRegisterScreen = null;
  AppFlavorConfig.buildRegisterWithCodeScreen = () => const RegisterWithCodeScreen();
  // مسار الانضمام الذاتي: حساب ← نموذج ومستندات ← انتظار حيّ ← اعتماد
  // المدير يفتح التطبيق وحده. الكود القديم يبقى للحالات اليدوية.
  AppFlavorConfig.buildApplicantGate = () => const ApplicationGateScreen();

  // اللغة المحفوظة تُقرأ قبل runApp حتى يُرسم أول إطار بها مباشرةً.
  await AppLang.init();

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
        // مزوّد اللغة: التبديل يعيد بناء MaterialApp كله (لغةً واتجاهاً).
        ChangeNotifierProvider<AppLang>(create: (_) => AppLang()),
      ],
      child: Consumer<AppLang>(
        builder: (context, lang, _) => MaterialApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: messengerKey,
        // رسائل الشاشة السابقة تُمسح عند الدخول لشاشة جديدة.
        navigatorObservers: [ClearMessagesOnPush()],
        title: 'ZadGo سائق',
        debugShowCheckedModeBanner: false,
        // اللغة من مزوّدها (دفعة «اللغة الثانية»): العربية RTL أصلاً،
        // والإنجليزية LTR ثانيةً — حوارات النظام (منتقيا التاريخ والوقت)
        // تتبعها تلقائياً عبر supportedLocales.
        locale: lang.locale,
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: AppTheme.build(palette: FlavorPalette.driver),
        builder: (context, child) => Directionality(
          textDirection: lang.direction,
          // بوابة الإصدار أولاً ثم شريط انقطاع الاتصال — نسخة محجوبة لا
          // معنى لعرض حالة شبكتها.
          child: MinVersionGate(child: ConnectivityBanner(child: child!)),
        ),
        home: const SplashScreen(),
        ),
      ),
    );
  }
}
