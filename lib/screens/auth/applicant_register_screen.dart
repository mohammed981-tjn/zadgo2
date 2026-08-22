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
import '../../utils/app_lang.dart';
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
      showError(
          context, auth.error ?? tr('فشل إنشاء الحساب', "Couldn't create account"));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    return Scaffold(
      appBar: AppBar(
          title: Text(_isDriverFlavor
              ? tr('الانضمام ككابتن', 'Join as a captain')
              : tr('تسجيل مطعمك', 'Register your restaurant'))),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(
            _isDriverFlavor
                ? tr(
                    'أنشئ حسابك، ثم املأ نموذج الانضمام وارفع مستنداتك — '
                        'وتبدأ فور اعتماد الإدارة.',
                    'Create your account, fill in the application, and upload '
                        'your documents — you start as soon as you are approved.')
                : tr(
                    'أنشئ حسابك، ثم سجّل بيانات مطعمك ومستنداته — '
                        'ويظهر مطعمك للعملاء فور اعتماد الإدارة.',
                    "Create your account, then register your restaurant's "
                        'details and documents — it goes live for customers '
                        'once approved.'),
            style: const TextStyle(fontSize: 13.5, color: AppColors.textGray),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _name,
            decoration: InputDecoration(labelText: tr('الاسم الكامل', 'Full name')),
            validator: (v) => validateRequired(v, tr('الاسم', 'Name')),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration:
                InputDecoration(labelText: tr('البريد الإلكتروني', 'Email')),
            validator: validateEmail,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration:
                InputDecoration(labelText: tr('رقم الجوال', 'Mobile number')),
            validator: validatePhone,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _pass,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: tr('كلمة المرور', 'Password'),
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
              child: Text(auth.loading
                  ? tr('ينشئ الحساب...', 'Creating account...')
                  : tr('إنشاء الحساب', 'Create account')),
            ),
          ),
        ]),
      ),
    );
  }
}
