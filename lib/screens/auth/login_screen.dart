import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../models/models.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../admin/admin_home.dart';
import '../customer/customer_home.dart';
import '../driver/driver_home.dart';
import 'register_screen.dart';

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

  static const Color deepBlack = Color(0xFF000000);
  static const Color navyDark = Color(0xFF0F1B2E);
  static const Color zadgoYellow = Color(0xFFD4A017);

  void _navigate(UserRole role) {
    Widget dest;
    switch (role) {
      case UserRole.admin: dest = const AdminHome(); break;
      case UserRole.customer: dest = const CustomerHome(); break;
      case UserRole.driver: dest = const DriverHome(); break;
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // القسم العلوي - يأخذ 62% من المساحة المتاحة
            Expanded(
              flex: 62,
              child: Container(
                width: double.infinity,
                color: deepBlack,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Image.asset(
                    'assets/images/logo_square.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // القسم السفلي - يأخذ 38% الباقية، ويتمدد إن احتاج لوحة المفاتيح
            Expanded(
              flex: 38,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'تسجيل الدخول',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navyDark),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: const Icon(Icons.email_outlined, color: navyDark),
                            filled: true,
                            fillColor: const Color(0xFFF0F0F3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: validateEmail,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline, color: navyDark),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: navyDark,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF0F0F3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: validatePassword,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: zadgoYellow,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 3,
                              shadowColor: zadgoYellow.withOpacity(0.5),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: auth.loading ? null : _login,
                            child: Center(
                              child: auth.loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'دخول',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          ),
                          child: const Text(
                            'ليس لديك حساب؟ سجّل الآن',
                            style: TextStyle(color: navyDark, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}