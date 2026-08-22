import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../utils/app_lang.dart';
import '../../utils/theme.dart';
import '../../widgets/osm_attribution.dart';

class PickLocationScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const PickLocationScreen({super.key, this.initialLocation});

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  late LatLng _selected;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation ?? const LatLng(24.7136, 46.6753);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('اختر الموقع', 'Pick location')),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.pop(context, _selected),
            tooltip: tr('تأكيد الموقع', 'Confirm location'),
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
              const OsmAttribution(),
            ],
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
                    Text(tr('خط العرض: ${_selected.latitude.toStringAsFixed(6)}',
                        'Latitude: ${_selected.latitude.toStringAsFixed(6)}')),
                    Text(tr('خط الطول: ${_selected.longitude.toStringAsFixed(6)}',
                        'Longitude: ${_selected.longitude.toStringAsFixed(6)}')),
                    const SizedBox(height: 8),
                    Text(tr('اضغط على أي مكان في الخريطة لتحديد الموقع',
                            'Tap anywhere on the map to set the location'),
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textGray)),
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
