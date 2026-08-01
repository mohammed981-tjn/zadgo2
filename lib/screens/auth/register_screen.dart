// lib/screens/auth/register_screen.dart
//
// التسجيل الذاتي المفتوح — مخصص لحسابات "العميل" فقط. حسابات "مدير عام"
// و"سائق" و"مدير مطعم" أصبحت تتطلب رمز تسجيل صادراً من المدير العام
// (راجع register_with_code_screen.dart) لمنع أي شخص من إنشاء حساب حسّاس
// دون تحقق.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/helpers.dart';
import '../customer/customer_home.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<app_auth.AuthProvider>();
    final ok = await auth.register(name: _nameCtrl.text, email: _emailCtrl.text,
        password: _passCtrl.text, phone: _phoneCtrl.text, role: UserRole.customer);
    if (!mounted) return;
    if (ok) {
      Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (_) => const CustomerHome()), (_) => false);
    } else {
      showError(context, auth.error ?? 'فشل التسجيل');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('حساب جديد')),
      body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
        TextFormField(controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => validateRequired(v, 'الاسم')),
        const SizedBox(height: 14),
        TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
            validator: validateEmail),
        const SizedBox(height: 14),
        TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_outlined)),
            validator: validatePhone),
        const SizedBox(height: 14),
        TextFormField(controller: _passCtrl, obscureText: _obscure, textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: 'كلمة المرور', prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure))),
            validator: validatePassword),
        const SizedBox(height: 28),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: auth.loading ? null : _register,
            child: auth.loading ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('إنشاء الحساب'))),
      ])),
    );
  }
}
