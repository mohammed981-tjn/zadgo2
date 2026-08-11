// lib/screens/driver/pickup_docket_screen.dart
//
// «مذكرة الاستلام» — الشاشة التي يعرضها السائق لموظف المطعم ليستلم الطلب
// بموجبها (نمط دوردا ش/كيتا/جاهز: مطابقة رقم الطلب والأصناف قبل مغادرة
// المطعم تمنع أغلب أخطاء «الطلب الخاطئ/الناقص» من جذرها):
//
//   • رقم الطلب ضخماً — ما يقرؤه موظف المطبخ من متر.
//   • الأصناف بكمياتها بخط كبير — تُطابَق مع محتوى الشنطة قبل الاستلام.
//   • شريط الدفع بلون حاسم: أخضر «مدفوع» / برتقالي «حصّل نقداً X» —
//     أخطر معلومة على السائق أن يخطئ فيها.
//   • ثم أزرار الرحلة نفسها: «توجه للمطعم» (يتحوّل «وصلتُ المطعم» عند
//     الاقتراب) و«استلمت الطلب» (بحارس النطاق والعُهدة والصورة) —
//     فالمذكرة هي مركز ما قبل الاستلام كله.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/driver_proof_flow.dart';
import '../../utils/location_guard.dart';
import '../../widgets/common_widgets.dart';
import '../customer/order_map_screen.dart';

class PickupDocketScreen extends StatefulWidget {
  final String orderId;
  const PickupDocketScreen({super.key, required this.orderId});

  @override
  State<PickupDocketScreen> createState() => _PickupDocketScreenState();
}

class _PickupDocketScreenState extends State<PickupDocketScreen> {
  /// آخر موقع معروف للجهاز — يقود تحوّل زر «توجه للمطعم» إلى «وصلتُ
  /// المطعم» عند دخول نطاق المطعم (ملاحظة المالك: سائق بعيد عن المطعم لم
  /// يكن أمامه زر يوجّهه إليه أصلاً). التتبّع محلي على الجهاز طوال عمر
  /// الشاشة القصير فقط — لا كتابة Firestore جديدة فوق خنق الموقع القائم.
  Position? _pos;
  StreamSubscription<Position>? _posSub;

  /// إحداثيات المطعم الحيّة من مستنده (تُجلب مرة لكل مطعم): لقطة الطلب قد
  /// تسبق تصحيح المدير للموقع، فيقيس زر الاقتراب على المكان الخطأ.
  double? _liveRestLat, _liveRestLng;
  String? _liveFetchedFor;

  void _maybeRefreshRestaurantCoords(FirebaseService service, Order o) {
    if (_liveFetchedFor == o.restaurantId) return;
    _liveFetchedFor = o.restaurantId;
    service.getRestaurantOnce(o.restaurantId).then((r) {
      if (!mounted || r?.lat == null || r?.lng == null) return;
      setState(() {
        _liveRestLat = r!.lat;
        _liveRestLng = r.lng;
      });
    }).catchError((_) {});
  }

  @override
  void initState() {
    super.initState();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        // كل ~١٥ متراً لا كل ثانية: يكفي لالتقاط لحظة دخول النطاق دون
        // استنزاف البطارية، والحارس يعيد القياس بدقة عالية عند الضغط.
        distanceFilter: 15,
      ),
    ).listen(
      (p) => setState(() => _pos = p),
      // إذن مرفوض أو GPS معطّل: يبقى الزر «توجه للمطعم» — فتح الخريطة لا
      // يحتاج موقعاً، وحارس «وصلتُ» سيشرح المانع بنفسه عند الحاجة.
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final fc = context.flavorColors;

    return Scaffold(
      appBar: AppBar(title: const Text('مذكرة الاستلام')),
      // متابعة حيّة للطلب: لو ألغته الإدارة أو تغيّرت حالته وهو أمام
      // المطعم، تتحدث المذكرة فوراً بدل أن يستلم طلباً أُلغي.
      body: StreamBuilder<Order?>(
        stream: service.streamOrder(widget.orderId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const AppLoading();
          }
          final o = snap.data;
          if (o == null) {
            return const AppEmpty(emoji: '❓', title: 'الطلب غير موجود');
          }
          if (!o.status.isActive) {
            return AppEmpty(
                emoji: '⚠️',
                title: 'الطلب لم يعد نشطاً',
                subtitle: 'حالته الآن: ${o.status.label}');
          }

          _maybeRefreshRestaurantCoords(service, o);
          // نسخة الطلب التي تقيس زر الاقتراب — بإحداثيات المطعم الحيّة إن
          // وصلت (بقية الشاشة عرضٌ لا يتأثر بالموقع).
          final navOrder = _liveRestLat != null && _liveRestLng != null
              ? o.copyWith(
                  restaurantLat: _liveRestLat, restaurantLng: _liveRestLng)
              : o;

          // «نقدي» يستحق شريط التحصيل فقط إن بقي على العميل ما يُحصَّل —
          // محفظته قد تكون غطّت المبلغ كله فيُعامل كالمدفوع إلكترونياً.
          final collectAmount = o.payableTotal - o.walletUsed;
          final isCash =
              o.paymentMethod == PaymentMethod.cash && collectAmount > 0;
          final prePickup = o.status == OrderStatus.readyForPickup ||
              o.status == OrderStatus.searchingDriver ||
              o.status == OrderStatus.driverAssigned;

          return Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                // إرشاد الاستخدام — سطر واحد يشرح الغرض لموظف مطعم يراها
                // لأول مرة.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: fc.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(children: [
                    Row(children: [
                      Icon(Icons.storefront_rounded, size: 18, color: fc.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('اعرض هذه الشاشة لموظف المطعم لمطابقة الطلب',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    // الخطوة الذهبية (نمط نينجا/كيتا): مطابقة رقم الكيس تمنع
                    // «الطلب الخاطئ» — أكثر أخطاء الاستلام شيوعاً — من جذره.
                    Row(children: [
                      Icon(Icons.qr_code_2_rounded, size: 18, color: fc.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                            'طابق رقم الطلب على ملصق الكيس مع الرقم أدناه قبل المغادرة',
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 12),

                // رقم الطلب — البطل: يُقرأ من بعيد.
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Column(children: [
                      const Text('رقم الطلب',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textGray)),
                      Text('#${o.orderNumber}',
                          style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: fc.primaryDark)),
                      Text(o.restaurantName,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),

                // شريط الدفع — أهم معلومة تشغيلية للسائق والمطعم معاً.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (isCash ? AppColors.warning : AppColors.success)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isCash ? AppColors.warning : AppColors.success,
                        width: 1.2),
                  ),
                  child: Row(children: [
                    Icon(isCash ? Icons.payments_rounded : Icons.credit_card,
                        color: isCash ? AppColors.warning : AppColors.success),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                isCash
                                    ? 'نقدي — حصّل من العميل ${formatCurrency(collectAmount)}'
                                    : 'مدفوع — لا تحصيل من أحد',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: isCash
                                        ? const Color(0xFF8A6508)
                                        : AppColors.success)),
                            if (isCash && o.custodyAmount > 0)
                              Text(
                                  'ستُقيَّد عُهدة ${formatCurrency(o.custodyAmount)} على محفظتك عند الاستلام',
                                  style: const TextStyle(fontSize: 11.5)),
                          ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                // الأصناف — تُطابَق مع الشنطة قبل الاستلام.
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Text('الأصناف',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                            const Spacer(),
                            Text('${o.items.fold<int>(0, (s, i) => s + i.quantity)} قطعة',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textGray)),
                          ]),
                          const Divider(),
                          ...o.items.map((i) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: fc.primary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text('${i.quantity}×',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: fc.primaryDark)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(i.name,
                                              style: const TextStyle(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w600)),
                                          // الخيارات (كبير • جبن...) جزء من
                                          // المطابقة مع الشنطة لا زينة.
                                          if ((i.extras ?? '')
                                              .trim()
                                              .isNotEmpty)
                                            Text(i.extras!,
                                                style: const TextStyle(
                                                    fontSize: 12.5,
                                                    color:
                                                        AppColors.textGray)),
                                        ]),
                                  ),
                                ]),
                              )),
                          if ((o.notes ?? '').trim().isNotEmpty) ...[
                            const Divider(),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.sticky_note_2_outlined,
                                      size: 16, color: AppColors.warning),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text('ملاحظة العميل: ${o.notes}',
                                        style: const TextStyle(fontSize: 12.5)),
                                  ),
                                ]),
                          ],
                        ]),
                  ),
                ),
                const SizedBox(height: 12),

                // وجهة التوصيل مختصرة — للسائق لا للمطعم.
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InfoRow(
                              icon: Icons.person_outline,
                              text: o.customerName,
                              bold: true),
                          InfoRow(
                              icon: Icons.location_on_outlined,
                              text: o.deliveryAddress),
                        ]),
                  ),
                ),
              ]),
            ),

            // أزرار الرحلة — المذكرة مركز ما قبل الاستلام.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(children: [
                  if (prePickup) ...[
                    if (o.arrivedAtRestaurantAt == null) ...[
                      _ApproachButton(
                          order: navOrder, pos: _pos, service: service),
                      const SizedBox(height: 8),
                    ],
                    ZadGradientButton(
                      label: 'استلمت الطلب — في الطريق',
                      icon: Icons.delivery_dining,
                      onPressed: () async {
                        final done =
                            await DriverProofFlow.confirmPickup(context, service, o);
                        if (done && context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderMapScreen(
                                order: o.copyWith(
                                  status: OrderStatus.onTheWay,
                                  updatedAt: DateTime.now(),
                                  statusChangedAt: DateTime.now(),
                                ),
                                readOnly: false,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ] else
                    ZadGradientButton(
                      label: 'متابعة الرحلة على الخريطة',
                      icon: Icons.map_outlined,
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                OrderMapScreen(order: o, readOnly: false)),
                      ),
                    ),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// زر ما قبل الوصول المتحوّل (اقتراح المالك ٢٠٢٦-٠٨-١١): بعيداً عن المطعم
/// يعرض «توجه للمطعم» ويفتح خريطة الطلب (وفيها الملاحة الخارجية)، وعند
/// دخول نطاق المطعم يتحوّل تلقائياً إلى «وصلتُ المطعم» فيسجّل الوصول.
/// عتبة التحوّل هي نفس نطاق الحارس — زرٌ يظهر ثم يرفضه الحارس كان سيبدو
/// عطلاً لا حمايةً. وموقعٌ مجهول (إذن مرفوض/داخل مبنى) يُعامل كبعيد:
/// فتح الخريطة يعمل دائماً، والحارس يشرح مانع التسجيل بنفسه عند الحاجة.
class _ApproachButton extends StatelessWidget {
  final Order order;
  final Position? pos;
  final FirebaseService service;
  const _ApproachButton(
      {required this.order, required this.pos, required this.service});

  @override
  Widget build(BuildContext context) {
    double? meters;
    if (pos != null &&
        order.restaurantLat != null &&
        order.restaurantLng != null) {
      meters = Geolocator.distanceBetween(pos!.latitude, pos!.longitude,
          order.restaurantLat!, order.restaurantLng!);
    }
    final near = meters != null && meters <= LocationGuard.proximityMeters;

    if (near) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => DriverProofFlow.recordArrival(context, service, order),
          icon: const Icon(Icons.where_to_vote_outlined),
          label: const Text('وصلتُ المطعم'),
        ),
      );
    }

    final distanceLabel = meters == null
        ? ''
        : meters >= 1000
            ? ' — ${(meters / 1000).toStringAsFixed(1)} كم'
            : ' — ${meters.round()} م';
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => OrderMapScreen(order: order, readOnly: false)),
        ),
        icon: const Icon(Icons.navigation_outlined),
        label: Text('توجه للمطعم$distanceLabel'),
      ),
    );
  }
}
