// lib/screens/customer/onboarding_screen.dart
//
// الجولة التعريفية — تُعرض مرة واحدة فقط عند أول فتح لتطبيق العميل (نمط
// مأخوذ من قالب wasl ومُعاد بناؤه بهوية ZadGo): ثلاث شرائح تختصر وعد
// المنصة، لكل شريحة مشهد متحرك مرسوم بالكود (onboarding_scenes.dart) —
// بلا أي أصول صور جديدة تُثقل التطبيق (بند و١).
//
// «تخطّي» متاح دائماً من أول لحظة: الجولة تسويق لا حاجز.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/theme.dart';
import '../../utils/app_lang.dart';
import '../../widgets/common_widgets.dart';
import 'onboarding_scenes.dart';

class OnboardingScreen extends StatefulWidget {
  /// يُستدعى عند الانتهاء (إكمالاً أو تخطياً) — التنقل قرار المستدعي
  /// (شاشة البداية) لا هذه الشاشة، فتبقى قابلة لإعادة الاستخدام.
  final VoidCallback onFinished;
  const OnboardingScreen({super.key, required this.onFinished});

  /// مفتاح «شوهدت» — تغيير الرقم في نسخة مستقبلية يعيد عرض جولة جديدة
  /// لكل المستخدمين إن أردنا ذلك يوماً.
  static const _seenKey = 'onboarding_seen_v1';

  static Future<bool> wasSeen() async =>
      (await SharedPreferences.getInstance()).getBool(_seenKey) ?? false;

  static Future<void> markSeen() async =>
      (await SharedPreferences.getInstance()).setBool(_seenKey, true);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _controller = PageController();
  int _page = 0;

  /// نبض المشاهد: دورة كاملة كل ٨ ثوانٍ تتغذى منها حركات المشاهد الثلاثة
  /// كلها (دوران الأطباق، مسير الكابتن، تنفّس المحفظة) — محرك واحد
  /// مشترك أرخص من محرك لكل عنصر، وإيقاع موحّد أهدأ للعين.
  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(seconds: 8))
    ..repeat();

  // getter لا const: tr() تُقيَّم وقت التشغيل باللغة الحالية.
  static List<(String, String)> get _slides => [
        (
          tr('مطاعمك المفضلة في مكان واحد',
              'Your favorite restaurants in one place'),
          tr('تصفّح القوائم بالصور والأسعار والسعرات — واطلب بضغطات معدودة',
              'Browse menus with photos, prices, and calories — and order in a few taps'),
        ),
        (
          tr('تتبّع طلبك لحظة بلحظة', 'Track your order live'),
          tr('من المطبخ إلى بابك: موقع السائق مباشرةً على الخريطة وإشعار عند كل خطوة',
              'From the kitchen to your door: the driver\'s live location on the map and a notification at every step'),
        ),
        (
          tr('ادفع كما يناسبك', 'Pay your way'),
          tr('نقداً عند الاستلام، بالبطاقة، أو من رصيد محفظتك — والأسعار شاملة الضريبة بلا مفاجآت',
              'Cash on delivery, card, or your wallet balance — prices include tax, no surprises'),
        ),
      ];

  @override
  void dispose() {
    _controller.dispose();
    _loop.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingScreen.markSeen();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.flavorColors;
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.4,
            colors: [fc.bgDark, fc.bgDarker],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            Align(
              alignment: AlignmentDirectional.topStart,
              child: TextButton(
                onPressed: _finish,
                child: Text(tr('تخطّي', 'Skip'),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w600)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final (title, text) = _slides[i];
                  // دخول الشريحة: انزلاق صاعد مع ظهور — المفتاح برقمها
                  // فتُعاد الحركة عند كل عودة للشريحة لا أول مرة فقط.
                  return TweenAnimationBuilder<double>(
                    key: ValueKey(i),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    builder: (context, ent, child) => Opacity(
                      opacity: ent,
                      child: Transform.translate(
                          offset: Offset(0, 24 * (1 - ent)), child: child),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // مشهد الشريحة المتحرك — بديل الأيقونة الساكنة.
                          OnboardingScene(index: i, loop: _loop),
                          const SizedBox(height: 28),
                          Text(title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  height: 1.4)),
                          const SizedBox(height: 12),
                          Text(text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.65),
                                  fontSize: 14.5,
                                  height: 1.8)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // نقاط المؤشر
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? fc.primary : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: ZadGradientButton(
                label: isLast
                    ? tr('ابدأ الطلب الآن', 'Start ordering')
                    : tr('التالي', 'Next'),
                onPressed: () {
                  if (isLast) {
                    _finish();
                  } else {
                    _controller.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut);
                  }
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
