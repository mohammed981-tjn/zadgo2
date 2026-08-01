import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/theme.dart';

class PickLocationScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const PickLocationScreen({super.key, this.initialLocation});

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  late LatLng _selected;
  final MapController _mapController = MapController();
  bool _locating = false;

  static const LatLng _defaultLocation = LatLng(24.7136, 46.6753);

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation ?? _defaultLocation;
    if (widget.initialLocation == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToMyLocation());
    }
  }

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final newLoc = LatLng(pos.latitude, pos.longitude);
      setState(() => _selected = newLoc);
      _mapController.move(newLoc, 16);
    } catch (_) {
      // في حالة الفشل نبقى على الموقع الافتراضي
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختر الموقع'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.pop(context, _selected),
            tooltip: 'تأكيد الموقع',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selected,
              initialZoom: 13,
              onTap: (tapPosition, point) {
                setState(() => _selected = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.zadam.delivery',
              ),
              MarkerLayer(markers: [
                Marker(
                  point: _selected,
                  width: 60,
                  height: 60,
                  child: const Icon(Icons.location_pin, color: AppColors.primary, size: 48),
                ),
              ]),
            ],
          ),
          // زر موقعي الحالي
          Positioned(
            top: 16,
            left: 16,
            child: FloatingActionButton.small(
              heroTag: 'myLocation',
              backgroundColor: Colors.white,
              onPressed: _locating ? null : _goToMyLocation,
              tooltip: 'موقعي الحالي',
              child: _locating
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('خط العرض: ${_selected.latitude.toStringAsFixed(6)}'),
                    Text('خط الطول: ${_selected.longitude.toStringAsFixed(6)}'),
                    const SizedBox(height: 8),
                    const Text('اضغط على أي مكان في الخريطة لتحديد الموقع',
                        style: TextStyle(fontSize: 12, color: AppColors.textGray)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
