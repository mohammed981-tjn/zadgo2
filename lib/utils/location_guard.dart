// lib/utils/location_guard.dart
//
// حارس الموقع لعمليات السائق الحسّاسة: تأكيد استلام الطلب من المطعم وتأكيد
// تسليمه للعميل لا يمرّان إلا والجهاز **فعلياً** ضمن نطاق الهدف.
//
// لماذا؟ بدون هذا القيد يستطيع السائق ضغط «استلمت» وهو في بيته و«سلّمت»
// وهو في الشارع المجاور — فتنهار قيمة كل التوثيق (أزمنة الحالات، قيد
// العُهدة، ولاحقاً الصور). القيد يُفحص لحظة الضغط بقراءة GPS حقيقية، مع
// رفض المواقع المُحاكاة (تطبيقات الموقع الوهمي) صراحةً.
//
// حدود مُصارَح بها: الفحص على جهاز السائق لا على خادم، فنسخة معدَّلة من
// التطبيق تستطيع تجاوزه — شأنه شأن بقية منطق العميل، ويُغلق نهائياً حين
// يتوفر خادم موثوق. ضد الاستخدام العادي (سائق يستعجل من بعيد) فعّال تماماً.
import 'package:geolocator/geolocator.dart';

class LocationGuard {
  LocationGuard._();

  /// نصف قطر السماح حول الهدف — ١٠٠ متر: يغطي مواقف السيارات ومداخل
  /// المجمّعات دون أن يسمح بتأكيد من حيّ آخر.
  static const double proximityMeters = 100;

  /// يقرأ موقع الجهاز الحالي بدقة عالية، أو يرمي رسالة عربية مفهومة.
  static Future<Position> currentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw 'خدمة الموقع غير مفعّلة — فعّل GPS أولاً';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw 'إذن الموقع مرفوض — يلزم للسماح بتأكيد الاستلام والتسليم';
    }
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
    } catch (_) {
      throw 'تعذّر تحديد موقعك — تأكد من إشارة GPS وحاول ثانية';
    }
  }

  /// يتحقق أن الجهاز ضمن [proximityMeters] من الهدف.
  ///
  /// يُرجع `null` عند السماح، أو رسالة عربية تشرح المانع (بعيد بمسافة كذا /
  /// موقع مُحاكى / GPS معطّل). وإن كان الهدف بلا إحداثيات محفوظة يُسمح
  /// بالمرور — لا يمكن فرض قربٍ من نقطة مجهولة، وتعطيل العملية كلها بسببها
  /// يوقف التشغيل عن طلبات قديمة صالحة.
  static Future<String?> checkNear({
    required double? targetLat,
    required double? targetLng,
    required String targetLabel,
  }) async {
    if (targetLat == null || targetLng == null) return null;

    final Position pos;
    try {
      pos = await currentPosition();
    } catch (e) {
      return e.toString();
    }

    // الموقع المُحاكى مرفوض هنا تحديداً: هذه العمليات هي ما يُزوَّر لأجله.
    if (pos.isMocked) {
      return 'موقع جهازك مُحاكى (تطبيق موقع وهمي) — عطّله ثم أعد المحاولة';
    }

    final distance = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, targetLat, targetLng);
    if (distance > proximityMeters) {
      final shown = distance >= 1000
          ? '${(distance / 1000).toStringAsFixed(1)} كم'
          : '${distance.round()} متر';
      return 'أنت على بُعد $shown من $targetLabel — '
          'التأكيد متاح ضمن ${proximityMeters.round()} متر فقط';
    }
    return null;
  }
}
