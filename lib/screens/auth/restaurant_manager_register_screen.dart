// lib/screens/auth/restaurant_manager_register_screen.dart
//
// تسجيل ذاتي لمدير مطعم باستخدام رمز تسجيل يُصدره المدير العام ويرسله
// يدوياً (واتساب/اتصال) لمدير المطعم. يتحقق الرمز عبر Firestore ويربط
// الحساب الجديد تلقائياً بالمطعم صاحب الرمز — لا يوجد اختيار مطعم يدوي هنا
// حتى لا يتمكن أي شخص من تسجيل حساب مدير مطعم دون رمز صحيح.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../restaurant/restaurant_home.dart';

class RestaurantManagerRegisterScreen extends StatefulWidget {
  const RestaurantManagerRegisterScreen({super.key});
  @override
  State<RestaurantManagerRegisterScreen> createState() =>
      _RestaurantManagerRegisterScreenState();
}

class _RestaurantManagerRegisterScreenState
    extends State<RestaurantManagerRegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<app_auth.AuthProvider>();
    final ok = await auth.registerRestaurantManagerWithCode(
      code: _codeCtrl.text,
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passCtrl.text,
      phone: _phoneCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (_) => const RestaurantHome()), (_) => false);
    } else {
      showError(context, auth.error ?? 'فشل التسجيل');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل مدير مطعم برمز التسجيل')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text(
            'أدخل رمز التسجيل الذي أرسله لك المدير العام لربط حسابك بمطعمك تلقائياً.',
            style: TextStyle(color: AppColors.textGray, fontSize: 13),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _codeCtrl,
            textDirection: TextDirection.ltr,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
                labelText: 'رمز التسجيل', prefixIcon: Icon(Icons.vpn_key_outlined)),
            validator: (v) => validateRequired(v, 'رمز التسجيل'),
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
            height: 52,
            child: ElevatedButton(
              onPressed: auth.loading ? null : _submit,
              child: auth.loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('تفعيل الحساب'),
            ),
          ),
        ]),
      ),
    );
  }
}
