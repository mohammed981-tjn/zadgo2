// lib/utils/driver_proof_flow.dart
//
// التدفّق الموحّد لتأكيد السائق استلامَ الطلب من المطعم وتسليمَه للعميل —
// تستدعيه شاشتا السائق (البطاقات والخريطة) فلا يختلف السلوك حسب المدخل:
//
//   ١) حارس الموقع: التأكيد لا يمرّ إلا والجهاز فعلياً ضمن ١٠٠ متر من
//      الهدف (LocationGuard) — يرفض البعيد والموقع المُحاكى.
//   ٢) صورة إلزامية من الكاميرا مباشرةً (لا من المعرض): إثبات ماذا استُلم
//      وماذا وُضع عند العميل، مضغوطة (~٦٠ كيلوبايت) وتُخزَّن في وثيقة
//      الإثبات order_proofs.
//   ٣) الصورة تُحفظ قبل تغيير الحالة: لا استلام مكتمل بلا صورته.
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
    final file = await ImagePicker().pickImage(
      // الكاميرا حصراً: صورة من المعرض قد تكون قديمة أو لطلب آخر، فتفقد
      // الوثيقة قيمتها كإثبات لحظي.
      source: ImageSource.camera,
      maxWidth: 800,
      imageQuality: 55,
    );
    if (file == null) return null;
    return file.readAsBytes();
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
          'التالي: التقط صورة للطلب (الشنطة/الفاتورة) لإثبات الاستلام.',
      confirmLabel: 'التقاط الصورة',
    );
    if (ok != true) return false;

    final photo = await _capturePhoto();
    if (photo == null) {
      if (context.mounted) {
        showError(context, 'صورة الاستلام إلزامية لإتمام العملية');
      }
      return false;
    }

    try {
      final pos = await LocationGuard.currentPosition();
      // الصورة أولاً ثم الحالة: لو انقطع الاتصال بعد الصورة بقيت وثيقة
      // زائدة غير مؤذية؛ العكس كان يترك استلاماً بلا إثبات.
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

  /// تدفّق تأكيد التسليم كاملاً: نطاق (موقع العميل) ← صورة ← حفظ ← تسليم.
  static Future<bool> confirmDelivery(
    BuildContext context,
    FirebaseService service,
    Order order,
  ) async {
    final err = await LocationGuard.checkNear(
      targetLat: order.deliveryLat,
      targetLng: order.deliveryLng,
      targetLabel: 'موقع العميل',
    );
    if (err != null) {
      if (context.mounted) showError(context, err);
      return false;
    }

    if (!context.mounted) return false;
    final ok = await showConfirmDialog(
      context,
      title: 'تأكيد التوصيل',
      content: 'التقط صورة للطلب عند العميل (عند الباب أو أثناء التسليم) — '
          'هي إثباتك الأقوى في أي نزاع «لم يصلني الطلب».',
      confirmLabel: 'التقاط الصورة',
    );
    if (ok != true) return false;

    final photo = await _capturePhoto();
    if (photo == null) {
      if (context.mounted) {
        showError(context, 'صورة التسليم إلزامية لإتمام العملية');
      }
      return false;
    }

    try {
      final pos = await LocationGuard.currentPosition();
      await service.saveDeliveryProof(
          order: order, photo: photo, lat: pos.latitude, lng: pos.longitude);
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
