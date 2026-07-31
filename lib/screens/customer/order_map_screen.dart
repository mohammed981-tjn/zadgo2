import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/helpers.dart';
import '../../utils/theme.dart';

class OrderMapScreen extends StatefulWidget {
  final Order order;
  const OrderMapScreen({super.key, required this.order});

  @override
  State<OrderMapScreen> createState() => _OrderMapScreenState();
}

class _OrderMapScreenState extends State<OrderMapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  double? _distanceToRestaurant;

  Order get order => widget.order;

  bool get _headingToRestaurant =>
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

  bool get _canPickup => _distanceToRestaurant != null && _distanceToRestaurant! <= 450;

  @override
  void initState() {
    super.initState();
    unawaited(_startLocationTracking());
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startLocationTracking() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          return;
        }
      }

      final initialPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;

      setState(() {
        _currentPosition = initialPosition;
        _distanceToRestaurant = _distanceToTarget(initialPosition.latitude, initialPosition.longitude);
      });

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
      ).listen((position) {
        if (!mounted) return;
        setState(() {
          _currentPosition = position;
          _distanceToRestaurant = _distanceToTarget(position.latitude, position.longitude);
        });
      });
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  double? _distanceToTarget(double lat, double lng) {
    if (order.restaurantLat == null || order.restaurantLng == null) return null;
    return Geolocator.distanceBetween(order.restaurantLat!, order.restaurantLng!, lat, lng);
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

    if (_currentPosition != null) {
      points.add(Marker(
        point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude), width: 50, height: 50,
        child: Container(
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: const Icon(Icons.navigation, color: Colors.white, size: 22),
        ),
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
                      userAgentPackageName: 'com.dinego.delivery',
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ✅ زر ابدأ الملاحة الخارجية (Google Maps)
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
              // ✅ زر تحديث الحالة (يتغيّر حسب المرحلة)
              if (_headingToRestaurant)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _canPickup
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
                    label: const Text('استلمت الطلب'),
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
      ),
    );
  }

  String _appBarTitle() {
    if (_headingToRestaurant) return 'التوجه إلى المطعم';
    if (_headingToCustomer) return 'التوجه إلى العميل';
    return 'خريطة الطلب';
  }

  Widget _buildStatusBanner() {
    if (!_headingToRestaurant && !_headingToCustomer) return const SizedBox.shrink();
    final isRestaurant = _headingToRestaurant;
    final distanceText = isRestaurant && _distanceToRestaurant != null
        ? (_distanceToRestaurant! > 450
            ? 'المسافة المتبقية: ${_distanceToRestaurant!.round()} متر'
            : 'أنت قريب من المطعم — الزر جاهز للاستخدام')
        : null;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRestaurant ? 'توجّه إلى المطعم لاستلام الطلب' : 'توجّه إلى العميل لتسليم الطلب',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (distanceText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    distanceText,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
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