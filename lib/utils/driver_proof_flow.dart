// lib/utils/driver_proof_flow.dart
//
// التدفّق الموحّد لتأكيد السائق استلامَ الطلب من المطعم وتسليمَه للعميل —
// تستدعيه شاشتا السائق (البطاقات والخريطة) فلا يختلف السلوك حسب المدخل.
//
// فلسفة القيود (بقرار المالك):
//
//   • الاستلام من المطعم: ضمن **١٠٠ متر** إلزاماً، ولا موقع مُحاكى —
//     موقع المطعم ثابت ومعروف ولا عذر للتأكيد من بعيد.
//   • التسليم للعميل: ضمن **١٥٠ متراً** إلزاماً من الموقع المسجّل — نطاق
//     أوسع قليلاً مراعاةً لدقة دبّوس العميل وتسليمات بوابة الحي وموقف
//     السيارات، لكنه يمنع «تسليماً» من حيّ آخر. المسافة الفعلية تُسجَّل
//     في وثيقة الإثبات.
//   • الصور **اختيارية مُشجَّعة** لا إلزامية: الكاميرا تُفتح مباشرةً، وإن
//     ألغى السائق تابع بعد تأكيد بسيط — التوثيق يخدم السائق نفسه أولاً
//     (حجّته في النزاع) والإلزام كان سيعقّد كل توصيلة لحماية نادرة الحدوث.
//     الصورة لا تصل العميل إطلاقاً — تُحفظ لشاشة النزاع عند الإدارة فقط.
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../providers/firebase_service.dart';
import 'helpers.dart';
import 'location_guard.dart';

class DriverProofFlow {
  DriverProofFlow._();

  /// رسالة منع نطاق المطعم تُذيَّل بتفسير الاحتمال الأرجح حين يكون الكابتن
  /// واقفاً عند المطعم فعلاً: النقطة المسجّلة على الخريطة خاطئة (حدث بعد
  /// تعديل موقع فرعَي فطير ستيشن ٢٠٢٦-٠٨-١١، فبدا العطل وكأنه في التطبيق).
  /// بلا هذا التذييل يقرأ الكابتن «أنت بعيد» وهو يرى لافتة المطعم أمامه،
  /// فلا يعرف ماذا يفعل ولا تصل الإدارة أي إشارة إلى أن النقطة تحتاج تصحيحاً.
  static String _restaurantRangeHint(String err) =>
      '$err\n\nإن كنت عند المطعم الآن فموقعه المسجّل على الخريطة غير صحيح — '
      'أبلغ الإدارة لتصحيحه من لوحة التحكم.';

  /// التقاط صورة من الكاميرا مضغوطة. `null` إن ألغى السائق التصوير.
  static Future<Uint8List?> _capturePhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        // الكاميرا حصراً: صورة من المعرض قد تكون قديمة أو لطلب آخر، فتفقد
        // الوثيقة قيمتها كإثبات لحظي.
        source: ImageSource.camera,
        maxWidth: 800,
        imageQuality: 55,
      );
      if (file == null) return null;
      return file.readAsBytes();
    } catch (_) {
      // كاميرا معطّلة أو إذن مرفوض — الصورة اختيارية فلا يتعطل التشغيل.
      return null;
    }
  }

  /// صورة اختيارية: إن ألغى السائق التصوير يُسأل سؤالاً واحداً — «متابعة
  /// بدون صورة» تمضي بالعملية بلا صورة، و«إلغاء» يوقف العملية كلها (لعله
  /// ضغط الزر خطأً). يُرجع (تابِع؟، الصورة إن وُجدت).
  static Future<(bool, Uint8List?)> _captureOptionalPhoto(
      BuildContext context) async {
    final photo = await _capturePhoto();
    if (photo != null) return (true, photo);
    if (!context.mounted) return (false, null);
    final proceed = await showConfirmDialog(
      context,
      title: 'بدون صورة؟',
      content: 'الصورة حجّتك عند أي نزاع، ولا يراها العميل. المتابعة بدونها؟',
      confirmLabel: 'متابعة بدون صورة',
    );
    return (proceed == true, null);
  }

  /// تسجيل وصول السائق للمطعم — ضمن النطاق فقط، بلا صورة (المعيار العالمي:
  /// الطابع الزمني الجغرافي هو الحاسم في نزاع التأخير).
  static Future<bool> recordArrival(
    BuildContext context,
    FirebaseService service,
    Order order,
  ) async {
    // إحداثيات المطعم الحيّة لا لقطة الطلب — موقع صحّحه المدير بعد إنشاء
    // الطلب يجب أن يحكم النطاق، وإلا رُفض سائق واقف أمام المطعم الفعلي.
    order = await service.withLiveRestaurantCoords(order);
    final err = await LocationGuard.checkNear(
      targetLat: order.restaurantLat,
      targetLng: order.restaurantLng,
      targetLabel: 'المطعم',
    );
    if (err != null) {
      if (context.mounted) showError(context, _restaurantRangeHint(err));
      return false;
    }
    try {
      final pos = await LocationGuard.currentPosition();
      await service.recordArrivalAtRestaurant(
          order: order, lat: pos.latitude, lng: pos.longitude);
      if (context.mounted) showSuccess(context, 'سُجّل وصولك إلى المطعم');
      return true;
    } catch (e) {
      if (context.mounted) showError(context, 'تعذّر تسجيل الوصول: $e');
      return false;
    }
  }

  /// تدفّق تأكيد الاستلام كاملاً: نطاق ← صورة ← تأكيد (مع مصارحة العُهدة
  /// للطلب النقدي) ← حفظ الصورة ← تغيير الحالة وقيد العُهدة.
  /// يُرجع true إن اكتمل الاستلام فعلاً.
  static Future<bool> confirmPickup(
    BuildContext context,
    FirebaseService service,
    Order order,
  ) async {
    // نفس مبدأ recordArrival: النطاق يُقاس على موقع المطعم الحالي لا لقطته.
    order = await service.withLiveRestaurantCoords(order);
    final err = await LocationGuard.checkNear(
      targetLat: order.restaurantLat,
      targetLng: order.restaurantLng,
      targetLabel: 'المطعم',
    );
    if (err != null) {
      if (context.mounted) showError(context, _restaurantRangeHint(err));
      return false;
    }

    if (!context.mounted) return false;
    final isCash = order.paymentMethod == PaymentMethod.cash;
    final ok = await showConfirmDialog(
      context,
      title: 'استلام الطلب',
      content: 'هل طابقت رقم الطلب #${order.orderNumber} على ملصق الكيس '
              'وعدد الأصناف؟\n\n' +
          (isCash && order.custodyAmount > 0
              ? 'سيُقيَّد على محفظتك ${formatCurrency(order.custodyAmount)} '
                  '(قيمة الطلب) حتى تحصيلها من العميل.\n\n'
              : '') +
          'التالي: صورة سريعة للطلب — اختيارية، لكنها حجّتك في أي نزاع.',
      confirmLabel: 'طابقتُ — متابعة',
    );
    if (ok != true || !context.mounted) return false;

    final (proceed, photo) = await _captureOptionalPhoto(context);
    if (!proceed) return false;

    try {
      // الوثيقة تُكتب دائماً (زمن + إحداثيات، والصورة إن التُقطت) وقبل
      // تغيير الحالة: لو انقطع الاتصال بعد الوثيقة بقيت وثيقة زائدة غير
      // مؤذية؛ العكس كان يترك استلاماً بلا إثبات.
      final pos = await LocationGuard.currentPosition();
      await service.savePickupProof(
          order: order, photo: photo, lat: pos.latitude, lng: pos.longitude);
      await service.markPickedUpBySelf(order.id);
      return true;
    } catch (e) {
      if (context.mounted) {
        showError(context, e.toString().replaceFirst('Exception: ', ''));
      }
      return false;
    }
  }

  /// تدفّق تأكيد التسليم — قيد **مُلزم ضمن ١٥٠ متراً** من موقع العميل
  /// المسجّل (بقرار المالك): أوسع من نطاق المطعم مراعاةً لدقة دبّوس العميل
  /// وتسليمات بوابة الحي، لكنه يمنع «تسليماً» من حيّ آخر بالكامل. المسافة
  /// الفعلية تُسجَّل في وثيقة الإثبات أيضاً.
  static Future<bool> confirmDelivery(
    BuildContext context,
    FirebaseService service,
    Order order,
  ) async {
    final err = await LocationGuard.checkNear(
      targetLat: order.deliveryLat,
      targetLng: order.deliveryLng,
      targetLabel: 'موقع العميل',
      radius: LocationGuard.deliveryProximityMeters,
    );
    if (err != null) {
      if (context.mounted) showError(context, err);
      return false;
    }

    // القياس نجح ضمن النطاق — تُلتقط الإحداثيات والمسافة للتسجيل.
    double? distance;
    double? lat;
    double? lng;
    try {
      final pos = await LocationGuard.currentPosition();
      lat = pos.latitude;
      lng = pos.longitude;
      if (order.deliveryLat != null && order.deliveryLng != null) {
        distance = Geolocator.distanceBetween(
            pos.latitude, pos.longitude, order.deliveryLat!, order.deliveryLng!);
      }
    } catch (_) {
      distance = null;
    }

    if (!context.mounted) return false;

    final ok = await showConfirmDialog(
      context,
      title: 'تأكيد التوصيل',
      content: 'التالي: صورة سريعة للطلب عند التسليم — اختيارية، '
          'وهي حجّتك الأقوى في نزاع «لم يصلني الطلب». لا يراها العميل.',
      confirmLabel: 'متابعة',
    );
    if (ok != true || !context.mounted) return false;

    final (proceed, photo) = await _captureOptionalPhoto(context);
    if (!proceed) return false;

    try {
      // الوثيقة تُكتب متى توفرت الإحداثيات — حتى بلا صورة: زمن التسليم
      // ومكانه (والمسافة عن الموقع المسجّل) بيّنة قائمة بذاتها.
      if (lat != null && lng != null) {
        await service.saveDeliveryProof(
          order: order,
          photo: photo,
          lat: lat,
          lng: lng,
          distanceMeters: distance,
        );
      }
      await service.markOrderDelivered(order.id, order.driverId ?? '');
      return true;
    } catch (e) {
      if (context.mounted) {
        showError(context, e.toString().replaceFirst('Exception: ', ''));
      }
      return false;
    }
  }
}
