// lib/screens/customer/onboarding_screen.dart
//
// الجولة التعريفية — تُعرض مرة واحدة فقط عند أول فتح لتطبيق العميل (نمط
// مأخوذ من قالب wasl ومُعاد بناؤه بهوية ZadGo): ثلاث شرائح تختصر وعد
// المنصة، بخلفية «ليل» العلامة وأيقونات متوهجة بلون النكهة — بلا أي أصول
// صور جديدة تُثقل التطبيق.
//
// «تخطّي» متاح دائماً من أول لحظة: الجولة تسويق لا حاجز.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';

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

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    (
      Icons.restaurant_menu_rounded,
      'مطاعمك المفضلة في مكان واحد',
      'تصفّح القوائم بالصور والأسعار والسعرات — واطلب بضغطات معدودة',
    ),
    (
      Icons.location_on_rounded,
      'تتبّع طلبك لحظة بلحظة',
      'من المطبخ إلى بابك: موقع السائق مباشرةً على الخريطة وإشعار عند كل خطوة',
    ),
    (
      Icons.account_balance_wallet_rounded,
      'ادفع كما يناسبك',
      'نقداً عند الاستلام، بالبطاقة، أو من رصيد محفظتك — والأسعار شاملة الضريبة بلا مفاجآت',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
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
                child: Text('تخطّي',
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
                  final (icon, title, text) = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // أيقونة متوهجة بأسلوب شعار شاشة الدخول نفسه —
                        // لغة بصرية واحدة عبر التطبيق.
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              fc.primary.withOpacity(0.25),
                              fc.primary.withOpacity(0.0),
                            ]),
                          ),
                          child: Center(
                            child: Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [fc.primaryLight, fc.primary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: fc.primary.withOpacity(0.5),
                                    blurRadius: 26,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(icon, color: fc.bgDarker, size: 52),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
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
                label: isLast ? 'ابدأ الطلب الآن' : 'التالي',
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
