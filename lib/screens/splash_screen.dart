import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../models/models.dart';
import 'auth/login_screen.dart';
import 'admin/admin_home.dart';
import 'customer/customer_home.dart';
import 'driver/driver_home.dart';
import 'restaurant/restaurant_manager_home.dart';

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
    if (!auth.isLoggedIn) { _go(const LoginScreen()); return; }
    final user = auth.user!;
    switch (user.role) {
      case UserRole.admin:
        _go(const AdminHome());
        break;
      case UserRole.customer:
        _go(const CustomerHome());
        break;
      case UserRole.driver:
        // Unapproved drivers land on the waiting screen instead of the main app.
        _go(user.isApproved ? const DriverHome() : const DriverPendingScreen());
        break;
      case UserRole.restaurantManager:
        _go(RestaurantManagerHome(restaurantId: user.restaurantId ?? ''));
        break;
    }
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => screen), (_) => false);
  }

  static const Color bgDark = Color(0xFF08201A);
  static const Color bgDarker = Color(0xFF040F0C);
  static const Color zadgoGreen = Color(0xFF12805F);
  static const Color zadgoGreenLight = Color(0xFF3FD69C);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.4,
            colors: [bgDark, bgDarker],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: screenWidth * 0.45,
                height: screenWidth * 0.45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      zadgoGreen.withOpacity(0.30),
                      zadgoGreen.withOpacity(0.0),
                    ],
                  ),
                ),
                child: Center(
                  child: SizedBox(
                    width: screenWidth * 0.32,
                    height: screenWidth * 0.32,
                    child: Image.asset(
                      'assets/images/logo_square.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [zadgoGreenLight, zadgoGreen],
                ).createShader(bounds),
                child: const Text(
                  'ZadGo',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(zadgoGreenLight.withOpacity(0.8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}