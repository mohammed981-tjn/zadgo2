// lib/utils/driver_proof_flow.dart
//
// التدفّق الموحّد لتأكيد السائق استلامَ الطلب من المطعم وتسليمَه للعميل —
// تستدعيه شاشتا السائق (البطاقات والخريطة) فلا يختلف السلوك حسب المدخل.
//
// فلسفة القيود — صرامة حيث الثقة ممكنة، ومرونة حيث الواقع متقلب:
//
//   • الاستلام من المطعم: قيد **صارم** (ضمن ١٠٠ متر، لا موقع مُحاكى) —
//     موقع المطعم ثابت ومعروف ولا عذر للتأكيد من بعيد.
//   • التسليم للعميل: قيد **ناعم** — العميل قد لا يكون في موقعه المسجّل
//     فعلاً (يستلم من الشارع، دبّوس خاطئ، اتفقا على نقطة أخرى)، فالبُعد
//     لا يمنع التسليم بل يُصارَح به السائق ويُسجَّل في وثيقة الإثبات
//     ليكون بيّنةً عند النزاع لا حاجزاً أمام التشغيل.
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
    final err = await LocationGuard.checkNear(
      targetLat: order.restaurantLat,
      targetLng: order.restaurantLng,
      targetLabel: 'المطعم',
    );
    if (err != null) {
      if (context.mounted) showError(context, err);
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
    final err = await LocationGuard.checkNear(
      targetLat: order.restaurantLat,
      targetLng: order.restaurantLng,
      targetLabel: 'المطعم',
    );
    if (err != null) {
      if (context.mounted) showError(context, err);
      return false;
    }

    if (!context.mounted) return false;
    final isCash = order.paymentMethod == PaymentMethod.cash;
    final ok = await showConfirmDialog(
      context,
      title: 'استلام الطلب',
      content: (isCash
              ? 'سيُقيَّد على محفظتك ${formatCurrency(order.custodyAmount)} '
                  '(قيمة الطلب) حتى تحصيلها من العميل.\n\n'
              : '') +
          'التالي: صورة سريعة للطلب — اختيارية، لكنها حجّتك في أي نزاع.',
      confirmLabel: 'متابعة',
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

  /// تدفّق تأكيد التسليم — قيد **ناعم**: البعد عن موقع العميل المسجّل لا
  /// يمنع التسليم (قد يستلم من الشارع أو من نقطة متفق عليها)، بل يُصارَح
  /// به السائق ويُسجَّل في وثيقة الإثبات بيّنةً عند النزاع.
  static Future<bool> confirmDelivery(
    BuildContext context,
    FirebaseService service,
    Order order,
  ) async {
    // قياس المسافة للتسجيل والمصارحة — لا للمنع. تعذُّر GPS لا يوقف
    // التسليم أيضاً: المرونة أولاً، والفجوة تُسجَّل بغياب الإحداثيات.
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

    final isFar =
        distance != null && distance > LocationGuard.proximityMeters;
    final farLine = isFar
        ? '⚠️ أنت على بُعد ${distance >= 1000 ? "${(distance / 1000).toStringAsFixed(1)} كم" : "${distance.round()} متر"} '
            'من موقع العميل المسجّل — إن كان استلم منك في مكان آخر فهذا طبيعي، '
            'وستُسجَّل المسافة في وثيقة الطلب.\n\n'
        : '';

    final ok = await showConfirmDialog(
      context,
      title: 'تأكيد التوصيل',
      content: '${farLine}التالي: صورة سريعة للطلب عند التسليم — اختيارية، '
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
