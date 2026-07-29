import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import '../../providers/firebase_service.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';

class OrderMapScreen extends StatelessWidget {
  final Order order;
  const OrderMapScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    if (order.driverId != null && order.status == OrderStatus.outForDelivery) {
      return StreamBuilder<Driver?>(
        stream: service.streamDriver(order.driverId!),
        builder: (ctx, driverSnap) => _buildMap(context, driverSnap.data),
      );
    }
    return _buildMap(context, null);
  }

  // ✅ تحديد الوجهة النشطة حسب حالة الطلب
  bool get _headingToRestaurant =>
      order.status == OrderStatus.confirmed ||
      order.status == OrderStatus.preparing ||
      order.status == OrderStatus.readyForPickup;

  bool get _headingToCustomer => order.status == OrderStatus.outForDelivery;

  Widget _buildMap(BuildContext context, Driver? liveDriver) {
    final points = <Marker>[];
    final polyPoints = <LatLng>[];

    final hasRestaurant = order.restaurantLat != null && order.restaurantLng != null;
    final hasDelivery = order.deliveryLat != null && order.deliveryLng != null;

    if (hasRestaurant) {
      final p = LatLng(order.restaurantLat!, order.restaurantLng!);
      polyPoints.add(p);
      points.add(Marker(
        point: p,
        width: 64,
        height: 64,
        child: _buildPin(
          icon: Icons.restaurant,
          color: Colors.orange,
          highlighted: _headingToRestaurant,
        ),
      ));
    }

    if (hasDelivery) {
      final p = LatLng(order.deliveryLat!, order.deliveryLng!);
      polyPoints.add(p);
      points.add(Marker(
        point: p,
        width: 64,
        height: 64,
        child: _buildPin(
          icon: Icons.location_on,
          color: AppColors.primary,
          highlighted: _headingToCustomer,
        ),
      ));
    }

    if (liveDriver != null && liveDriver.lat != null && liveDriver.lng != null) {
      final p = LatLng(liveDriver.lat!, liveDriver.lng!);
      points.add(Marker(
        point: p,
        width: 50,
        height: 50,
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

    final center = points[0].point;

    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitle())),
      body: Column(
        children: [
          _buildStatusBanner(),
          Expanded(
            child: FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 14),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: isRestaurant ? Colors.orange.withOpacity(0.15) : AppColors.primary.withOpacity(0.1),
      child: Row(
        children: [
          Icon(
            isRestaurant ? Icons.restaurant : Icons.location_on,
            color: isRestaurant ? Colors.orange : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isRestaurant
                  ? 'توجّه إلى المطعم لاستلام الطلب'
                  : 'توجّه إلى العميل لتسليم الطلب',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPin({required IconData icon, required Color color, required bool highlighted}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
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
        ),
      ],
    );
  }
}