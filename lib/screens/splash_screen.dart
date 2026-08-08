import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../models/models.dart';
import '../utils/theme.dart';
import '../app_flavor.dart';
import '../navigator_key.dart';
import 'customer/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _navigated = false;

  /// ظهور تدريجي مع تكبير طفيف للشعار — لمسة «حيّة» بلا انتظار إضافي:
  /// الحركة تجري ضمن ثانيتَي الانتظار القائمتين أصلاً.
  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  late final Animation<double> _scale =
      Tween(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: _anim, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    // كان الانتظار ثانيتين ثابتتين بلا تحميل فعلي خلفهما — ضريبة مجانية على
    // كل إطلاق (المنافسون أقل من ثانية). 1.2 ثانية تكفي لإتمام حركة الظهور
    // (700مل) ولمحة الهوية، ثم انتقال فوري.
    Future.delayed(const Duration(milliseconds: 1200), _navigate);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    final auth = context.read<app_auth.AuthProvider>();
    if (!auth.isLoggedIn) {
      // التسجيل المؤجل: زائر تطبيق العميل يدخل مباشرة لشاشة المطاعم دون أي
      // شاشة تسجيل دخول؛ التسجيل يُطلب فقط عند تأكيد الطلب لاحقاً. هذا لا
      // يتعارض مع القيد أدناه لأنه يعمل فقط حين لا يوجد مستخدم مسجَّل دخوله
      // أصلاً (حالة الزائر)، ولا يستدعي auth.logout() إطلاقاً.
      if (AppFlavorConfig.allowGuestBrowsing) {
        // الجولة التعريفية — للزائر الجديد في تطبيق العميل، مرة واحدة فقط.
        if (AppFlavorConfig.flavor == AppFlavor.customer &&
            !await OnboardingScreen.wasSeen()) {
          if (!mounted) return;
          _go(OnboardingScreen(
            onFinished: () => navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (_) =>
                      AppFlavorConfig.buildHomeForRole(UserRole.customer)),
              (_) => false,
            ),
          ));
          return;
        }
        _go(AppFlavorConfig.buildHomeForRole(UserRole.customer));
        return;
      }
      _go(AppFlavorConfig.buildLoginScreen());
      return;
    }
    final restrict = AppFlavorConfig.restrictToRole;
    if (restrict != null && auth.user!.role != restrict) {
      auth.logout();
      _go(AppFlavorConfig.buildLoginScreen());
      return;
    }
    _go(AppFlavorConfig.buildHomeForRole(auth.user!.role));
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => screen), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final label = AppFlavorConfig.flavorLabel;
    final fc = context.flavorColors;

    // تطبيق العميل — واجهة الجمهور — يفتح ببوستر العلامة الكامل (الشعار
    // والسائق والعبارة التسويقية) ملء الشاشة، فيبدو كتطبيقات التوصيل
    // الكبرى من أول لحظة. بقية النكهات أدوات عمل داخلية، فتكتفي بالشعار
    // الكتابي على «ليل» هويتها — أسرع وأقل تشتيتاً لمن يفتحها عشرات
    // المرات يومياً.
    if (AppFlavorConfig.flavor == AppFlavor.customer) {
      return Scaffold(
        body: FadeTransition(
          opacity: _fade,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF0E1B33),
            child: Image.asset(
              'assets/images/splash_customer.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      // خلفية البداية بهوية النكهة: تدرّج شعاعي من "ليل" النكهة الفاتح نسبياً
      // في المركز إلى الأغمق في الأطراف.
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1.3,
            colors: [fc.bgDark, fc.bgDarker],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // الشعار الكتابي الرسمي بخلفية شفافة — يتوافق مع أي «ليل»
                  // نكهة، بدل الشعار المربع ذي الخلفية الكحلية المثبتة.
                  Image.asset(
                    'assets/images/logo_wordmark.png',
                    width: screenWidth * 0.62,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppFlavorConfig.flavorTagline,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.white.withOpacity(0.6),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (label != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [fc.primary, fc.primaryDark],
                          begin: AlignmentDirectional.centerStart,
                          end: AlignmentDirectional.centerEnd,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: fc.primary.withOpacity(0.5),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(AppFlavorConfig.flavorIcon, color: fc.onPrimary, size: 17),
                          const SizedBox(width: 7),
                          Text(
                            label,
                            style: TextStyle(
                              color: fc.onPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
