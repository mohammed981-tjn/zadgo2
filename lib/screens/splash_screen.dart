import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../models/models.dart';
import '../utils/theme.dart';
import '../app_flavor.dart';
import '../navigator_key.dart';
import '../widgets/z_mark.dart';
import 'customer/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _navigated = false;

  /// مشهد افتتاحي من ثلاث ثوانٍ يقوده محرّك واحد: الحرف يهبط وتمتد خطوط
  /// سرعته متعاقبة، فيظهر الشعار الكتابي، فالسطر التعريفي، فشارة النكهة،
  /// ثم لمعة تعبر الحرف. محرّك واحد لا سلسلة محرّكات: المراحل تتداخل
  /// زمنياً (Interval) فلا فجوة ميّتة بينها، ولا تسريب لو أُغلقت الشاشة
  /// في منتصف المشهد.
  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3000))
    ..forward();

  late final Animation<double> _mark = CurvedAnimation(
      parent: _anim, curve: const Interval(0.0, 0.62, curve: Curves.linear));
  late final Animation<double> _word = CurvedAnimation(
      parent: _anim, curve: const Interval(0.18, 0.42, curve: Curves.easeOut));
  late final Animation<double> _tagline = CurvedAnimation(
      parent: _anim, curve: const Interval(0.32, 0.52, curve: Curves.easeOut));
  late final Animation<double> _badge = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.45, 0.68, curve: Curves.easeOutBack));
  // «كن بيرنز» لبوستر العميل: تقريب بطيء يمتد الثواني الثلاث كلها —
  // صورة ثابتة ٣ ثوانٍ تُحسّ جموداً، وتقريبٌ محسوس يُحسّ رخصاً.
  late final Animation<double> _posterZoom = Tween(begin: 1.0, end: 1.06)
      .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
  late final Animation<double> _posterFade = CurvedAnimation(
      parent: _anim, curve: const Interval(0.0, 0.22, curve: Curves.easeOut));

  /// هل تجاوزنا مشهد الثواني الثلاث وما زلنا ننتظر حكم المصادقة؟ يُظهر
  /// مؤشراً صغيراً كي لا تبدو الشاشة معلّقة على شبكة بطيئة.
  bool _waitingAuth = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  /// ثلاث ثوانٍ بقرار صريح من المالك (٢٠٢٦-٠٨-١٠) عدولاً عن قرار 1.2ث
  /// السابق: لحظة العلامة أهم عنده من سرعة الإقلاع، والمدة الآن مشغولة
  /// بمشهد متحرّك لا انتظاراً فارغاً كما كانت عليه في عهد الثانيتين.
  ///
  /// لكنّ المهلة الثابتة وحدها كانت العلّة الخفية وراء «يطلب تسجيل الدخول
  /// كل مرة»: استعادة الجلسة تحتاج جلب ملف المستخدم عبر الشبكة، وقد تتأخر
  /// عن الثواني الثلاث فيُحكم على صاحب جلسة سليمة بأنه زائر. فالانتقال
  /// الآن ينتظر الشرطين معاً: اكتمال المشهد **و**حكم المصادقة الفعلي —
  /// بسقف ١٢ ثانية يمنع التعليق الأبدي لو انقطعت الشبكة كلياً.
  Future<void> _start() async {
    final auth = context.read<app_auth.AuthProvider>();
    final scene = Future.delayed(const Duration(milliseconds: 3000));
    await scene;
    if (mounted && !_navigated) setState(() => _waitingAuth = true);
    await auth.onAuthResolved
        .timeout(const Duration(seconds: 12), onTimeout: () {});
    _navigate();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    final auth = context.read<app_auth.AuthProvider>();
    if (!auth.isLoggedIn) {
      // التسجيل المؤجل: زائر تطبيق العميل يدخل مباشرة لشاشة المطاعم دون أي
      // شاشة تسجيل دخول؛ التسجيل يُطلب فقط عند تأكيد الطلب لاحقاً. هذا لا
      // يتعارض مع القيد أدناه لأنه يعمل فقط حين لا يوجد مستخدم مسجَّل دخوله
      // أصلاً (حالة الزائر)، ولا يستدعي auth.logout() إطلاقاً.
      if (AppFlavorConfig.allowGuestBrowsing) {
        // الجولة التعريفية — للزائر الجديد في تطبيق العميل، مرة واحدة فقط.
        if (AppFlavorConfig.flavor == AppFlavor.customer &&
            !await OnboardingScreen.wasSeen()) {
          if (!mounted) return;
          _go(OnboardingScreen(
            onFinished: () => navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (_) =>
                      AppFlavorConfig.buildHomeForRole(UserRole.customer)),
              (_) => false,
            ),
          ));
          return;
        }
        _go(AppFlavorConfig.buildHomeForRole(UserRole.customer));
        return;
      }
      _go(AppFlavorConfig.buildLoginScreen());
      return;
    }
    if (!AppFlavorConfig.roleAllowed(auth.user!.role)) {
      // حساب «عميل» في نكهة مقيّدة = متقدّم انضمام في الطريق (أنشأ حسابه
      // من زر «انضم من هنا») — يعود لبوابة التقديم/الانتظار لا للطرد،
      // فإغلاق التطبيق وفتحه لا يضيّع طلبه. (نكهتا الكابتن والمطعم فقط.)
      final gate = AppFlavorConfig.buildApplicantGate;
      if (gate != null && auth.user!.role == UserRole.customer) {
        _go(gate());
        return;
      }
      auth.logout();
      _go(AppFlavorConfig.buildLoginScreen());
      return;
    }
    _go(AppFlavorConfig.buildHomeForRole(auth.user!.role));
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => screen), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final label = AppFlavorConfig.flavorLabel;
    final fc = context.flavorColors;

    // تطبيق العميل — واجهة الجمهور — يفتح ببوستر العلامة الكامل (الشعار
    // والسائق والعبارة التسويقية) ملء الشاشة، فيبدو كتطبيقات التوصيل
    // الكبرى من أول لحظة. بقية النكهات أدوات عمل داخلية، فتكتفي بالشعار
    // الكتابي على «ليل» هويتها — أسرع وأقل تشتيتاً لمن يفتحها عشرات
    // المرات يومياً.
    if (AppFlavorConfig.flavor == AppFlavor.customer) {
      // البوستر أُعيد تركيبه على نسبة الجوال (1242×2688) بدل نسبة المطبوعة
      // الأصلية (748×1286)، وذلك بعد بلاغ المالك ٢٠٢٦-٠٨-١٢ («صورة العميل
      // زبالة») — والعلّة كانت في **تركيبنا** لا في المطبوعة:
      //
      //   ١) شعارٌ مزدوج: المطبوعة تحمل «ZadGo» مخبوزاً في أعلاها، وكنّا
      //      نرسم فوقه `logo_wordmark.png` بإزاحة يسيرة — فيظهر شعارٌ
      //      شبحيّ خلف شعارٍ حقيقي، وهو ما يقرأه العين لطخةً لا هوية.
      //   ٢) تعتيمٌ ثقيل (92%) على أعلى الكادر كان لازماً لإقحام ذلك
      //      الشعار، فيطمس الشعار المخبوز نصف طمسٍ ويوحل الكحلي.
      //   ٣) قصٌّ جانبي: نسبة المطبوعة 0.58 ونسبة الجوال 0.46، فـcover
      //      كان يقتطع 13% من كل جانب — تذهب معها دبّوس الموقع وطرف
      //      الدرّاجة.
      //
      // الحلّ في الأصل لا في الشاشة: الشعار يُخبز مرة واحدة من ملفه
      // الشفّاف (تكبير 1.2× بدل 1.66×، فهو أحدّ لا أنعم)، والكحلي يُمدّ
      // من شريط المطبوعة نفسها فلا يظهر خطّ وصل. فلم يبقَ للشاشة إلا
      // عرضه كاملاً وتقريب «كن بيرنز» — ولا تعتيم ولا طبقة فوقه إطلاقاً.
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: fc.bgDarker,
          child: FadeTransition(
            opacity: _posterFade,
            child: Stack(fit: StackFit.expand, children: [
              ScaleTransition(
                scale: _posterZoom,
                child: Image.asset(
                  'assets/images/splash_customer.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              if (_waitingAuth) const _AuthWaitIndicator(),
            ]),
          ),
        ),
      );
    }

    // تطبيق الكابتن يفتح على خلفية «الطريق الليلي» بهويته الكحلية — منتصفها
    // داكن صافٍ فيبقى الشعار والعبارة بأعلى وضوح. بقية النكهات تدرّج شعاعي
    // من "ليل" النكهة الفاتح نسبياً في المركز إلى الأغمق في الأطراف.
    final isDriver = AppFlavorConfig.flavor == AppFlavor.driver;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: isDriver
              ? const DecorationImage(
                  image: AssetImage('assets/images/bg_splash_driver.jpg'),
                  fit: BoxFit.cover,
                )
              : null,
          gradient: isDriver
              ? null
              : RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 1.3,
                  colors: [fc.bgDark, fc.bgDarker],
                ),
        ),
        child: Stack(children: [
          if (_waitingAuth) const _AuthWaitIndicator(),
          Center(
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // الحرف أولاً وقبل الاسم — هو ما سيراه المستخدم في أيقونة
                // تطبيقه، فيرسّخ السبلاش الربط بينهما كل مرة. الحرف أبيض
                // وخطوط السرعة بلون النكهة: التلوين للهوية والحرف للوضوح.
                ZMark(
                  size: screenWidth * 0.40,
                  color: Colors.white,
                  trailColor: fc.primaryLight,
                  progress: _mark.value,
                ),
                const SizedBox(height: 18),
                // الشعار الكتابي الرسمي بخلفية شفافة — يتوافق مع أي «ليل»
                // نكهة، بدل الشعار المربع ذي الخلفية الكحلية المثبتة.
                // ينزلق صاعداً مع ظهوره فيبدو مدفوعاً من حركة الحرف فوقه.
                Opacity(
                  opacity: _word.value,
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - _word.value)),
                    child: Image.asset(
                      'assets/images/logo_wordmark.png',
                      width: screenWidth * 0.62,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Opacity(
                  opacity: _tagline.value,
                  child: Text(
                    AppFlavorConfig.flavorTagline,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.white.withOpacity(0.6),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                if (label != null)
                  Transform.scale(
                    scale: 0.6 + 0.4 * _badge.value,
                    child: Opacity(
                      opacity: _badge.value.clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [fc.primary, fc.primaryDark],
                            begin: AlignmentDirectional.centerStart,
                            end: AlignmentDirectional.centerEnd,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: fc.primary.withOpacity(0.5),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(AppFlavorConfig.flavorIcon,
                                color: fc.onPrimary, size: 17),
                            const SizedBox(width: 7),
                            Text(
                              label,
                              style: TextStyle(
                                color: fc.onPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        ]),
      ),
    );
  }
}

/// مؤشر «ما زلنا نستعيد جلستك» أسفل السبلاش — يظهر فقط إن امتد انتظار حكم
/// المصادقة بعد انتهاء المشهد، فلا تبدو الشاشة معلّقة بلا تفسير.
class _AuthWaitIndicator extends StatelessWidget {
  const _AuthWaitIndicator();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 48),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 10),
            Text('جارٍ استعادة جلستك…',
                style: TextStyle(
                    fontSize: 12.5, color: Colors.white.withOpacity(0.7))),
          ]),
        ),
      );
}
