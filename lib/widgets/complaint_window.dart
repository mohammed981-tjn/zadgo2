// lib/widgets/complaint_window.dart
//
// عدّاد حيّ لمهلة الشكوى على الطلبات المنتهية (٢٤ ساعة من لحظة الانتهاء).
//
// لماذا عدّاد لا نصّ ثابت: نصّ «متبقٍ ٣ ساعات» يُحسب لحظة بناء الشاشة ثم
// يتجمّد. من يترك الشاشة مفتوحة يرى رقماً كاذباً، والأسوأ أن الزر يبقى
// قابلاً للضغط بعد انقضاء المهلة لأن لا شيء يعيد بناءه — فيكتب العميل
// شكواه ثم تُرفض. هذا الودجت يعيد بناء نفسه دورياً، فينتهي الزر في لحظته.
//
// يُستخدم بصيغة builder ليخدم النكهات الثلاث بأشكالها المختلفة: زر عريض
// عند العميل، وأيقونة عند المطعم والسائق — بمنطق مهلة واحد لا ثلاثة.
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';

/// صياغة عربية سليمة للمدة المتبقية (مثنّى وجمع) — «ساعتان» لا «2 ساعة».
String formatRemaining(Duration left) {
  final hours = left.inHours;
  if (hours >= 1) {
    if (hours == 1) return 'ساعة واحدة';
    if (hours == 2) return 'ساعتان';
    if (hours <= 10) return '$hours ساعات';
    return '$hours ساعة';
  }
  final mins = left.inMinutes;
  if (mins <= 0) return 'أقل من دقيقة';
  if (mins == 1) return 'دقيقة واحدة';
  if (mins == 2) return 'دقيقتان';
  if (mins <= 10) return '$mins دقائق';
  return '$mins دقيقة';
}

class ComplaintWindow extends StatefulWidget {
  final Order order;

  /// [timeLeft] هي المتبقّي من المهلة، و`null` للطلبات الجارية (لا مهلة
  /// عليها أصلاً فتبقى الشكوى مفتوحة). [canSubmit] محسوبة لحظتها.
  final Widget Function(BuildContext context, Duration? timeLeft, bool canSubmit)
      builder;

  const ComplaintWindow({
    super.key,
    required this.order,
    required this.builder,
  });

  @override
  State<ComplaintWindow> createState() => _ComplaintWindowState();
}

class _ComplaintWindowState extends State<ComplaintWindow> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(ComplaintWindow old) {
    super.didUpdateWidget(old);
    // قد يتغيّر الطلب تحت نفس الودجت (تحديث من البثّ) — تُعاد الجدولة على
    // حالته الجديدة: طلبٌ انتهى للتوّ يبدأ عدّه، وطلبٌ انقضت مهلته يتوقف.
    if (old.order.id != widget.order.id ||
        old.order.status != widget.order.status) {
      _arm();
    }
  }

  /// دقّة العدّ بحسب ما يراه المستخدم: ما دام العرض بالساعات فدقيقةٌ كافية،
  /// وفي الساعة الأخيرة (عرض بالدقائق) يُشدَّد إلى ١٥ ثانية. وبعد الانقضاء
  /// يتوقف المؤقّت نهائياً — لا عدّ بلا فائدة في الخلفية.
  void _arm() {
    _ticker?.cancel();
    final left = widget.order.complaintTimeLeft;
    if (left == null || left <= Duration.zero) return;
    final period = left.inHours >= 1
        ? const Duration(minutes: 1)
        : const Duration(seconds: 15);
    _ticker = Timer.periodic(period, (_) {
      if (!mounted) return;
      final now = widget.order.complaintTimeLeft ?? Duration.zero;
      setState(() {});
      // الدخول في الساعة الأخيرة يستدعي دقّة أعلى، والانقضاء يُنهي العدّ.
      if (now <= Duration.zero || (now.inHours < 1 && period.inMinutes >= 1)) {
        _arm();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
        context,
        widget.order.complaintTimeLeft,
        widget.order.canSubmitComplaint,
      );
}
