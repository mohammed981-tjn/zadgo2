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
    // ملاحظة تشخيصية مؤقتة: كانت الطباعة سابقاً محصورة بوضع التطوير فقط
    // (kDebugMode)، فكانت أخطاء Firestore الحقيقية تختفي تماماً في نسخة
    // الإصدار (release) التي نختبرها على الجهاز. الآن تُطبع دائماً.
    debugPrint('AppError: $error');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
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

          // ===================================================================
          // كتلة تشخيص مؤقتة — تُحذف بعد معرفة سبب المشكلة
          // ===================================================================
          // تعرض نص الخطأ التقني القادم من Firestore مباشرة على الشاشة، لأن
          // الرسالة العربية العامة أعلاه تُخفي السبب الحقيقي. النص المتوقع
          // يحدد المشكلة فوراً:
          //   • PERMISSION_DENIED  → قواعد Firestore لم تُنشر بعد على المشروع
          //   • FAILED_PRECONDITION → الاستعلام يحتاج فهرساً مركّباً (index)
          //   • UNAVAILABLE        → مشكلة اتصال شبكة فعلية
          //   • أي خطأ تحويل بيانات → حقل في Firestore بنوع غير متوقع
          if (error != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تفاصيل تقنية (مؤقتة للتشخيص):',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // SelectableText يسمح بنسخ نص الخطأ ولصقه بدل تصويره.
                  SelectableText(
                    error.toString(),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // ===================== نهاية كتلة التشخيص ==========================

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

/// مؤشر تحميل موحّد مع رسالة اختيارية أسفله.
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
/// مهم عند الاستخدام: البارامتر [stream] نوعه `Stream<T> Function()` — أي
/// **دالة تُرجع Stream**، وليس Stream جاهزاً. لذلك يُمرَّر إما كـ
/// `stream: service.streamRestaurants` (بلا أقواس) أو
/// `stream: () => service.streamCategories(id)`. إضافة الأقواس مباشرة
/// (`service.streamRestaurants()`) خطأ يكسر التوقيع.
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
    // إنشاء الـ Stream مرة واحدة فقط عند بناء الودجت أول مرة، لا في كل rebuild.
    _stream = widget.stream();
  }

  /// إعادة محاولة حقيقية: تُنشئ Stream جديداً بالكامل بدل مجرد إعادة رسم.
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

/// حالة "لا توجد بيانات" — تُستخدم حين ينجح الجلب لكن النتيجة فارغة فعلاً،
/// وهي مختلفة تماماً عن حالة الخطأ ([AppError]).
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

/// شارة حالة ملوّنة (مفتوح/مغلق، حالة الطلب... إلخ).
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

/// سطر معلومة بأيقونة — يُستخدم في بطاقات الطلب وتفاصيله.
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

/// عنوان قسم بخط عمودي ملوّن على جانبه.
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

/// سطر سعر (المجموع/التوصيل/الضريبة/الإجمالي) مع إبراز اختياري للسطر النهائي.
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

/// شريط الرسائل الجماعية (البث) أعلى الشاشة الرئيسية.
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

/// خط تتبع الطلب (Stepper) بشكل نقاط متصلة بخط يوضح أين وصل الطلب ضمن
/// المسار العام: إنشاء الطلب ← قبول المطعم ← التحضير ← الاستلام/الإسناد ←
/// التوصيل.
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

  /// فهرس المرحلة الحالية ضمن المراحل الخمس، أو -1 إن كان الطلب منتهياً
  /// بحالة استثنائية (إلغاء/رفض/تعذر سائق/استرداد).
  int get _activeIndex {
    switch (status) {
      case OrderStatus.created:
      case OrderStatus.restaurantPending:
        return 0;
      case OrderStatus.restaurantAccepted:
        return 1;
      case OrderStatus.preparing:
        return 2;
      case OrderStatus.readyForPickup:
      case OrderStatus.searchingDriver:
      case OrderStatus.driverAssigned:
      case OrderStatus.pickedUp:
        return 3;
      case OrderStatus.onTheWay:
      case OrderStatus.delivered:
        return 4;
      case OrderStatus.restaurantRejected:
      case OrderStatus.noDriverFound:
      case OrderStatus.cancelled:
      case OrderStatus.refunded:
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
          // العناصر الفردية خطوط واصلة، والزوجية نقاط المراحل نفسها.
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