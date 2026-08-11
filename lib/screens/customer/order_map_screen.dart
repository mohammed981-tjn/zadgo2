import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../utils/driver_proof_flow.dart';
import '../../widgets/common_widgets.dart';

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

class _OrderMapScreenState extends State<OrderMapScreen> {
  final MapController _mapController = MapController();
  int _driverStreamRetryToken = 0;

  Order get order => widget.order;

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

  Widget _buildScaffold(BuildContext context, FirebaseService service, Driver? liveDriver) {
    final points = <Marker>[];
    final polyPoints = <LatLng>[];

    final hasRestaurant = order.restaurantLat != null && order.restaurantLng != null;
    final hasDelivery = order.deliveryLat != null && order.deliveryLng != null;

    if (hasRestaurant) {
      final p = LatLng(order.restaurantLat!, order.restaurantLng!);
      polyPoints.add(p);
      points.add(Marker(
        point: p, width: 64, height: 64,
        child: _buildPin(icon: Icons.restaurant, color: Colors.orange, highlighted: _headingToRestaurant),
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
        appBar: AppBar(title: const Text('خريطة الطلب')),
        body: const Center(child: Text('لا توجد إحداثيات محفوظة لهذا الطلب')),
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
              tooltip: 'الاتصال بالعميل',
              icon: const Icon(Icons.call_outlined),
              onPressed: () => _call(order.customerPhone),
            ),
          if (liveDriver != null && liveDriver.phone.isNotEmpty)
            IconButton(
              tooltip: 'الاتصال بالسائق',
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
                        'حصّل من العميل ${formatCurrency(order.payableTotal - order.walletUsed)} نقداً عند التسليم',
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
              onPressed: () => _mapController.move(targetPoint, 15),
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
                        label: const Text('ابدأ الملاحة'),
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
                          label: const Text('استلمت الطلب'),
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
                                      ? 'تم التوصيل! أجرتك ${order.driverShare.toStringAsFixed(2)} ر.س ضمن المبلغ الذي حصّلته'
                                      : 'تم التوصيل! +${order.driverShare.toStringAsFixed(2)} ر.س أُضيفت لمحفظتك');
                              Navigator.pop(context);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.success,
                            side: const BorderSide(color: AppColors.success),
                          ),
                          icon: const Icon(Icons.done_all_rounded),
                          label: const Text('تم التوصيل'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  String _appBarTitle() {
    // ✅ العميل يرى دائماً "متابعة الطلب" بغض النظر عن مرحلة السائق الدقيقة
    // (متوجه للمطعم أو للعميل) — فهو يتابع فقط، لا يحتاج تمييز اتجاه السائق.
    if (widget.readOnly) return 'متابعة الطلب';
    if (_headingToRestaurant) return 'التوجه إلى المطعم';
    if (_headingToCustomer) return 'التوجه إلى العميل';
    return 'خريطة الطلب';
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
      color: isRestaurant ? Colors.orange.withOpacity(0.15) : AppColors.primary.withOpacity(0.1),
      child: Row(
        children: [
          Icon(isRestaurant ? Icons.restaurant : Icons.location_on,
              color: isRestaurant ? Colors.orange : AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.readOnly
                  ? (isRestaurant ? 'السائق في طريقه لاستلام طلبك' : 'السائق في طريقه إليك')
                  : (isRestaurant ? 'توجّه إلى المطعم لاستلام الطلب' : 'توجّه إلى العميل لتسليم الطلب'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPin({required IconData icon, required Color color, required bool highlighted}) {
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
      child: Icon(icon, color: Colors.white, size: highlighted ? 26 : 20),
    );
  }
}