import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../models/models.dart';
import 'auth/login_screen.dart';
import 'admin/admin_home.dart';
import 'customer/customer_home.dart';
import 'driver/driver_home.dart';
import 'restaurant/restaurant_home.dart';

class SplashScreen extends StatefulWidget {
  /// عند تفعيلها (تطبيق العميل المستقل) يُقصر التنقل التلقائي على حسابات
  /// العميل فقط؛ أي حساب آخر (إدارة/سائق/مطعم) يُسجَّل خروجه تلقائياً
  /// ويُعاد توجيهه لشاشة الدخول الخاصة بالعميل.
  final bool customerOnly;
  const SplashScreen({super.key, this.customerOnly = false});
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
      // يتعارض مع منطق customerOnly أدناه لأنه يعمل فقط حين لا يوجد مستخدم
      // مسجَّل دخوله أصلاً (حالة الزائر)، ولا يستدعي auth.logout() إطلاقاً.
      if (widget.customerOnly) {
        _go(const CustomerHome());
        return;
      }
      _go(LoginScreen(customerOnly: widget.customerOnly));
      return;
    }
    if (widget.customerOnly && auth.user!.role != UserRole.customer) {
      auth.logout();
      _go(LoginScreen(customerOnly: widget.customerOnly));
      return;
    }
    switch (auth.user!.role) {
      case UserRole.admin: _go(const AdminHome()); break;
      case UserRole.customer: _go(const CustomerHome()); break;
      case UserRole.driver: _go(const DriverHome()); break;
      case UserRole.restaurantManager: _go(const RestaurantHome()); break;
    }
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