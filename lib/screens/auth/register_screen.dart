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
import '../../app_flavor.dart';
import '../../utils/app_lang.dart';

class RegisterScreen extends StatefulWidget {
  /// عند تفعيلها (التسجيل أثناء إتمام الطلب كزائر) تُغلق الشاشة بعد نجاح
  /// التسجيل بدل الانتقال للرئيسية، ليستكمل المستدعي (شاشة السلة) الطلب من
  /// نفس النقطة دون فقدان السلة أو العودة للرئيسية.
  final bool fromCheckout;
  const RegisterScreen({super.key, this.fromCheckout = false});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  bool _obscure = true;

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<app_auth.AuthProvider>();
    final ok = await auth.register(name: _nameCtrl.text, email: _emailCtrl.text,
        password: _passCtrl.text, phone: _phoneCtrl.text, role: UserRole.customer,
        referredByCode: _refCtrl.text);
    if (!mounted) return;
    if (ok) {
      if (widget.fromCheckout) {
        Navigator.pop(context, true);
        return;
      }
      Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (_) => AppFlavorConfig.buildHomeForRole(UserRole.customer)), (_) => false);
    } else {
      showError(context, auth.error ?? tr('فشل التسجيل', 'Registration failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('حساب جديد', 'New account'))),
      body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
        TextFormField(controller: _nameCtrl,
            decoration: InputDecoration(labelText: tr('الاسم الكامل', 'Full name'), prefixIcon: const Icon(Icons.person_outline)),
            validator: (v) => validateRequired(v, tr('الاسم', 'Name'))),
        const SizedBox(height: 14),
        TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: tr('البريد الإلكتروني', 'Email'), prefixIcon: const Icon(Icons.email_outlined)),
            validator: validateEmail),
        const SizedBox(height: 14),
        TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: tr('رقم الهاتف', 'Phone number'), prefixIcon: const Icon(Icons.phone_outlined)),
            validator: validatePhone),
        const SizedBox(height: 14),
        TextFormField(controller: _passCtrl, obscureText: _obscure, textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: tr('كلمة المرور', 'Password'), prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure))),
            validator: validatePassword),
        const SizedBox(height: 14),
        // كود دعوة اختياريّ (إحالة العميل، دفعة ٥): من دُعي بكودٍ يكتبه هنا
        // فينال هو وداعيه مكافأةً حين يُكمل شرط الطلبات. اختياريّ فلا يعطّل من
        // سجّل بلا دعوة.
        TextFormField(controller: _refCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
                labelText: tr('كود دعوة (اختياري)', 'Invite code (optional)'),
                prefixIcon: const Icon(Icons.card_giftcard_outlined))),
        const SizedBox(height: 28),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: auth.loading ? null : _register,
            child: auth.loading ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(tr('إنشاء الحساب', 'Create account')))),
      ])),
    );
  }
}
