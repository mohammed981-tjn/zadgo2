// lib/widgets/z_mark.dart
//
// حرف الـZ بخطوط السرعة — مرسوم بمضلّعات لا صورةً، فحوافه حادّة على أي
// دقة شاشة، ولونه يتبع هوية النكهة بلا أصول صور متعددة. نفس الهندسة التي
// يولّد بها tool/brand/make_icons.py أيقونات المشغّل (النسب منسوخة منه
// حرفياً)، فما يراه المستخدم في السبلاش هو ما يراه في أيقونة تطبيقه.
//
// [progress] يقود ثلاث مراحل داخل الرسّام نفسه بدل ثلاث حركات منفصلة في
// الشاشة: ظهور الحرف، فامتداد خطوط السرعة متعاقبةً، فلمعة تعبر الحرف.
import 'package:flutter/material.dart';

class ZMark extends StatelessWidget {
  final double size;
  final Color color;
  final Color trailColor;

  /// تقدّم الحركة 0..1 — مرّر 1.0 لعرض ساكن مكتمل.
  final double progress;

  const ZMark({
    super.key,
    required this.size,
    required this.color,
    Color? trailColor,
    this.progress = 1.0,
  }) : trailColor = trailColor ?? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _ZMarkPainter(
            color: color, trailColor: trailColor, progress: progress),
      );
}

class _ZMarkPainter extends CustomPainter {
  final Color color;
  final Color trailColor;
  final double progress;

  const _ZMarkPainter(
      {required this.color, required this.trailColor, required this.progress});

  // نسب الحرف — مطابقة لـmake_icons.py: سُمك الضلع 0.205 من الارتفاع،
  // عرض القطر 0.70، والميل 0.13 حول منتصف الارتفاع.
  static const _tb = 0.205, _dw = 0.70, _shear = 0.13;
  static const _tt = 0.062, _tg = 0.055; // سُمك خط السرعة والفجوة بينها
  static const _trailLens = [0.46, 0.34, 0.22];

  double _stage(double a, double b, [Curve curve = Curves.easeOutCubic]) {
    final t = ((progress - a) / (b - a)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height * 0.62;
    final w = h * 0.86;
    final cx = size.width / 2, cy = size.height / 2;
    final x0 = cx - w / 2, y0 = cy - h / 2;

    Offset p(double u, double v) =>
        Offset(x0 + (u + _shear * (0.5 - v)) * w, y0 + v * h);

    Path poly(List<Offset> pts) => Path()..addPolygon(pts, true);

    final zIn = _stage(0.0, 0.30, Curves.easeOutBack);
    if (zIn == 0) return;

    final z = poly([
      p(0, 0), p(1, 0), p(1, _tb), p(1 - _dw, 1 - _tb), p(1, 1 - _tb),
      p(1, 1), p(0, 1), p(0, 1 - _tb), p(_dw, _tb), p(0, _tb),
    ]);

    // خطوط السرعة تمتد من الحرف خارجاً واحداً بعد الآخر — الإحساس بالانطلاق
    // يصنعه التعاقب لا الامتداد نفسه.
    final trails = <Path>[];
    for (var i = 0; i < _trailLens.length; i++) {
      final ext = _stage(0.18 + i * 0.08, 0.44 + i * 0.08);
      if (ext == 0) continue;
      final ln = _trailLens[i] * ext;
      final vTop = _tb + _tg + i * (_tt + _tg);
      trails.add(poly([
        p(1.07, vTop), p(1.07 + ln, vTop),
        p(1.07 + ln, vTop + _tt), p(1.07, vTop + _tt),
      ]));
      final vBot = 1 - _tb - _tg - _tt - i * (_tt + _tg);
      trails.add(poly([
        p(-0.07, vBot), p(-0.07 - ln, vBot),
        p(-0.07 - ln, vBot + _tt), p(-0.07, vBot + _tt),
      ]));
    }

    // ظهور الحرف: تكبير من 0.85 حول مركزه مع الشفافية — «يهبط» في مكانه.
    // easeOutBack يتجاوز 1 عمداً (الارتداد)؛ يُترك للتكبير ويُقصّ للشفافية
    // التي ترمي assert خارج المدى 0..1.
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(0.85 + 0.15 * zIn);
    canvas.translate(-cx, -cy);

    final zo = zIn.clamp(0.0, 1.0);
    final fill = Paint()..color = color.withOpacity(zo);
    final trailFill = Paint()..color = trailColor.withOpacity(zo);
    // توهّج خفيف خلف الحرف يفصله عن الخلفية الداكنة — مكافئ ظلّ الأيقونة.
    final glow = Paint()
      ..color = Colors.black.withOpacity(0.35 * zo)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(z.shift(const Offset(2, 3)), glow);
    canvas.drawPath(z, fill);
    for (final t in trails) {
      canvas.drawPath(t, trailFill);
    }

    // اللمعة: شريط ضوئي مائل بميل الحرف نفسه يعبره مرة واحدة ثم يختفي —
    // تُقصّ على شكل الحرف فلا تلمس الخلفية.
    final shine = _stage(0.55, 0.95, Curves.easeInOut);
    if (shine > 0 && shine < 1) {
      canvas.save();
      canvas.clipPath(z);
      final sx = x0 - w * 0.8 + (w * 2.6) * shine;
      final band = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0),
            Colors.white.withOpacity(0.45),
            Colors.white.withOpacity(0),
          ],
        ).createShader(Rect.fromLTWH(sx, y0, w * 0.5, h))
        ..blendMode = BlendMode.plus;
      canvas.drawRect(
          Rect.fromLTWH(sx, y0 - h * 0.1, w * 0.5, h * 1.2), band);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ZMarkPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trailColor != trailColor;
}
