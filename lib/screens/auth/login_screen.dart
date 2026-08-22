import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../models/models.dart';
import '../../utils/helpers.dart';
import '../../utils/theme.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/common_widgets.dart';
import '../../app_flavor.dart';
import '../../utils/app_lang.dart';
import 'applicant_register_screen.dart';
import 'application_gate_screen.dart';

/// شاشة تسجيل الدخول الموحّدة الكود، المتمايزة الهوية: كل نكهة (عميل/سائق/
/// مطعم/مدير) تظهر بخلفيتها الداكنة الخاصة، وأيقونتها، وعنوانها، وزر دخول
/// متدرّج بلونها — عبر [FlavorColorsExtension] و[AppFlavorConfig] فقط،
/// دون أي استيراد لشاشات الأدوار (الفصل على مستوى الحزمة محفوظ كما هو).
class LoginScreen extends StatefulWidget {
  /// عند تفعيلها (الدخول أثناء إتمام الطلب كزائر) تُغلق الشاشة بعد نجاح
  /// الدخول بدل الانتقال للرئيسية، ليستكمل المستدعي (شاشة السلة) الطلب من
  /// نفس النقطة دون فقدان السلة أو العودة للرئيسية.
  final bool fromCheckout;
  const LoginScreen({super.key, this.fromCheckout = false});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _navigate(UserRole role) {
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => AppFlavorConfig.buildHomeForRole(role)), (_) => false);
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<app_auth.AuthProvider>();
    final ok = await auth.login(_emailCtrl.text, _passCtrl.text);
    if (!mounted) return;
    if (ok && auth.user != null) {
      // إغلاق سياق التعبئة التلقائية بعد نجاح الدخول هو ما يدفع مدير كلمات
      // المرور (Google وغيره) لعرض «حفظ كلمة المرور؟» — بدونه كان السائق
      // يعيد كتابتها في كل مرة (شكوى المالك ٢٠٢٦-٠٨-١١).
      TextInput.finishAutofillContext();
      if (!AppFlavorConfig.roleAllowed(auth.user!.role)) {
        // حساب «عميل» في نكهة مقيّدة متقدّمٌ في الطريق لا دخيل: إلى بوابة
        // التقديم/الانتظار (يكمل نموذجه أو يتابع حالة طلبه) بدل الطرد.
        if (AppFlavorConfig.buildApplicantGate != null &&
            auth.user!.role == UserRole.customer) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const ApplicationGateScreen()),
            (_) => false,
          );
          return;
        }
        await auth.logout();
        if (!mounted) return;
        showError(
            context,
            tr(AppFlavorConfig.restrictedMessage,
                AppFlavorConfig.restrictedMessageEn));
        return;
      }
      if (widget.fromCheckout) {
        Navigator.pop(context, true);
        return;
      }
      _navigate(auth.user!.role);
    } else {
      showError(context, auth.error ?? tr('فشل تسجيل الدخول', 'Sign-in failed'));
    }
  }

  InputDecoration _fieldDecoration(String label, IconData icon, Color accent, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60, fontSize: 14.5),
      prefixIcon: Icon(icon, color: accent, size: 20),
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
        borderSide: BorderSide(color: accent, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    final fc = context.flavorColors;

    return Scaffold(
      body: AmbientBackground(
        bgDark: fc.bgDark,
        bgDarker: fc.bgDarker,
        accent: fc.primary,
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
                    const SizedBox(height: 8),
                    // تبديل اللغة قبل الدخول: أول شاشة يراها الجميع — من لا
                    // يقرأ العربية يجب أن يجد مخرجه هنا لا بعد تسجيلٍ لن
                    // يستطيع إتمامه.
                    const Align(
                      alignment: AlignmentDirectional.topEnd,
                      // onDark: الشاشة بخلفيتها الليلية — ألوان الحبّة تنقلب.
                      child: LanguageToggleButton(onDark: true),
                    ),
                    // الشعار المتوهّج — نفس القرص المستخدم في الجولة
                    // التعريفية بحلقاته ولمعته، بحجم أصغر: لغة بصرية واحدة
                    // بين أول شاشتين يراهما المستخدم.
                    GlowOrb(
                      size: 84,
                      primary: fc.primary,
                      primaryLight: fc.primaryLight,
                      child: Icon(
                        AppFlavorConfig.flavorIcon,
                        color: fc.bgDarker,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [fc.primaryLight, fc.primary],
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
                      tr(AppFlavorConfig.flavorTagline,
                          AppFlavorConfig.flavorTaglineEn),
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.white.withOpacity(0.55),
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (AppFlavorConfig.flavorLabel != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [fc.primary, fc.primaryDark],
                            begin: AlignmentDirectional.centerStart,
                            end: AlignmentDirectional.centerEnd,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: fc.primary.withOpacity(0.45),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(AppFlavorConfig.flavorIcon, color: fc.onPrimary, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              AppLang.en
                                  ? (AppFlavorConfig.flavorLabelEn ??
                                      AppFlavorConfig.flavorLabel!)
                                  : AppFlavorConfig.flavorLabel!,
                              style: TextStyle(
                                color: fc.onPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    // النموذج — نفس الخلفية الداكنة، حقول شفافة بلون النكهة.
                    // AutofillGroup + تلميحات الحقول = يعرض النظام كلمات
                    // المرور المحفوظة ويقترح حفظ الجديدة.
                    Form(
                      key: _form,
                      child: AutofillGroup(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              AppLang.en
                                  ? (AppFlavorConfig.flavorLoginTitleEn ??
                                      'Sign in')
                                  : (AppFlavorConfig.flavorLoginTitle ??
                                      'تسجيل الدخول'),
                              style: const TextStyle(
                                fontSize: 17,
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
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            style: const TextStyle(color: Colors.white),
                            decoration: _fieldDecoration(
                                tr('البريد الإلكتروني', 'Email'),
                                Icons.email_outlined,
                                fc.primaryLight),
                            validator: validateEmail,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            textDirection: TextDirection.ltr,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _login(),
                            style: const TextStyle(color: Colors.white),
                            decoration: _fieldDecoration(
                              tr('كلمة المرور', 'Password'),
                              Icons.lock_outline,
                              fc.primaryLight,
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
                          ZadGradientButton(
                            label: tr('دخول', 'Sign in'),
                            loading: auth.loading,
                            onPressed: auth.loading ? null : _login,
                          ),
                          const SizedBox(height: 18),
                          if (AppFlavorConfig.buildRegisterScreen != null)
                            Center(
                              child: TextButton(
                                onPressed: () async {
                                  final buildRegister = AppFlavorConfig.buildRegisterScreen!;
                                  final result = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => buildRegister(fromCheckout: widget.fromCheckout)),
                                  );
                                  if (widget.fromCheckout && result == true && context.mounted) {
                                    Navigator.pop(context, true);
                                  }
                                },
                                child: Text(
                                  tr('ليس لديك حساب؟ سجّل الآن',
                                      "Don't have an account? Sign up"),
                                  style: TextStyle(
                                    color: fc.primaryLight,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),
                          // مسار الانضمام الذاتي (نكهتا الكابتن والمطعم):
                          // حساب جديد ← نموذج ومستندات ← انتظار الاعتماد —
                          // المسار الرئيسي، وزر الكود يبقى أسفل منه للحالات
                          // اليدوية (كود من المدير مباشرة).
                          if (AppFlavorConfig.buildApplicantGate != null)
                            Center(
                              child: TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ApplicantRegisterScreen()),
                                ),
                                child: Text(
                                  AppFlavorConfig.flavor == AppFlavor.driver
                                      ? tr('كابتن جديد؟ انضم من هنا ✨',
                                          'New captain? Join here ✨')
                                      : tr('صاحب مطعم؟ سجّل مطعمك من هنا ✨',
                                          'Restaurant owner? Register here ✨'),
                                  style: TextStyle(
                                    color: fc.primaryLight,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),
                          if (AppFlavorConfig.buildRegisterWithCodeScreen != null)
                            Center(
                              child: TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => AppFlavorConfig.buildRegisterWithCodeScreen!()),
                                ),
                                child: Text(
                                  tr('لديك كود تسجيل؟ سجّل الآن',
                                      'Have a registration code? Sign up'),
                                  style: TextStyle(
                                    color: AppColors.silver.withOpacity(0.85),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )),
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
