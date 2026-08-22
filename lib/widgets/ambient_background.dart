import 'dart:math' as math;
import 'package:flutter/material.dart';

/// خلفية «الليل الفاخر» المشتركة لشاشات ما قبل الدخول.
///
/// كانت هذه الشاشات تكتفي بتدرّج شعاعي واحد، فتبدو مسطّحة وفارغة. هنا نبني
/// عمقاً من أربع طبقات فوق بعضها:
///
///   ١. تدرّج شعاعي أساسي من «ليل» النكهة الفاتح في المركز إلى الأغمق.
///   ٢. هالتان لونيتان (ذهبية وخضراء) خارج الإطار جزئياً — تكسران الرتابة
///      وتوحيان باتساع المشهد بدل صندوق مغلق.
///   ٣. نسيج نقطي خفيف جداً يمنع التدرّج من الظهور شرائطَ لونية (banding)
///      على الشاشات الرخيصة، وهو عيب شائع في التدرّجات الداكنة.
///   ٤. تعتيم عند الأطراف (vignette) يدفع العين إلى المنتصف حيث النص.
///
/// كلها مرسومة بالكود: لا صور، لا أصول تُنزَّل، ولا وزن يُذكر على حجم التطبيق.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.bgDark,
    required this.bgDarker,
    required this.accent,
    this.child,
    this.glowShift = 0,
  });

  final Color bgDark;
  final Color bgDarker;
  final Color accent;
  final Widget? child;

  /// إزاحة أفقية للهالات من -1 إلى 1. تُربط بموضع الصفحة في الجولة
  /// التعريفية فتتحرّك الخلفية أبطأ من المحتوى — عمق بصري (parallax).
  final double glowShift;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 1.35,
          colors: [bgDark, bgDarker],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // الهالات والنسيج والتعتيم — طبقة رسم واحدة لتقليل كلفة التركيب.
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _AmbiencePainter(
                  accent: accent,
                  deep: bgDarker,
                  shift: glowShift,
                ),
              ),
            ),
          ),
          if (child != null) Positioned.fill(child: child!),
        ],
      ),
    );
  }
}

class _AmbiencePainter extends CustomPainter {
  _AmbiencePainter({
    required this.accent,
    required this.deep,
    required this.shift,
  });

  final Color accent;
  final Color deep;
  final double shift;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ١. هالة ذهبية أعلى اليمين، خارجة عن الإطار جزئياً.
    _glow(
      canvas,
      Offset(w * (0.86 - shift * 0.08), h * 0.12),
      w * 0.75,
      accent.withOpacity(0.16),
    );

    // ٢. هالة باردة أسفل اليسار — تباين لوني يمنع الأحادية مع بقاء
    //    الهوية. ت٢٢: كانت كحلية مبرمَجة (0xFF2A4E86) تخالف ليل ثلاث
    //    نكهات من أربع (قرميد المطعم وبنفسج الإدارة وأزرق الكابتن) فتخفق
    //    في غرضها المعلن عندها — الآن تُشتق من «ليل» النكهة نفسها
    //    بتفتيحه، فتبرد كل شاشة دخول بلون عائلتها.
    _glow(
      canvas,
      Offset(w * (0.10 - shift * 0.05), h * 0.82),
      w * 0.80,
      (Color.lerp(deep, Colors.white, 0.28) ?? deep).withOpacity(0.15),
    );

    // ٣. نسيج نقطي: يكسر تدرّج الألوان فلا يظهر شرائطَ على الشاشات الضعيفة.
    _dots(canvas, size);

    // ٤. تعتيم الأطراف.
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.98,
        colors: [Colors.transparent, deep.withOpacity(0.55)],
        stops: const [0.62, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  void _glow(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _dots(Canvas canvas, Size size) {
    const step = 26.0;
    final paint = Paint()..color = Colors.white.withOpacity(0.028);
    // بذرة ثابتة: النمط نفسه في كل إطار، فلا يهتزّ بين الرسمات.
    var seed = 7;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        final jitter = (seed % 100) / 100.0;
        if (jitter < 0.55) continue; // نقاط متفرّقة لا شبكة منتظمة
        final r = 0.7 + jitter * 0.8;
        canvas.drawCircle(
          Offset(x + math.sin(y) * 3, y + math.cos(x) * 3),
          r,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_AmbiencePainter old) =>
      old.accent != accent || old.deep != deep || old.shift != shift;
}

/// قرص متوهّج بطبقات — بديل القرص الذهبي المسطّح الذي كان يحمل الأيقونة.
///
/// ثلاث حلقات متحدة المركز: هالة خارجية واسعة، ثم حلقة زجاجية رفيعة، ثم
/// القرص الذهبي نفسه بتدرّج قطري وظلّ ملوّن. الفارق أن العين ترى عمقاً
/// وانتقالاً لونياً بدل دائرة صمّاء.
class GlowOrb extends StatelessWidget {
  const GlowOrb({
    super.key,
    required this.child,
    required this.primary,
    required this.primaryLight,
    this.size = 118,
  });

  final Widget child;
  final Color primary;
  final Color primaryLight;
  final double size;

  @override
  Widget build(BuildContext context) {
    final halo = size * 1.62;
    return SizedBox(
      width: halo,
      height: halo,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // هالة خارجية ناعمة
          Container(
            width: halo,
            height: halo,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primary.withOpacity(0.22),
                  primary.withOpacity(0.0),
                ],
                stops: const [0.35, 1.0],
              ),
            ),
          ),
          // حلقة زجاجية رفيعة
          Container(
            width: size * 1.24,
            height: size * 1.24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: primary.withOpacity(0.28),
                width: 1.2,
              ),
            ),
          ),
          // القرص الذهبي
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [primaryLight, primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.45),
                  blurRadius: 30,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(child: child),
          ),
          // لمعة علوية تعطي انطباع الحجم
          Positioned(
            top: (halo - size) / 2 + size * 0.10,
            child: Container(
              width: size * 0.52,
              height: size * 0.22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.30),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
