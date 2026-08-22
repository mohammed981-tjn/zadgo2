import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/app_lang.dart';
import '../../utils/driver_proof_flow.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/osm_attribution.dart';

class OrderMapScreen extends StatefulWidget {
  final Order order;
  /// عندما تكون true (الافتراضي) تُعرض الخريطة للمتابعة فقط دون أزرار تغيير حالة
  /// الطلب (استلمت الطلب / تم التوصيل) ودون زر الملاحة الخارجية — تُستخدم
  /// للعميل والمطعم ولوحة المدير. السائق فقط هو من يستخدم readOnly=false
  /// لتمكين أزرار الإجراء والملاحة.
  final bool readOnly;
  const OrderMapScreen({super.key, required this.order, this.readOnly = true});

  @override
  State<OrderMapScreen> createState() => _OrderMapScreenState();
}

class _OrderMapScreenState extends State<OrderMapScreen>
    with TickerProviderStateMixin {
  // كاميرا متحركة (و5): move() كانت قفزة حادة تفقد المستخدم سياقه
  // المكاني — أين كان وأين صار. الانزلاق يبقي الخريطة «مكاناً واحداً».
  late final AnimatedMapController _animatedMap =
      AnimatedMapController(vsync: this);
  MapController get _mapController => _animatedMap.mapController;
  int _driverStreamRetryToken = 0;

  /// نسخة الطلب بإحداثيات المطعم الحيّة — تُجلب مرة عند الفتح: موقع صحّحه
  /// المدير بعد إنشاء الطلب يجب أن يقود الدبوس والملاحة، لا لقطة الإنشاء.
  Order? _liveOrder;
  Order get order => _liveOrder ?? widget.order;

  @override
  void dispose() {
    _animatedMap.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    context
        .read<FirebaseService>()
        .withLiveRestaurantCoords(widget.order)
        .then((fresh) {
      if (mounted && !identical(fresh, widget.order)) {
        setState(() => _liveOrder = fresh);
      }
    });
  }

  // وجهة الخريطة تتبع مرحلة الرحلة لا حالةً واحدة بعينها (ملاحظة المالك
  // ٢٠٢٦-٠٨-١١): كل ما قبل استلام الطلب من المطعم وجهتُه المطعم — حتى لو
  // فتح السائق الخريطة والطلب ما زال يُحضَّر — وبعد الاستلام وجهته العميل.
  // الحصر السابق في driverAssigned كان يجعل الخريطة تتمركز على العميل
  // وتوجّه الملاحة إليه لمجرد أن الحالة «جاهز للاستلام» مثلاً.
  bool get _headingToRestaurant =>
      order.status.isActive && !_headingToCustomer;

  bool get _headingToCustomer =>
      order.status == OrderStatus.pickedUp ||
      order.status == OrderStatus.onTheWay;

  /// زر «استلمت الطلب» يبقى محصوراً في الحالات التي يكون الطلب فيها قابلاً
  /// للاستلام فعلاً — الوجهة نحو المطعم أوسع منها (تشمل «قيد التحضير»).
  bool get _canPickUp =>
      order.status == OrderStatus.readyForPickup ||
      order.status == OrderStatus.searchingDriver ||
      order.status == OrderStatus.driverAssigned;

  Future<void> _openExternalNavigation(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _call(String phone) async {
    if (phone.trim().isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    if (order.driverId != null && order.driverId!.isNotEmpty) {
      return StreamBuilder<Driver?>(
        key: ValueKey(_driverStreamRetryToken),
        stream: service.streamDriver(order.driverId!),
        builder: (ctx, driverSnap) {
          if (driverSnap.hasError) {
            return AppError(
              error: driverSnap.error,
              onRetry: () => setState(() => _driverStreamRetryToken++),
            );
          }
          return _buildScaffold(context, service, driverSnap.data);
        },
      );
    }
    return _buildScaffold(context, service, null);
  }

  // آخر موقع كابتن تمركزت عليه الكاميرا — تتبّعٌ بلا اهتزاز: لا نحرك
  // الخريطة إلا حين يقطع مسافة معتبرة، وإلا اهتزت مع كل تحديث GPS.
  double? _followedLat, _followedLng;

  void _followDriver(Driver? d) {
    if (d?.lat == null || d?.lng == null) return;
    final lat = d!.lat!, lng = d.lng!;
    final moved = _followedLat == null
        ? double.infinity
        : haversineDistanceKm(_followedLat!, _followedLng!, lat, lng) * 1000;
    if (moved < 40) return;
    _followedLat = lat;
    _followedLng = lng;
    // بعد اكتمال الإطار — التحريك أثناء البناء يرمي استثناءً.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animatedMap.animateTo(dest: LatLng(lat, lng));
    });
  }

  Widget _buildScaffold(BuildContext context, FirebaseService service, Driver? liveDriver) {
    // متابعة موقع الكابتن (ملاحظة المالك 2026-08-14): كانت الكاميرا تفتح
    // على المطعم وتبقى — والعميل فتح الخريطة ليرى مندوبه يتحرك.
    _followDriver(liveDriver);
    final points = <Marker>[];
    final polyPoints = <LatLng>[];

    final hasRestaurant = order.restaurantLat != null && order.restaurantLng != null;
    final hasDelivery = order.deliveryLat != null && order.deliveryLng != null;

    if (hasRestaurant) {
      final p = LatLng(order.restaurantLat!, order.restaurantLng!);
      polyPoints.add(p);
      points.add(Marker(
        point: p, width: 64, height: 64,
        // دبوس المطعم كحليّ (رمز الهوية) لا برتقاليّاً خارج اللوحة، ويتمايز عن
        // دبوس العميل الذهبي.
        child: _buildPin(icon: Icons.restaurant, color: AppColors.secondary, highlighted: _headingToRestaurant),
      ));
    }

    if (hasDelivery) {
      final p = LatLng(order.deliveryLat!, order.deliveryLng!);
      polyPoints.add(p);
      points.add(Marker(
        point: p, width: 64, height: 64,
        child: _buildPin(icon: Icons.location_on, color: AppColors.primary, highlighted: _headingToCustomer),
      ));
    }

    if (liveDriver != null && liveDriver.lat != null && liveDriver.lng != null) {
      points.add(Marker(
        point: LatLng(liveDriver.lat!, liveDriver.lng!), width: 50, height: 50,
        child: Container(
          decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
          child: const Icon(Icons.delivery_dining, color: Colors.white, size: 26),
        ),
      ));
    }

    if (points.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('خريطة الطلب', 'Order map'))),
        body: Center(
            child: Text(tr('لا توجد إحداثيات محفوظة لهذا الطلب',
                'No saved coordinates for this order'))),
      );
    }

    final targetPoint = _headingToRestaurant && hasRestaurant
        ? LatLng(order.restaurantLat!, order.restaurantLng!)
        : (hasDelivery ? LatLng(order.deliveryLat!, order.deliveryLng!) : points[0].point);

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle()),
        actions: [
          if (!widget.readOnly && order.customerPhone.isNotEmpty)
            IconButton(
              tooltip: tr('الاتصال بالعميل', 'Call the customer'),
              icon: const Icon(Icons.call_outlined),
              onPressed: () => _call(order.customerPhone),
            ),
          if (liveDriver != null && liveDriver.phone.isNotEmpty)
            IconButton(
              tooltip: tr('الاتصال بالسائق', 'Call the driver'),
              icon: const Icon(Icons.support_agent_outlined),
              onPressed: () => _call(liveDriver.phone),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildStatusBanner(),
              // لافتة التحصيل النقدي (نمط تويو/جاهز): أخطر معلومة على السائق
              // أن يفوتها وهو عند باب العميل — بلون تحذيري لا سطراً عابراً.
              if (!widget.readOnly &&
                  order.paymentMethod == PaymentMethod.cash &&
                  _headingToCustomer)
                Container(
                  width: double.infinity,
                  color: AppColors.error,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(children: [
                    const Icon(Icons.payments_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(
                            'حصّل من العميل ${formatCurrency(order.payableTotal - order.walletUsed + order.driverTip)} نقداً عند التسليم${order.driverTip > 0 ? " (منها إكراميتك " + formatCurrency(order.driverTip) + ")" : ""}',
                            'Collect ${formatCurrency(order.payableTotal - order.walletUsed + order.driverTip)} in cash from the customer on delivery${order.driverTip > 0 ? " (includes your " + formatCurrency(order.driverTip) + " tip)" : ""}'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5),
                      ),
                    ),
                  ]),
                ),
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: targetPoint, initialZoom: 14),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.zadam.delivery',
                    ),
                    if (polyPoints.length > 1)
                      PolylineLayer(polylines: [
                        Polyline(points: polyPoints, strokeWidth: 4, color: AppColors.primary),
                      ]),
                    MarkerLayer(markers: points),
                    const OsmAttribution(),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 100,
            left: 16,
            child: FloatingActionButton.small(
              heroTag: 'recenter',
              backgroundColor: Colors.white,
              onPressed: () =>
                  _animatedMap.animateTo(dest: targetPoint, zoom: 15),
              child: const Icon(Icons.my_location, color: AppColors.dark),
            ),
          ),
        ],
      ),
      // ✅ الشريط السفلي بأكمله يخص السائق فقط الآن (زر الملاحة الخارجية +
      // أزرار تغيير حالة الطلب). العميل يرى خريطة المتابعة فقط دون أي زر
      // أسفلها، لأن "ابدأ الملاحة" لا معنى له لمن لا يقود لأي مكان.
      bottomNavigationBar: widget.readOnly
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openExternalNavigation(
                            targetPoint.latitude, targetPoint.longitude),
                        icon: const Icon(Icons.navigation),
                        label: Text(tr('ابدأ الملاحة', 'Start navigation')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (_canPickUp || _headingToCustomer)
                      const SizedBox(width: 10),
                    if (_canPickUp)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final done = await DriverProofFlow.confirmPickup(
                                context, service, order);
                            if (done && context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(tr('استلمت الطلب', 'Picked up')),
                        ),
                      ),
                    if (_headingToCustomer)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final done = await DriverProofFlow.confirmDelivery(
                                context, service, order);
                            if (done && context.mounted) {
                              showSuccess(
                                  context,
                                  order.paymentMethod == PaymentMethod.cash
                                      ? tr('تم التوصيل! أجرتك ${order.driverShare.toStringAsFixed(2)} ر.س ضمن المبلغ الذي حصّلته',
                                          'Delivered! Your ${order.driverShare.toStringAsFixed(2)} SAR fee is part of the cash you collected')
                                      : tr('تم التوصيل! +${order.driverShare.toStringAsFixed(2)} ر.س أُضيفت لمحفظتك',
                                          'Delivered! ${order.driverShare.toStringAsFixed(2)} SAR was added to your wallet'));
                              Navigator.pop(context);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.success,
                            side: const BorderSide(color: AppColors.success),
                          ),
                          icon: const Icon(Icons.done_all_rounded),
                          label: Text(tr('تم التوصيل', 'Delivered')),
                        ),
                      ),
                    // «تعذّر التسليم» (درع النقد): مخرجُ كابتنٍ على بابٍ
                    // لا يُفتح — أيقونة صغيرة لا زر عريض: خيار اضطرار
                    // لا دعوة ضغط، والحوار يشرح ما سيقع قبل التأكيد.
                    if (_headingToCustomer && !order.deliveryFailed)
                      IconButton(
                        tooltip: tr('تعذّر التسليم', 'Couldn\'t deliver'),
                        onPressed: () => _reportDeliveryFailure(service),
                        icon: const Icon(Icons.report_problem_outlined,
                            color: AppColors.error),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  /// حوار «تعذّر التسليم»: سببٌ يُختار لا نصٌّ حر — الأسباب الثلاثة تغطي
  /// الواقع وتُبقي عدَّ «رفض الاستلام» النقدي (أساس الحظر) نظيفاً من
  /// اجتهادات الصياغة. لا يغلق الطلب: يُعلّمه أحمرَ عند الإدارة وتقرّر.
  Future<void> _reportDeliveryFailure(FirebaseService service) async {
    const reasons = [
      'العميل لا يردّ على الاتصال',
      'العميل رفض استلام الطلب',
      'العنوان خاطئ ولا يمكن الوصول',
    ];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(tr('ما الذي منع التسليم؟', 'What prevented delivery?'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
                tr(
                    'اتصل بالعميل أولاً. بعد الإبلاغ يبقى الطلب معك حتى '
                    'تقرّر الإدارة (إلغاء أو إعادة محاولة) — لا تتخلص من '
                    'الطلب ولا تغادر منطقتك.',
                    'Call the customer first. After reporting, keep the order '
                    'with you until support decides (cancel or retry) — don\'t '
                    'dispose of the order or leave your area.'),
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textGray)),
          ),
          const SizedBox(height: 6),
          for (final r in reasons)
            ListTile(
              leading: const Icon(Icons.chevron_left_rounded),
              title: Text(r, style: const TextStyle(fontSize: 13.5)),
              onTap: () => Navigator.pop(sheetCtx, r),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (chosen == null || !mounted) return;
    try {
      await service.markDeliveryFailed(widget.order, chosen);
      if (mounted) {
        showSuccess(
            context,
            tr('أُبلغت الإدارة — ستقرّر خلال دقائق، وأجرتك محفوظة',
                'Support was notified — they\'ll decide within minutes, and your fee is safe'));
      }
    } catch (_) {
      if (mounted) {
        showError(context,
            tr('تعذّر الإبلاغ — حاول مرة أخرى', 'Couldn\'t report — please try again'));
      }
    }
  }

  String _appBarTitle() {
    // ✅ العميل يرى دائماً "متابعة الطلب" بغض النظر عن مرحلة السائق الدقيقة
    // (متوجه للمطعم أو للعميل) — فهو يتابع فقط، لا يحتاج تمييز اتجاه السائق.
    if (widget.readOnly) return tr('متابعة الطلب', 'Track order');
    if (_headingToRestaurant) {
      return tr('التوجه إلى المطعم', 'Heading to the restaurant');
    }
    if (_headingToCustomer) {
      return tr('التوجه إلى العميل', 'Heading to the customer');
    }
    return tr('خريطة الطلب', 'Order map');
  }

  Widget _buildStatusBanner() {
    if (!_headingToRestaurant && !_headingToCustomer) return const SizedBox.shrink();
    // للمتابع (عميل/مطعم/مدير): «السائق في طريقه لاستلام طلبك» تُعرض فقط
    // إن وُجد سائق مُسند فعلاً — قبل الإسناد لا سائق في طريقه لأي مكان.
    if (widget.readOnly &&
        _headingToRestaurant &&
        (order.driverId == null || order.driverId!.isEmpty)) {
      return const SizedBox.shrink();
    }
    final isRestaurant = _headingToRestaurant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: isRestaurant ? AppColors.secondary.withOpacity(0.12) : AppColors.primary.withOpacity(0.1),
      child: Row(
        children: [
          Icon(isRestaurant ? Icons.restaurant : Icons.location_on,
              color: isRestaurant ? AppColors.secondary : AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.readOnly
                  ? (isRestaurant
                      ? tr('السائق في طريقه لاستلام طلبك',
                          'The driver is on the way to pick up your order')
                      : tr('السائق في طريقه إليك',
                          'The driver is on the way to you'))
                  : (isRestaurant
                      ? tr('توجّه إلى المطعم لاستلام الطلب',
                          'Head to the restaurant to pick up the order')
                      : tr('توجّه إلى العميل لتسليم الطلب',
                          'Head to the customer to deliver the order')),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPin({required IconData icon, required Color color, required bool highlighted}) {
    // لون الرمز يُشتقّ من إضاءة تعبئة الدبوس: الأبيض على الدبوس الذهبي (موقع
    // العميل) يذوب — الفاتح يأخذ رمزاً كحلياً والداكن يبقى أبيض.
    final onColor = color.computeLuminance() > 0.5 ? AppColors.dark : Colors.white;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: highlighted ? Border.all(color: Colors.white, width: 3) : null,
        boxShadow: highlighted
            ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 12, spreadRadius: 2)]
            : null,
      ),
      child: Icon(icon, color: onColor, size: highlighted ? 26 : 20),
    );
  }
}