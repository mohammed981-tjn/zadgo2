// lib/screens/auth/register_with_code_screen.dart
//
// تسجيل ذاتي بدور محدد (مدير عام / سائق / مدير مطعم) باستخدام كود تسجيل
// يُصدره المدير العام ويرسله يدوياً (واتساب/اتصال) للشخص المستهدف. يحدد
// الرمز نفسه الدور والمطعم المرتبط (إن وُجد) عبر Firestore — لا يوجد أي
// اختيار للدور أو المطعم هنا حتى لا يتمكن أي شخص من تسجيل حساب حسّاس
// (مدير عام/سائق/مدير مطعم) دون رمز صحيح صادر مسبقاً.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../admin/admin_home.dart';
import '../customer/customer_home.dart';
import '../driver/driver_home.dart';
import '../restaurant/restaurant_home.dart';

class RegisterWithCodeScreen extends StatefulWidget {
  const RegisterWithCodeScreen({super.key});
  @override
  State<RegisterWithCodeScreen> createState() =>
      _RegisterWithCodeScreenState();
}

class _RegisterWithCodeScreenState extends State<RegisterWithCodeScreen> {
  final _form = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _nationalIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

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

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<app_auth.AuthProvider>();
    final ok = await auth.registerWithCode(
      code: _codeCtrl.text,
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passCtrl.text,
      phone: _phoneCtrl.text,
      nationalId: _nationalIdCtrl.text,
    );
    if (!mounted) return;
    if (ok && auth.user != null) {
      _navigate(auth.user!.role);
    } else {
      showError(context, auth.error ?? 'فشل التسجيل');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل بكود التسجيل')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text(
            'أدخل كود التسجيل الذي أرسله لك المدير العام (مدير عام / سائق / مدير مطعم) '
            'لتفعيل حسابك تلقائياً بالدور والمطعم المرتبطين به.',
            style: TextStyle(color: AppColors.textGray, fontSize: 13),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _codeCtrl,
            textDirection: TextDirection.ltr,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
                labelText: 'كود التسجيل', prefixIcon: Icon(Icons.vpn_key_outlined)),
            validator: (v) => validateRequired(v, 'كود التسجيل'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
                labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => validateRequired(v, 'الاسم'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _nationalIdCtrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
                labelText: 'رقم الإقامة / الهوية', prefixIcon: Icon(Icons.badge_outlined)),
            validator: (v) => validateRequired(v, 'رقم الإقامة/الهوية'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
            validator: validateEmail,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_outlined)),
            validator: validatePhone,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscure,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: validatePassword,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: auth.loading ? null : _submit,
              child: auth.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('تفعيل الحساب'),
            ),
          ),
        ]),
      ),
    );
  }
}
