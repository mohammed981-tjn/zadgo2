import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../models/models.dart';
import 'auth/login_screen.dart';
import 'admin/admin_home.dart';
import 'customer/customer_home.dart';
import 'driver/driver_home.dart';

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
    switch (auth.user!.role) {
      case UserRole.admin: _go(const AdminHome()); break;
      case UserRole.customer: _go(const CustomerHome()); break;
      case UserRole.driver: _go(const DriverHome()); break;
    }
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => screen), (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SizedBox.expand(
      child: Image.asset(
        'assets/images/logo_square.png',
        fit: BoxFit.cover,
      ),
    ),
  );
}