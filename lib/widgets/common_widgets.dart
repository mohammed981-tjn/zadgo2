import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/theme.dart';

/// عرض موحّد لأخطاء StreamBuilder/FutureBuilder: رسالة عربية واضحة + زر
/// "إعادة المحاولة" + طباعة الخطأ التقني في الـ console للتشخيص.
///
/// يُستخدم في كل مكان بدل ترك `hasData == false` تتحول صمتاً إلى تحميل
/// لا ينتهي عند فشل الاتصال بـ Firestore.
class AppError extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;
  final String? message;
  const AppError({super.key, this.error, this.onRetry, this.message});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode && error != null) {
      debugPrint('AppError: $error');
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(
            message ?? 'حدث خطأ أثناء تحميل البيانات',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى',
            style: TextStyle(fontSize: 13, color: AppColors.textGray),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ]),
      ),
    );
  }
}

class AppLoading extends StatelessWidget {
  final String? message;
  const AppLoading({super.key, this.message});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const CircularProgressIndicator(color: AppColors.primary),
    if (message != null) ...[const SizedBox(height: 16), Text(message!)],
  ]));
}

/// غلاف موحّد حول [StreamBuilder] يفحص صراحة ثلاث حالات: خطأ، تحميل، بيانات.
/// عند الخطأ يعرض [AppError] مع زر "إعادة المحاولة" الذي يعيد إنشاء الـ
/// Stream فعلياً (لا مجرد rebuild بلا أثر)، ويطبع الخطأ التقني في الـ console.
///
/// يُستخدم بدل تكرار `StreamBuilder` + فحص `hasData` فقط في كل شاشة، وهو ما
/// كان يسبب تحوّل أخطاء Firestore إلى تحميل لا ينتهي أبداً.
class AppStreamBuilder<T> extends StatefulWidget {
  final Stream<T> Function() stream;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loading;

  const AppStreamBuilder({super.key, required this.stream, required this.builder, this.loading});

  @override
  State<AppStreamBuilder<T>> createState() => _AppStreamBuilderState<T>();
}

class _AppStreamBuilderState<T> extends State<AppStreamBuilder<T>> {
  late Stream<T> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.stream();
  }

  void _retry() => setState(() => _stream = widget.stream());

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return AppError(error: snap.error, onRetry: _retry);
        }
        if (!snap.hasData) {
          return widget.loading ?? const AppLoading();
        }
        return widget.builder(context, snap.data as T);
      },
    );
  }
}

/// غلاف موحّد حول [FutureBuilder] بنفس فلسفة [AppStreamBuilder]: فحص صريح
/// لثلاث حالات (خطأ/تحميل/بيانات) وإعادة محاولة فعلية تُعيد تنفيذ الـ Future.
class AppFutureBuilder<T> extends StatefulWidget {
  final Future<T> Function() future;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loading;

  const AppFutureBuilder({super.key, required this.future, required this.builder, this.loading});

  @override
  State<AppFutureBuilder<T>> createState() => _AppFutureBuilderState<T>();
}

class _AppFutureBuilderState<T> extends State<AppFutureBuilder<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.future();
  }

  void _retry() => setState(() => _future = widget.future());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return AppError(error: snap.error, onRetry: _retry);
        }
        if (snap.connectionState != ConnectionState.done) {
          return widget.loading ?? const AppLoading();
        }
        return widget.builder(context, snap.data as T);
      },
    );
  }
}

class AppEmpty extends StatelessWidget {
  final String emoji; final String title; final String? subtitle; final Widget? action;
  const AppEmpty({super.key, required this.emoji, required this.title, this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 64)),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      if (subtitle != null) ...[const SizedBox(height: 8), Text(subtitle!, textAlign: TextAlign.center)],
      if (action != null) ...[const SizedBox(height: 16), action!],
    ]),
  ));
}

class StatusBadge extends StatelessWidget {
  final String label; final Color color; final IconData? icon;
  const StatusBadge({super.key, required this.label, required this.color, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, color: color, size: 13), const SizedBox(width: 4)],
      Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}

class InfoRow extends StatelessWidget {
  final IconData icon; final String text; final bool bold;
  const InfoRow({super.key, required this.icon, required this.text, this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Icon(icon, size: 15, color: AppColors.textGray), const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(fontSize: 13,
          color: bold ? AppColors.textDark : AppColors.textGray,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
    ]));
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(width: 4, height: 20, color: AppColors.primary),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ]));
}

class PriceRow extends StatelessWidget {
  final String label; final String value; final bool bold;
  const PriceRow({super.key, required this.label, required this.value, this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: bold ? AppColors.primary : AppColors.textDark)),
    ]));
}

class BroadcastBanner extends StatelessWidget {
  final String title;
  final String body;
  const BroadcastBanner({super.key, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.campaign_outlined, color: AppColors.primary),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(body, style: const TextStyle(fontSize: 13)),
      ])),
    ]),
  );
}

/// خط تتبع الطلب (Stepper) بشكل نقاط متصلة بخط، على غرار تطبيقات مثل
/// دومينوز بيتزا ومايسترو بيتزا: يبيّن مرحلة الطلب الحالية ضمن مراحله الخمس:
/// تنفيذ الطلب ← استلام المطعم ← جاري التحضير ← تسليم المندوب ← توصيل الطلب.
class OrderTrackingTimeline extends StatelessWidget {
  final OrderStatus status;
  const OrderTrackingTimeline({super.key, required this.status});

  static const _steps = [
    _TimelineStep('تنفيذ الطلب', Icons.receipt_long_rounded),
    _TimelineStep('استلام المطعم', Icons.storefront_rounded),
    _TimelineStep('جاري التحضير', Icons.restaurant_rounded),
    _TimelineStep('تسليم المندوب', Icons.delivery_dining_rounded),
    _TimelineStep('توصيل الطلب', Icons.home_rounded),
  ];

  /// فهرس المرحلة الحالية ضمن المراحل الخمس، أو -1 إن كان الطلب ملغى/مرفوضاً.
  int get _activeIndex {
    switch (status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.confirmed:
        return 1;
      case OrderStatus.preparing:
      case OrderStatus.readyForPickup:
        return 2;
      case OrderStatus.outForDelivery:
        return 3;
      case OrderStatus.delivered:
        return 4;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeIndex;
    if (active < 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(children: [
        Row(
          children: List.generate(_steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              final lineDone = (i ~/ 2) < active;
              return Expanded(
                child: Container(
                  height: 3,
                  color: lineDone ? AppColors.primary : AppColors.primary.withOpacity(0.15),
                ),
              );
            }
            final idx = i ~/ 2;
            final done = idx < active;
            final isCurrent = idx == active;
            return Tooltip(
              message: _steps[idx].label,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? AppColors.primary : Colors.white,
                  border: Border.all(
                    color: (done || isCurrent) ? AppColors.primary : AppColors.primary.withOpacity(0.25),
                    width: 2,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                    : isCurrent
                        ? Icon(_steps[idx].icon, size: 13, color: AppColors.primary)
                        : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          _steps[active].label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
        ),
      ]),
    );
  }
}

class _TimelineStep {
  final String label;
  final IconData icon;
  const _TimelineStep(this.label, this.icon);
}
