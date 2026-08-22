import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../utils/app_lang.dart';
import '../utils/theme.dart';

/// الزر الأساسي الموحّد للمنصة: تدرّج لوني بهوية النكهة الحالية + توهج ناعم
/// + حالة تحميل مدمجة. يُستخدم في شاشات الدخول والإجراءات الرئيسية بدل
/// تكرار DecoratedBox/InkWell يدوياً في كل شاشة.
class ZadGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final double height;
  const ZadGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final fc = context.flavorColors;
    final disabled = onPressed == null || loading;
    return Semantics(
      button: true,
      label: label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: disabled && !loading ? 0.55 : 1,
        child: SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [fc.primaryLight, fc.primary, fc.primaryDark],
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
              ),
              boxShadow: [
                BoxShadow(
                  color: fc.primary.withOpacity(0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: disabled ? null : onPressed,
                child: Center(
                  child: loading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: fc.onPrimary, strokeWidth: 2.4),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, color: fc.onPrimary, size: 20),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: fc.onPrimary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

  /// يستخرج رمز الخطأ المختصر من استثناءات Firebase — النمط المعتاد
  /// `[cloud_firestore/failed-precondition] ...` يُرجع منه
  /// `failed-precondition` — أو null إن لم يُتعرف على النمط.
  static String? _errorCode(Object? error) {
    if (error == null) return null;
    final match = RegExp(r'\[([\w./-]+)\]').firstMatch(error.toString());
    if (match == null) return null;
    final full = match.group(1)!;
    return full.contains('/') ? full.split('/').last : full;
  }

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
            message ??
                tr('حدث خطأ أثناء تحميل البيانات',
                    'Something went wrong while loading data'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // إرشاد بحسب نوع الخطأ لا نصيحة واحدة للجميع: «تحقق من اتصالك»
          // على خطأ صلاحيات (permission-denied) ضلّلت المالك فعلياً —
          // ظنّها انقطاع شبكة بينما السبب نسخة تطبيق أحدث من القواعد
          // المنشورة أو صلاحية ناقصة (ملاحظته 2026-08-22).
          Text(
            _errorCode(error) == 'permission-denied'
                ? tr('صلاحية مرفوضة — حدّث التطبيق لآخر نسخة، وإن استمرّ فأبلغ الإدارة',
                    'Permission denied — update the app to the latest version; if it persists, contact admin')
                : tr('تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى',
                    'Check your internet connection and try again'),
            style: const TextStyle(fontSize: 13.5, color: AppColors.textGray),
            textAlign: TextAlign.center,
          ),
          // رمز الخطأ المختصر يبقى ظاهراً حتى في نسخة الإصدار: سطر صغير مثل
          // «failed-precondition» يكفي للتشخيص عن بُعد من صورة شاشة، بينما
          // النص التقني الكامل (أدناه) محصور بوضع التطوير — بدونه كنا
          // سنفقد الطريقة التي شُخّص بها عطلا المحفظة والسجل فعلياً.
          if (_errorCode(error) != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                tr('رمز الخطأ: ${_errorCode(error)}',
                    'Error code: ${_errorCode(error)}'),
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
              ),
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
          //
          // [احترافية]: الكتلة الآن محصورة بوضع التطوير (kDebugMode) حتى لا
          // يرى المستخدم النهائي نصوص أخطاء تقنية بالإنجليزية في الإصدار.
          if (kDebugMode && error != null) ...[
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
                  Text(
                    tr('تفاصيل تقنية (مؤقتة للتشخيص):',
                        'Technical details (temporary, for diagnosis):'),
                    style: const TextStyle(
                      fontSize: 11.5,
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
                      fontSize: 11.5,
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
              label: Text(tr('إعادة المحاولة', 'Retry')),
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
    CircularProgressIndicator(color: context.flavorColors.primary),
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

  /// الإيموجي → أيقونة (دفعة ز2، ٢٠٢٦-٠٨-١٢): الإيموجي يُرسم بخط النظام
  /// فيختلف شكله بين أندرويد وآيفون وبين إصدارات أندرويد نفسها — وكان
  /// أوضح موضع «رخص» في التطبيق (٣٣ شاشة). الأيقونة تُرسم من خطّنا نحن،
  /// فتخرج واحدةً على كل جهاز وبلون الهوية.
  ///
  /// المعامل بقي `emoji` نصاً عمداً: تغييره لأيقونة يعني لمس ٣٣ موضع
  /// نداء، بينما الخريطة هنا تُغيّرها كلها من سطر واحد — وأي إيموجي جديد
  /// لم يُسجَّل بعدُ يسقط على أيقونة «صندوق فارغ» بدل أن يكسر شيئاً.
  static const Map<String, IconData> _icons = {
    '🛒': Icons.shopping_cart_outlined,
    '🍽️': Icons.restaurant_outlined,
    '🔍': Icons.search_off_rounded,
    '👤': Icons.person_outline_rounded,
    '👥': Icons.group_outlined,
    '⚠️': Icons.error_outline_rounded,
    '✅': Icons.check_circle_outline_rounded,
    '❓': Icons.help_outline_rounded,
    '📮': Icons.forum_outlined,
    '💬': Icons.chat_bubble_outline_rounded,
    '📢': Icons.campaign_outlined,
    '📊': Icons.insert_chart_outlined_rounded,
    '📋': Icons.assignment_outlined,
    '🧾': Icons.receipt_long_outlined,
    '🛵': Icons.delivery_dining_outlined,
    '🛰️': Icons.satellite_alt_outlined,
    '🎟️': Icons.confirmation_number_outlined,
    '💸': Icons.payments_outlined,
    '🔑': Icons.vpn_key_outlined,
    '🖼️': Icons.image_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final fc = context.flavorColors;
    final icon = _icons[emoji] ?? Icons.inbox_outlined;
    return Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // قرصان متداخلان بلون النكهة خلف الأيقونة — عمقٌ بصري رخيص يجعل
        // الحالة الفارغة تُقرأ «تصميماً مقصوداً» لا «شاشة لم تكتمل».
        Container(
          width: 108, height: 108,
          decoration: BoxDecoration(
            color: fc.primary.withOpacity(0.07),
            shape: BoxShape.circle,
          ),
          child: Center(child: Container(
            width: 78, height: 78,
            decoration: BoxDecoration(
              color: fc.primary.withOpacity(0.11),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 38, color: fc.primaryDark),
          )),
        ).animate().scale(
            begin: const Offset(0.82, 0.82), end: const Offset(1, 1),
            duration: 320.ms, curve: Curves.easeOutBack).fadeIn(duration: 220.ms),
        const SizedBox(height: 18),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textGray, height: 1.6)),
        ],
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]),
    ));
  }
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
      Text(label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
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
      Expanded(child: Text(text, style: TextStyle(fontSize: 13.5,
          color: bold ? AppColors.textDark : AppColors.textGray,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
    ]));
}

/// شارة حالة صغيرة: نص فوق خلفية بلون الحالة المخفَّف — تُستخدم لحالات
/// الشكاوى والطلبات حيث يلزم تمييز الحالة بلمحة لا بقراءة.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip({super.key, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.bold, color: color)),
      );
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
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
      // إجمالي السلة كحليّ لا ذهبيّ (دفعة ٤): الذهبي على خلفية السطر النهائي
      // الذهبية ~1.6:1 — أهمّ رقم في السلة لا يُقرأ. الكحلي على الفاتح ~15:1
      // ويحترم قرار الثيم (onPrimary=كحلي). حجمٌ أكبر قليلاً للسطر النهائي.
      Text(value, style: TextStyle(
          fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
          fontSize: bold ? 16 : null,
          color: bold ? AppColors.dark : AppColors.textDark)),
    ]));
}

/// شريط الرسائل الجماعية (البث) أعلى الشاشة الرئيسية.
///
/// قابلٌ للإخفاء مع تذكّر آخر رسالة أُخفيت (§7): سابقاً كان الشريط يلتصق
/// أعلى القائمة بلا زرّ إغلاق، فرسالةٌ طويلة تلتهم أعلى الشاشة في كل فتح
/// ولا سبيل لإزاحتها. الآن يحفظ الجهاز مُعرِّف آخر رسالة أخفاها صاحبه، فلا
/// تعود إلا حين تصل رسالةٌ **أحدث** بمعرّفٍ مختلف — تماماً كأشرطة الإشعار في
/// التطبيقات العالمية. (حدُّه: جهازٌ واحد، وهو المناسب لتنبيهٍ محلّي.)
class BroadcastBanner extends StatefulWidget {
  final String id;
  final String title;
  final String body;
  const BroadcastBanner(
      {super.key, required this.id, required this.title, required this.body});

  @override
  State<BroadcastBanner> createState() => _BroadcastBannerState();
}

class _BroadcastBannerState extends State<BroadcastBanner> {
  static const _kDismissedKey = 'broadcast_dismissed_id';
  // null = لم نقرأ التفضيل بعد؛ نُخفي الشريط ريثما نعرف حتى لا «يومض» ظاهراً
  // ثم يختفي إن كان مُخفىً أصلاً.
  bool? _dismissed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BroadcastBanner old) {
    super.didUpdateWidget(old);
    // رسالةٌ جديدة (معرّفٌ مختلف) تُعيد تقييم حالة الإخفاء من جديد.
    if (old.id != widget.id) _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedId = prefs.getString(_kDismissedKey);
    if (!mounted) return;
    setState(() => _dismissed = dismissedId == widget.id);
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDismissedKey, widget.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed != false) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.campaign_outlined, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(widget.body, style: const TextStyle(fontSize: 13.5)),
        ])),
        // زرّ إغلاق صريح: أوضح من الإزاحة بالسحب لمستخدمٍ لا يتوقّعها.
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          color: AppColors.textGray,
          tooltip: tr('إخفاء', 'Dismiss'),
          onPressed: _dismiss,
        ),
      ]),
    );
  }
}

/// خط تتبع الطلب (Stepper) بشكل نقاط متصلة بخط يوضح أين وصل الطلب ضمن
/// المسار العام: إنشاء الطلب ← قبول المطعم ← التحضير ← الاستلام/الإسناد ←
/// التوصيل.
class OrderTrackingTimeline extends StatelessWidget {
  final OrderStatus status;
  const OrderTrackingTimeline({super.key, required this.status});

  // getter لا const: التسميات تمرّ بـ tr() فتُقيَّم بلغة العرض الحالية عند
  // كل بناء — وconst كان سيجمّدها على العربية.
  static List<_TimelineStep> get _steps => [
        _TimelineStep(tr('تنفيذ الطلب', 'Order placed'), Icons.receipt_long_rounded),
        _TimelineStep(tr('استلام المطعم', 'Restaurant accepted'), Icons.storefront_rounded),
        _TimelineStep(tr('جاري التحضير', 'Preparing'), Icons.restaurant_rounded),
        _TimelineStep(tr('تسليم المندوب', 'Courier pickup'), Icons.delivery_dining_rounded),
        _TimelineStep(tr('توصيل الطلب', 'Delivery'), Icons.home_rounded),
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
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
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
/// تنبيه صدق النافذة — يظهر حين تعرض شاشةٌ ماليةٌ «الكل» من نافذة مقصوصة
/// (أحدث ٥٠٠ طلب): كانت العناوين تدّعي «منذ البداية» فوق أرقام ناقصة،
/// والمدير لا يملك وسيلة لاكتشاف القصّ. التنبيه يصارحه ويدلّه على البديل
/// الكامل (نطاق زمني محدد يُجلب من القاعدة بلا سقف).
class WindowCapNotice extends StatelessWidget {
  /// العدد الحقيقي الكامل من استعلام العدّ الخادمي — قد يتأخر لحظة فيُعرض
  /// التنبيه بلا الرقم ثم يكتمل.
  final int? trueTotal;

  /// الافتراضي لموضع «فوق قائمة بلا حواف» (التقارير)؛ الشاشات ذات الحواف
  /// (الرئيسة) تمرّر هامشها كي لا تتضاعف الحواف.
  final EdgeInsetsGeometry margin;

  const WindowCapNotice({
    super.key,
    this.trueTotal,
    this.margin = const EdgeInsets.fromLTRB(16, 10, 16, 0),
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withOpacity(0.45)),
        ),
        child: Row(children: [
          const Icon(Icons.crop_rounded, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr(
                  'يغطي هذا العرض أحدث ٥٠٠ طلب'
                  '${trueTotal != null ? ' من أصل $trueTotal' : ''}'
                  ' — اختر نطاقاً زمنياً محدداً لأرقام كاملة.',
                  'This view covers the latest 500 orders'
                  '${trueTotal != null ? ' of $trueTotal' : ''}'
                  ' — pick a specific date range for complete figures.'),
              style: const TextStyle(fontSize: 12, color: AppColors.textDark),
            ),
          ),
        ]),
      );
}
