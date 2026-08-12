// lib/screens/customer/onboarding_scenes.dart
//
// المشاهد المرسومة للجولة التعريفية — لكل شريحة «عالم» صغير متحرك بدل
// أيقونة في دائرة: أطباق تدور حول المطعم، سائق يقطع طريقاً على خريطة،
// محفظة تُخرج بطاقتها. كلها مرسومة بالكود (CustomPainter + عناصر مركّبة)
// بلا أي أصل صورة — التزاماً ببند و١ (لا خلفيات صور داخل الشاشات؛ البند
// وُضع أصلاً لصور فوتوغرافية تُثقل التطبيق وتشوّش نصوصه، والرسم البرمجي
// يلوَّن بهوية النكهة ويظل نصّه فوقه مقروءاً).
//
// [loop] محرك واحد يدور كل ٨ ثوانٍ تتغذى منه كل الحركات؛ الأطوار كلها
// دوال sin بمضاعفات صحيحة أو دورة كاملة لكل لفة، فلا «قفزة» عند التفاف
// العداد من ١ إلى ٠.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../widgets/z_mark.dart';

/// نقطتا الطريق في مشهد التتبع — نسبتان من مقاس المشهد، يشترك فيهما
/// الرسّام (يرسم الخط) والعناصر (تقف عليهما)، فلا ينفصل الدبوس عن طريقه.
const _storeAnchor = Offset(0.16, 0.74);
const _homeAnchor = Offset(0.84, 0.20);
const _routeC1 = Offset(0.45, 0.88);
const _routeC2 = Offset(0.45, 0.06);

Offset _bezier(Offset a, Offset b, Offset c, Offset d, double t) {
  final u = 1 - t;
  return a * (u * u * u) +
      b * (3 * u * u * t) +
      c * (3 * u * t * t) +
      d * (t * t * t);
}

class OnboardingScene extends StatelessWidget {
  final int index;
  final Animation<double> loop;
  const OnboardingScene({super.key, required this.index, required this.loop});

  @override
  Widget build(BuildContext context) {
    final fc = context.flavorColors;
    return SizedBox(
      height: 300,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, box) => AnimatedBuilder(
          animation: loop,
          builder: (context, _) {
            final t = loop.value;
            final w = box.maxWidth, h = box.maxHeight;
            return Stack(clipBehavior: Clip.none, children: [
              // ختم الحرف باهتاً في الزاوية — توقيع العلامة على كل مشهد،
              // نفس هندسة الأيقونة والسبلاش.
              PositionedDirectional(
                top: -18,
                end: -26,
                child: Opacity(
                  opacity: 0.05,
                  child: ZMark(size: 150, color: Colors.white, progress: 1),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _ScenePainter(
                      index: index,
                      loop: t,
                      gold: fc.primary,
                      goldLight: fc.primaryLight),
                ),
              ),
              ...switch (index) {
                0 => _restaurants(fc, w, h, t),
                1 => _tracking(fc, w, h, t),
                _ => _wallet(fc, w, h, t),
              },
            ]);
          },
        ),
      ),
    );
  }

  // ── المشهد ١: أطباق المطاعم تدور حول الطبق الرئيس ──
  List<Widget> _restaurants(FlavorColorsExtension fc, double w, double h, double t) {
    const sats = [
      (Icons.lunch_dining_rounded, 0.00),
      (Icons.local_pizza_rounded, 0.25),
      (Icons.local_cafe_rounded, 0.50),
      (Icons.icecream_rounded, 0.75),
    ];
    final r = math.min(w, h) * 0.40;
    return [
      Align(
        alignment: Alignment.center,
        child: _GlowDot(
            icon: Icons.restaurant_menu_rounded, size: 108, fc: fc),
      ),
      // الأقمار تُتم دورة كاملة كل لفة (٨ ثوانٍ) — أبطأ من أن تشتّت،
      // وأسرع من أن تبدو ساكنة.
      for (final (icon, phase) in sats)
        Positioned(
          left: w / 2 + r * math.cos(2 * math.pi * (t + phase)) - 23,
          top: h / 2 + r * math.sin(2 * math.pi * (t + phase)) - 23,
          child: _GlowDot(icon: icon, size: 46, fc: fc),
        ),
    ];
  }

  // ── المشهد ٢: الطريق من المطعم إلى البيت وكابتن يقطعه ──
  List<Widget> _tracking(FlavorColorsExtension fc, double w, double h, double t) {
    final pos = _bezier(
      Offset(_storeAnchor.dx * w, _storeAnchor.dy * h),
      Offset(_routeC1.dx * w, _routeC1.dy * h),
      Offset(_routeC2.dx * w, _routeC2.dy * h),
      Offset(_homeAnchor.dx * w, _homeAnchor.dy * h),
      Curves.easeInOut.transform(t),
    );
    return [
      Positioned(
        left: _storeAnchor.dx * w - 26,
        top: _storeAnchor.dy * h - 26,
        child: _GlowDot(icon: Icons.storefront_rounded, size: 52, fc: fc),
      ),
      Positioned(
        left: _homeAnchor.dx * w - 26,
        top: _homeAnchor.dy * h - 26,
        child: _GlowDot(icon: Icons.home_rounded, size: 52, fc: fc),
      ),
      Positioned(
        left: pos.dx - 19,
        top: pos.dy - 19,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: fc.primary.withOpacity(0.55),
                  blurRadius: 16,
                  spreadRadius: 2),
            ],
          ),
          child: Icon(Icons.two_wheeler_rounded,
              color: fc.bgDarker, size: 24),
        ),
      ),
    ];
  }

  // ── المشهد ٣: المحفظة تُخرج بطاقتها وطرق الدفع تحوم حولها ──
  List<Widget> _wallet(FlavorColorsExtension fc, double w, double h, double t) {
    double bob(double phase) => math.sin(2 * math.pi * (2 * t + phase)) * 5;
    return [
      Align(
        alignment: const Alignment(0, 0.12),
        child: SizedBox(
          width: 168,
          height: 150,
          child: Stack(alignment: Alignment.bottomCenter, children: [
            // البطاقة تطلّ من المحفظة وتغوص فيها — «الدفع جاهز دائماً».
            Positioned(
              bottom: 58 - bob(0) * 1.6,
              child: Container(
                width: 132,
                height: 78,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                      colors: [fc.primaryLight, fc.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                ),
                child: Stack(children: [
                  PositionedDirectional(
                    top: 12,
                    start: 14,
                    child: Container(
                      width: 26,
                      height: 18,
                      decoration: BoxDecoration(
                        color: fc.bgDarker.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            Container(
              width: 168,
              height: 92,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: fc.bgDark,
                border: Border.all(
                    color: fc.primary.withOpacity(0.75), width: 2),
                boxShadow: [
                  BoxShadow(
                      color: fc.primary.withOpacity(0.30),
                      blurRadius: 24,
                      spreadRadius: 2),
                ],
              ),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 14),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: fc.primary,
                        border: Border.all(color: fc.bgDarker, width: 3)),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
      // طرق الدفع الثلاث تحوم بأطوار متفاوتة — لكلٍّ نَفَسه الخاص.
      for (final (label, icon, align, phase) in [
        ('نقداً', Icons.payments_rounded, const Alignment(-0.92, -0.72), 0.0),
        ('بطاقة', Icons.credit_card_rounded, const Alignment(0.92, -0.86), 0.33),
        ('محفظة', Icons.account_balance_wallet_rounded,
            const Alignment(0.0, -1.0), 0.66),
      ])
        Align(
          alignment: align,
          child: Transform.translate(
            offset: Offset(0, bob(phase)),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: fc.bgDark.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: fc.primary.withOpacity(0.55)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: fc.primaryLight, size: 16),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
    ];
  }
}

/// دائرة متوهجة بأيقونة — نفس اللغة البصرية لشعار شاشة الدخول، مصغَّرة
/// ومعمَّمة كي تُبنى منها الأقمار والدبابيس.
class _GlowDot extends StatelessWidget {
  final IconData icon;
  final double size;
  final FlavorColorsExtension fc;
  const _GlowDot({required this.icon, required this.size, required this.fc});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
              colors: [fc.primaryLight, fc.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          boxShadow: [
            BoxShadow(
                color: fc.primary.withOpacity(0.45),
                blurRadius: size * 0.22,
                spreadRadius: 1),
          ],
        ),
        child: Icon(icon, color: fc.bgDarker, size: size * 0.5),
      );
}

/// خلفية المشهد وخطوطه: توهّج مركزي، نجيمات تومض، ثم عناصر كل مشهد
/// الخطّية (مدار الأقمار / شبكة الشوارع والطريق / شرارات المحفظة).
class _ScenePainter extends CustomPainter {
  final int index;
  final double loop;
  final Color gold;
  final Color goldLight;

  const _ScenePainter(
      {required this.index,
      required this.loop,
      required this.gold,
      required this.goldLight});

  // مواضع النجيمات ثابتة (لا Random) — العشوائية الحقيقية تُعيد رصّها كل
  // إطار فتُحسّ «غلياناً» لا وميضاً.
  static const _dots = [
    (0.08, 0.18, 0.0), (0.22, 0.06, 0.4), (0.90, 0.10, 0.2),
    (0.95, 0.55, 0.7), (0.05, 0.62, 0.5), (0.15, 0.90, 0.1),
    (0.85, 0.88, 0.6), (0.55, 0.04, 0.8), (0.35, 0.95, 0.3),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final center = Offset(w / 2, h / 2);

    // توهّج مركزي خافت يجمع المشهد.
    canvas.drawCircle(
        center,
        h * 0.75,
        Paint()
          ..shader = RadialGradient(colors: [
            gold.withOpacity(0.10),
            gold.withOpacity(0.0),
          ]).createShader(
              Rect.fromCircle(center: center, radius: h * 0.75)));

    for (final (fx, fy, phase) in _dots) {
      final tw = 0.35 + 0.65 *
          (0.5 + 0.5 * math.sin(2 * math.pi * (2 * loop + phase)));
      canvas.drawCircle(Offset(fx * w, fy * h), 1.6,
          Paint()..color = Colors.white.withOpacity(0.35 * tw));
    }

    switch (index) {
      case 0:
        _dashedCircle(canvas, center, math.min(w, h) * 0.40,
            Paint()
              ..color = gold.withOpacity(0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
      case 1:
        _streets(canvas, w, h);
        _route(canvas, w, h);
      default:
        _sparkles(canvas, w, h);
    }
  }

  void _dashedCircle(Canvas canvas, Offset c, double r, Paint p) {
    const seg = 14;
    for (var i = 0; i < seg; i++) {
      final a0 = 2 * math.pi * i / seg;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a0,
          2 * math.pi / seg * 0.55, false, p);
    }
  }

  void _streets(Canvas canvas, double w, double h) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;
    for (final fy in [0.25, 0.55, 0.85]) {
      canvas.drawLine(Offset(0, fy * h), Offset(w, fy * h), p);
    }
    for (final fx in [0.28, 0.62, 0.90]) {
      canvas.drawLine(Offset(fx * w, 0), Offset(fx * w, h), p);
    }
  }

  void _route(Canvas canvas, double w, double h) {
    final a = Offset(_storeAnchor.dx * w, _storeAnchor.dy * h);
    final b = Offset(_routeC1.dx * w, _routeC1.dy * h);
    final c = Offset(_routeC2.dx * w, _routeC2.dy * h);
    final d = Offset(_homeAnchor.dx * w, _homeAnchor.dy * h);
    final paint = Paint()
      ..color = goldLight.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    // شرطات على طول المنحنى بتقسيمه نقاطاً متقاربة — أدقّ من PathMetric
    // هنا لأننا نريد شرطات متساوية بصرياً على منحنى واحد فقط.
    const steps = 60;
    for (var i = 0; i < steps; i += 2) {
      final p0 = _bezier(a, b, c, d, i / steps);
      final p1 = _bezier(a, b, c, d, (i + 1) / steps);
      canvas.drawLine(p0, p1, paint);
    }
    // نبضة تتسع وتتلاشى حول موضع الكابتن الحالي.
    final t = Curves.easeInOut.transform(loop);
    final pos = _bezier(a, b, c, d, t);
    final pulse = (loop * 3) % 1;
    canvas.drawCircle(
        pos,
        19 + 22 * pulse,
        Paint()
          ..color = goldLight.withOpacity(0.35 * (1 - pulse))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  void _sparkles(Canvas canvas, double w, double h) {
    const stars = [(0.20, 0.30, 0.0), (0.80, 0.40, 0.5), (0.30, 0.72, 0.25)];
    for (final (fx, fy, phase) in stars) {
      final tw = 0.5 + 0.5 * math.sin(2 * math.pi * (2 * loop + phase));
      final c = Offset(fx * w, fy * h);
      final r = 5.0 + 3 * tw;
      final p = Paint()
        ..color = goldLight.withOpacity(0.25 + 0.5 * tw)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), p);
      canvas.drawLine(c - Offset(0, r), c + Offset(0, r), p);
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.loop != loop || old.index != index;
}
