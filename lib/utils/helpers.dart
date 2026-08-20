import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/theme.dart';

String formatCurrency(double amount) => '${amount.toStringAsFixed(2)} ر.س';

/// تطبيع نصٍّ عربيٍّ للبحث (لمسات العميل 2026-08-20): العميل يكتب «مطعم
/// البيك» فلا يجد «مطعم البيك” لأن الألف بهمزة، أو يكتب «شاورما» فيفوته
/// «شاورمه» بالتاء المربوطة. البحث الحرفي يعاقب مَن لا يضبط الإملاء —
/// وأكثر مستخدمينا كذلك. نطبّع الطرفين (الاستعلام والحقل) بالقواعد
/// المتعارَفة عربياً فيلتقيان:
///   • الألفات (أ إ آ ٱ) ← ا     • التاء المربوطة ة ← ه
///   • الألف المقصورة ى ← ي       • الهمزات المفردة ؤ ئ ء ← تُحذف/تُبسَّط
///   • حذف التشكيل والتطويل (ـ)   • توحيد المسافات وحالة الأحرف اللاتينية
String normalizeArabic(String input) {
  var s = input.trim().toLowerCase();
  // حذف التشكيل (الفتحة..السكون + الشدة + التنوين) والتطويل.
  s = s.replaceAll(RegExp('[ً-ْـ]'), '');
  s = s.replaceAll(RegExp('[آأإٱ]'), 'ا'); // آأإٱ ← ا
  s = s.replaceAll('ى', 'ي'); // ى ← ي
  s = s.replaceAll('ة', 'ه'); // ة ← ه
  s = s.replaceAll('ؤ', 'و'); // ؤ ← و
  s = s.replaceAll('ئ', 'ي'); // ئ ← ي
  s = s.replaceAll('ء', ''); // ء مفردة تُحذف
  // توحيد المسافات المتعددة إلى واحدة.
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  return s;
}

/// هل يحتوي النص المطبَّع [haystack] النصَّ المطبَّع [needle]؟ اختصارٌ
/// لبحث المطاعم والأصناف — يطبّع الطرفين مرة واحدة عند الاستدعاء.
bool normalizedContains(String haystack, String needle) =>
    normalizeArabic(haystack).contains(normalizeArabic(needle));

/// تاريخ ووقت بصيغة موجزة «11/8 — 14:52» — للطوابع الزمنية في البطاقات
/// والسجلّات حيث السنة معلومة من السياق ولا تستحق عرضها.
String formatDateTime(DateTime t) =>
    '${t.day}/${t.month} — '
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

// ScaffoldMessenger الجذري (الذي يوفّره MaterialApp) يبقي الرسالة ظاهرة
// عبر أي تنقّل بين الشاشات لا يُغلقها صراحة — فمن أخطأ كود كوبون عدّة مرات
// متتالية (كل خطأ يُضيف 4 ثوانٍ للطابور) ثم انتقل فوراً لشاشة أخرى تماماً
// كان يرى رسالة الخطأ القديمة تظهر فوق شاشته الجديدة بلا صلة. مسح الطابور
// أولاً يضمن أن كل رسالة تخصّ شاشتها الحالية فقط.
void showSuccess(BuildContext context, String msg) {
  final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
  messenger.showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.success));
}

void showError(BuildContext context, String msg) {
  final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
  messenger.showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
}

Future<bool?> showConfirmDialog(BuildContext context, {required String title, required String content,
    String confirmLabel = 'تأكيد', Color? confirmColor}) => showDialog<bool>(
  context: context,
  barrierColor: Colors.black54,
  builder: (_) => AlertDialog(title: Text(title), content: Text(content), actions: [
    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
    ElevatedButton(onPressed: () => Navigator.pop(context, true),
        style: ElevatedButton.styleFrom(backgroundColor: confirmColor ?? AppColors.primary),
        child: Text(confirmLabel)),
  ]),
);

/// يفتح تطبيق الاتصال على الرقم المُعطى — تُستخدم للاتصال بين العميل والسائق
/// أثناء التوصيل. تعرض رسالة واضحة بدل الفشل الصامت إن تعذّر فتح المتصل أو
/// كان الرقم غير متوفّر.
Future<void> callPhone(BuildContext context, String? phone) async {
  final number = phone?.trim() ?? '';
  if (number.isEmpty) {
    showError(context, 'رقم الهاتف غير متوفّر');
    return;
  }
  final uri = Uri(scheme: 'tel', path: number);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showError(context, 'تعذّر فتح تطبيق الاتصال');
  } catch (_) {
    if (context.mounted) showError(context, 'تعذّر فتح تطبيق الاتصال');
  }
}

String? validateRequired(String? v, [String label = 'هذا الحقل']) =>
    (v == null || v.trim().isEmpty) ? '$label مطلوب' : null;

String? validateEmail(String? v) {
  if (v == null || v.trim().isEmpty) return 'البريد الإلكتروني مطلوب';
  if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) return 'صيغة غير صالحة';
  return null;
}

String? validatePassword(String? v) {
  if (v == null || v.isEmpty) return 'كلمة المرور مطلوبة';
  if (v.length < 6) return 'يجب أن تكون 6 أحرف على الأقل';
  return null;
}

String? validatePhone(String? v) => (v == null || v.trim().length < 9) ? 'رقم هاتف غير صالح' : null;

String? validatePrice(String? v) {
  if (v == null || v.trim().isEmpty) return 'السعر مطلوب';
  final n = double.tryParse(v.trim());
  if (n == null || n < 0) return 'سعر غير صالح';
  return null;
}

/// المسافة بالكيلومترات بين نقطتين باستخدام معادلة Haversine.
double haversineDistanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLng = _deg2rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _deg2rad(double deg) => deg * (math.pi / 180.0);

/// عدد الكيلومترات الإضافية بعد المسافة المجانية — لا تُحسب كسور الكيلومتر،
/// بل تُجبر للأعلى دائماً (Ceil) حتى لو كان الكسر بسيطاً.
int ceilExtraKm(double distanceKm, double freeKm) {
  final extra = distanceKm - freeKm;
  if (extra <= 0) return 0;
  return extra.ceil();
}

/// أجرة الكيلومترات الإضافية بعد إجبار التقريب للأعلى — بدون كسور.
double calculateExtraKmFee(double distanceKm, double freeKm, double perKmFee) =>
    ceilExtraKm(distanceKm, freeKm) * perKmFee;

/// إعدادات التسعير الموحّدة لكل التطبيق — مصدر واحد للحقيقة. القيم هنا ثوابت
/// عمل عامة (لا لكل مطعم)؛ يمكن لاحقاً نقلها إلى إعدادات عامة في Firestore
/// (delivery_settings) دون تغيير بقية الكود لأن الجميع يمرّ عبر هذه الدوال.
class Pricing {
  Pricing._();

  /// عمولة التطبيق على قيمة الوجبة (يدفعها العميل فوق سعر الوجبة).
  static const double appCommissionRate = 0.15;

  /// أجرة توصيل أول [baseDeliveryKm] كم (ثابتة).
  static const double baseDeliveryFee = 9.0;
  static const double baseDeliveryKm = 7.0;

  /// أجرة كل كيلومتر إضافي فوق المدى الأساسي.
  static const double perExtraKmFee = 1.0;

  /// رسم توصيل ثابت للتطبيق يتحمّله العميل في كل طلب.
  static const double fixedDeliveryCommission = 3.0;

  /// أقصى مسافة توصيل مقبولة بالكيلومترات. بدون هذا الحدّ يستطيع العميل
  /// تحديد موقع في مدينة أخرى فتُحتسب أجرة توصيل خيالية (مثل 732 ر.س لمسافة
  /// 730 كم) على طلب لا يستطيع أي سائق تنفيذه أصلاً.
  static const double maxDeliveryDistanceKm = 25.0;

  /// هل الموقع خارج نطاق خدمة المطعم؟
  static bool isOutOfRange(double distanceKm) =>
      distanceKm > maxDeliveryDistanceKm;

  /// أجرة التوصيل حسب المسافة: أساس ثابت لأول 7 كم + 1 ر.س لكل كم إضافي،
  /// مع إجبار كسور الكيلومتر للأعلى (9.8 كم → 10).
  static double deliveryFee(double distanceKm) {
    final extraKm = ceilExtraKm(distanceKm, baseDeliveryKm);
    return baseDeliveryFee + extraKm * perExtraKmFee;
  }

  /// عمولة التطبيق على الوجبة (15%) — تُخصم من مستحقّات المطعم ولا يدفعها
  /// العميل؛ تُستخدم في تقارير المدير فقط (قيمة الطلب للعميل = قيمتها للمطعم).
  static double appCommission(double itemsTotal) => itemsTotal * appCommissionRate;

  /// صافي مستحقّات المطعم من قيمة وجباته بعد خصم عمولة التطبيق.
  static double restaurantNet(double itemsTotal) =>
      itemsTotal - appCommission(itemsTotal);

  /// نسبة ضريبة القيمة المضافة في السعودية.
  static const double vatRate = 0.15;

  // -------------------------------------------------------------------------
  // إعدادات دفتر السائق — مفاتيح المراحل. المرحلة الحالية (صفر: التجريب)
  // تسجّل كل الحركات بلا أي تقييد، والمحاسبة يدوية خارج التطبيق.
  //
  // قرار المالك: كفاية رصيد السائق لتغطية عُهد طلباته **اتفاق تشغيلي**
  // بينه وبين الإدارة خارج التطبيق — فالتطبيق لا يعرض قاعدةً ولا تنبيهاً
  // ولا يمنع إسناداً بسببها. المفاتيح أدناه تبقى للمستقبل إن قرّر المالك
  // يوماً تفعيل التقييد آلياً (تغيير قيمة هنا لا إعادة برمجة).
  // راجع dev-docs/driver-wallet-design.md للتفصيل.
  // -------------------------------------------------------------------------

  /// عتبة تنبيه دَين السائق — غير مستخدَمة في الواجهة حالياً (قرار المالك:
  /// لا إشارة للاتفاق داخل التطبيق)، وتبقى لتفعيل مستقبلي إن طُلب.
  static const double driverDebtWarningThreshold = 50.0;

  /// سقف الدَّين الذي يتوقّف عنده إسناد الطلبات النقدية.
  /// `null` = بلا إيقاف إطلاقاً (المرحلة الحالية).
  static const double? driverDebtHardLimit = null;

  /// أقصى قيمة طلب يُسمح بدفعها نقداً. `null` = بلا سقف (المرحلة الحالية).
  static const double? maxCashOrderValue = null;

  /// هل بلغ رصيد السائق حدّ التوقّف عن الطلبات النقدية؟ يُرجع false دائماً
  /// ما دام [driverDebtHardLimit] بقيمة null — أي لا تقييد في مرحلة التجريب.
  static bool isDriverCashBlocked(double balance) {
    final limit = driverDebtHardLimit;
    if (limit == null) return false;
    return balance <= -limit;
  }

  /// هل تجاوز السائق عتبة التنبيه؟ (عرض فقط، بلا أثر تشغيلي)
  static bool isDriverDebtWarning(double balance) =>
      balance <= -driverDebtWarningThreshold;

  /// قيمة الضريبة **المتضمَّنة** في مبلغ شامل لها. الأسعار المعروضة للعميل
  /// شاملة الضريبة (كما يقتضي النظام)، فتُستخرج منها بالمعادلة
  /// المبلغ × 15 ÷ 115 — لا بضربها في 15% (ذاك يُضاعف الاحتساب).
  static double vatIncludedIn(double grossAmount) =>
      grossAmount * vatRate / (1 + vatRate);

  /// إجمالي ما يدفعه العميل = الوجبات + التوصيل + الرسم الثابت (بلا عمولة
  /// الوجبة — فهي تُخصم من المطعم لا تُضاف على العميل).
  static double customerTotal(double itemsTotal, double distanceKm) =>
      itemsTotal + deliveryFee(distanceKm) + fixedDeliveryCommission;
}