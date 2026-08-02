import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../admin/admin_home.dart';
import '../customer/customer_home.dart';
import '../driver/driver_home.dart';
import '../restaurant/restaurant_home.dart';
import 'register_screen.dart';
import 'register_with_code_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  static const Color bgDark = Color(0xFF08211A);
  static const Color bgDarker = Color(0xFF04120D);
  static const Color zadgoGold = Color(0xFFD4A017);
  static const Color zadgoGoldLight = Color(0xFFF0C550);
  static const Color zadgoSilver = Color(0xFFC7CFD6);

  void _navigate(UserRole role) {
    Widget dest;
    switch (role) {
      case UserRole.admin: dest = const AdminHome(); break;
      case UserRole.customer: dest = const CustomerHome(); break;
      case UserRole.driver: dest = const DriverHome(); break;
      case UserRole.restaurantManager: dest = const RestaurantHome(); break;
    }
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => dest), (_) => false);
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<app_auth.AuthProvider>();
    final ok = await auth.login(_emailCtrl.text, _passCtrl.text);
    if (!mounted) return;
    if (ok && auth.user != null) {
      _navigate(auth.user!.role);
    } else {
      showError(context, auth.error ?? 'فشل تسجيل الدخول');
    }
  }

  InputDecoration _fieldDecoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60, fontSize: 14),
      prefixIcon: Icon(icon, color: zadgoGold, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: zadgoGold, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.4,
            colors: [bgDark, bgDarker],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    // ✅ الشعار المصمم بالكود - أيقونة مع توهج ذهبي
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            zadgoGold.withOpacity(0.25),
                            zadgoGold.withOpacity(0.0),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [zadgoGoldLight, zadgoGold],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: zadgoGold.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.two_wheeler_rounded,
                            color: bgDarker,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [zadgoGoldLight, zadgoGold],
                      ).createShader(bounds),
                      child: const Text(
                        'ZadGo',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'كل احتياجاتك نوصلها لك',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.55),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // ✅ النموذج - نفس الخلفية الداكنة، حقول شفافة
                    Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'تسجيل الدخول',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(color: Colors.white),
                            decoration: _fieldDecoration('البريد الإلكتروني', Icons.email_outlined),
                            validator: validateEmail,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(color: Colors.white),
                            decoration: _fieldDecoration(
                              'كلمة المرور',
                              Icons.lock_outline,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: validatePassword,
                          ),
                          const SizedBox(height: 26),
                          SizedBox(
                            height: 50,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [zadgoGoldLight, zadgoGold],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: zadgoGold.withOpacity(0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: auth.loading ? null : _login,
                                  child: Center(
                                    child: auth.loading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              color: bgDarker,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'دخول',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: bgDarker,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              ),
                              child: Text(
                                'ليس لديك حساب؟ سجّل الآن',
                                style: TextStyle(
                                  color: zadgoGoldLight,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegisterWithCodeScreen()),
                              ),
                              child: Text(
                                'لديك كود تسجيل (مدير مطعم / سائق / مدير)؟ فعّل حسابك',
                                style: TextStyle(
                                  color: zadgoSilver.withOpacity(0.85),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}