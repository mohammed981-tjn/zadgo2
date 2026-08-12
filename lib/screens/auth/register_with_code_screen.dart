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
import '../../app_flavor.dart';

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
  final _referrerCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    for (final c in [
      _codeCtrl, _nameCtrl, _nationalIdCtrl,
      _emailCtrl, _phoneCtrl, _passCtrl, _referrerCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _navigate(UserRole role) {
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => AppFlavorConfig.buildHomeForRole(role)), (_) => false);
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
      referredByCode: _referrerCtrl.text,
      // النكهة المقيّدة بدور واحد (سائق/مطعم/أدمن) تقبل فقط أكواداً بنفس
      // الدور؛ النكهة الكاملة (restrictToRole == null) تقبل أي دور كما كان
      // الحال سابقاً.
      expectedRole: AppFlavorConfig.restrictToRole,
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
            'أدخل كود التسجيل الذي أرسله لك المدير العام لتفعيل حسابك تلقائياً.',
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
          // كود الداعي — للسائقين فقط، واختياري. يُثبَّت لحظة التسجيل ولا
          // يُعدَّل بعدها، فلا تُدّعى إحالة بأثر رجعي لسائق يعمل منذ شهور.
          if (AppFlavorConfig.restrictToRole == UserRole.driver ||
              AppFlavorConfig.restrictToRole == null) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _referrerCtrl,
              textDirection: TextDirection.ltr,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'كود الكابتن الذي دعاك (اختياري)',
                helperText: 'تناله وإياه مكافأة بعد إكمالك عدد التوصيلات المطلوب',
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.card_giftcard_outlined),
              ),
            ),
          ],
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
