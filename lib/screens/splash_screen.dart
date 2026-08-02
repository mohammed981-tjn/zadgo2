import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../models/models.dart';
import '../app_flavor.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), _navigate);
  }

  void _navigate() {
    if (_navigated || !mounted) return;
    _navigated = true;
    final auth = context.read<app_auth.AuthProvider>();
    if (!auth.isLoggedIn) {
      // التسجيل المؤجل: زائر تطبيق العميل يدخل مباشرة لشاشة المطاعم دون أي
      // شاشة تسجيل دخول؛ التسجيل يُطلب فقط عند تأكيد الطلب لاحقاً. هذا لا
      // يتعارض مع القيد أدناه لأنه يعمل فقط حين لا يوجد مستخدم مسجَّل دخوله
      // أصلاً (حالة الزائر)، ولا يستدعي auth.logout() إطلاقاً.
      if (AppFlavorConfig.allowGuestBrowsing) {
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
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF040E1A),
      body: Center(
        child: SizedBox(
          width: screenWidth * 0.75,
          height: screenHeight * 0.75,
          child: Image.asset(
            'assets/images/logo_square.png',
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}
