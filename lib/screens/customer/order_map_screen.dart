import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';

class OrderMapScreen extends StatefulWidget {
  final Order order;
  final bool isDriverView;
  const OrderMapScreen({super.key, required this.order, this.isDriverView = false});

  @override
  State<OrderMapScreen> createState() => _OrderMapScreenState();
}

class _OrderMapScreenState extends State<OrderMapScreen> {
  final MapController _mapController = MapController();
  Position? _driverPosition;
  StreamSubscription<Position>? _positionSub;

  static const double _pickupRadiusMeters = 300;

  @override
  void initState() {
    super.initState();
    if (widget.isDriverView) _startPositionTracking();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _startPositionTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
      ).listen((pos) {
        if (mounted) setState(() => _driverPosition = pos);
      });
    } catch (_) {}
  }

  double? get _distanceToRestaurant {
    final pos = _driverPosition;
    if (pos == null || order.restaurantLat == null || order.restaurantLng == null) return null;
    const calc = Distance();
    return calc(LatLng(pos.latitude, pos.longitude), LatLng(order.restaurantLat!, order.restaurantLng!));
  }

  bool get _isNearRestaurant {
    final d = _distanceToRestaurant;
    return d != null && d <= _pickupRadiusMeters;
  }

  Order get order => widget.order;

  bool get _headingToRestaurant =>
      order.status == OrderStatus.pending ||
      order.status == OrderStatus.confirmed ||
      order.status == OrderStatus.preparing ||
      order.status == OrderStatus.readyForPickup;

  bool get _headingToCustomer => order.status == OrderStatus.outForDelivery;

  Future<void> _openExternalNavigation(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    if (order.driverId != null && order.status == OrderStatus.outForDelivery) {
      return StreamBuilder<Driver?>(
        stream: service.streamDriver(order.driverId!),
        builder: (ctx, driverSnap) => _buildScaffold(context, service, driverSnap.data),
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
      appBar: AppBar(title: Text(_appBarTitle())),
      body: Stack(
        children: [
          Column(
            children: [
              _buildStatusBanner(),
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
          // ✅ زر إعادة التوسيط على الهدف
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
      bottomNavigationBar: widget.isDriverView
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openExternalNavigation(targetPoint.latitude, targetPoint.longitude),
                        icon: const Icon(Icons.navigation),
                        label: const Text('ابدأ الملاحة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_headingToRestaurant)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isNearRestaurant
                              ? () async {
                                  final ok = await showConfirmDialog(context,
                                      title: 'استلام الطلب', content: 'هل استلمت الطلب من المطعم؟', confirmLabel: 'نعم');
                                  if (ok == true) {
                                    await service.updateOrderStatus(order.id, OrderStatus.outForDelivery);
                                    if (context.mounted) Navigator.pop(context);
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(_distanceToRestaurant == null
                              ? 'استلمت الطلب'
                              : _isNearRestaurant
                                  ? 'استلمت الطلب'
                                  : 'اقترب من المطعم (${_distanceToRestaurant!.toInt()} م)'),
                        ),
                      ),
                    if (_headingToCustomer)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await showConfirmDialog(context,
                                title: 'تأكيد التوصيل', content: 'هل تم توصيل الطلب للعميل؟', confirmLabel: 'نعم');
                            if (ok == true) {
                              await service.markOrderDelivered(order.id, order.driverId ?? '');
                              if (context.mounted) {
                                showSuccess(context, 'تم التوصيل! +10 ر.س أرباح');
                                Navigator.pop(context);
                              }
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
            )
          : null,
    );
  }

  String _appBarTitle() {
    if (widget.isDriverView) {
      if (_headingToRestaurant) return 'التوجه إلى المطعم';
      if (_headingToCustomer) return 'التوجه إلى العميل';
      return 'توجيه التسليم';
    }
    if (_headingToRestaurant) return 'التوجه إلى المطعم';
    if (_headingToCustomer) return 'التوجه إلى العميل';
    return 'خريطة الطلب';
  }

  Widget _buildStatusBanner() {
    if (!_headingToRestaurant && !_headingToCustomer) return const SizedBox.shrink();
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
              isRestaurant ? 'توجّه إلى المطعم لاستلام الطلب' : 'توجّه إلى العميل لتسليم الطلب',
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