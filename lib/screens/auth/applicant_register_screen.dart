// lib/screens/auth/applicant_register_screen.dart
//
// إنشاء حساب متقدّم جديد (نكهتا الكابتن والمطعم) — الخطوة الأولى في مسار
// «سجّل من التطبيق»: الحساب يُنشأ بدور «عميل» (الدور الوحيد المتاح ذاتياً
// في القواعد، وبلا أي صلاحية)، ثم تفتح بوابة التقديم فيملأ النموذج ويرفع
// المستندات وينتظر الاعتماد — الذي يمنح حسابَه هذا دورَه الحقيقي.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_flavor.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/helpers.dart';
import '../../utils/theme.dart';
import 'application_gate_screen.dart';

class ApplicantRegisterScreen extends StatefulWidget {
  const ApplicantRegisterScreen({super.key});

  @override
  State<ApplicantRegisterScreen> createState() =>
      _ApplicantRegisterScreenState();
}

class _ApplicantRegisterScreenState extends State<ApplicantRegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;

  bool get _isDriverFlavor => AppFlavorConfig.flavor == AppFlavor.driver;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<app_auth.AuthProvider>();
    final ok = await auth.register(
      name: _name.text,
      email: _email.text,
      password: _pass.text,
      phone: _phone.text,
      role: UserRole.customer,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ApplicationGateScreen()),
        (_) => false,
      );
    } else {
      showError(context, auth.error ?? 'فشل إنشاء الحساب');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    return Scaffold(
      appBar: AppBar(
          title:
              Text(_isDriverFlavor ? 'الانضمام ككابتن' : 'تسجيل مطعمك')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(
            _isDriverFlavor
                ? 'أنشئ حسابك، ثم املأ نموذج الانضمام وارفع مستنداتك — '
                    'وتبدأ فور اعتماد الإدارة.'
                : 'أنشئ حسابك، ثم سجّل بيانات مطعمك ومستنداته — '
                    'ويظهر مطعمك للعملاء فور اعتماد الإدارة.',
            style: const TextStyle(fontSize: 13.5, color: AppColors.textGray),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'الاسم الكامل'),
            validator: (v) => validateRequired(v, 'الاسم'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration:
                const InputDecoration(labelText: 'البريد الإلكتروني'),
            validator: validateEmail,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'رقم الجوال'),
            validator: validatePhone,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _pass,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              suffixIcon: IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: validatePassword,
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: auth.loading ? null : _submit,
              child: Text(auth.loading ? 'ينشئ الحساب...' : 'إنشاء الحساب'),
            ),
          ),
        ]),
      ),
    );
  }
}
