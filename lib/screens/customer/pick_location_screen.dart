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
  final MapController _mapController = MapController();

  /// مركز مبدئي للخريطة حين لا يتوفّر موقع بعد — **لعرض الخريطة فقط**، ولا
  /// يُعامَل موقعاً مختاراً. سابقاً كان يُسند مباشرةً إلى الموقع المختار،
  /// فيؤكّد العميل «الرياض» ظنّاً أنها موقعه بينما تعذّر تحديد موقعه فعلاً —
  /// ومن هنا نشأت طلبات بمسافات مئات الكيلومترات.
  static const LatLng _mapStartCenter = LatLng(24.7136, 46.6753);

  /// الموقع المختار فعلياً: من GPS أو بنقرة العميل. `null` يعني «لم يُختر
  /// موقع بعد»، فيبقى زر التأكيد معطّلاً ولا يُرسَل موقع لم يقصده أحد.
  LatLng? _selected;

  bool _loadingGps = true;
  String? _gpsError;

  /// هل الموقع المُلتقط من GPS مُحاكى (محاكي أو تطبيق موقع وهمي)؟ يُعرض
  /// تحذيراً لأن العنوان الناتج لن يطابق موقع العميل الحقيقي، فيصل السائق
  /// إلى مكان خاطئ.
  bool _mockedLocation = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;

    // تحديد الموقع تلقائيًا بعد بناء الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCurrentLocation());
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _loadingGps = true;
      _gpsError = null;
      _mockedLocation = false;
    });

    try {
      // التأكد من تفعيل خدمة الموقع
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() {
          _loadingGps = false;
          _gpsError = 'خدمة الموقع غير مفعّلة على الجهاز';
        });
        return;
      }

      // طلب الإذن
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _loadingGps = false;
          _gpsError = 'تم رفض إذن الوصول للموقع';
        });
        return;
      }

      // الحصول على الموقع
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (!mounted) return;

      final point = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _selected = point;
        _loadingGps = false;
        // geolocator يبلّغ صراحةً إن كان الموقع مُحاكى — وهي الحالة المعتادة
        // على المحاكي أو مع تطبيقات الموقع الوهمي.
        _mockedLocation = pos.isMocked;
      });

      // تحريك الكاميرا
      _mapController.move(point, 16);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingGps = false;
        _gpsError = 'تعذّر تحديد موقعك الحالي';
      });
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selected = point;
      // اختيار يدوي صريح يلغي أي تحذير سابق — العميل حدّد موقعه بنفسه.
      _gpsError = null;
      _mockedLocation = false;
    });
    _mapController.move(point, 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختيار الموقع'),
        actions: [
          IconButton(
            tooltip: 'تحديد موقعي الحالي',
            icon: _loadingGps
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.my_location),
            onPressed: _loadingGps ? null : _fetchCurrentLocation,
          ),
        ],
      ),

      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selected ?? _mapStartCenter,
              initialZoom: 15,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.zadam.delivery',
              ),
              // لا تُعرض علامة إلا لموقع مختار فعلاً، فلا يظنّ العميل أن
              // موقعاً افتراضياً هو موقعه.
              if (_selected != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selected!,
                      width: 50,
                      height: 50,
                      child: Icon(
                        Icons.location_on,
                        color: _mockedLocation
                            ? AppColors.warning
                            : AppColors.primary,
                        size: 44,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // تحذير الموقع المُحاكى — أخطر من فشل التحديد، لأن الموقع يبدو
          // صحيحاً وليس كذلك، فيصل السائق إلى مكان لا يسكنه العميل.
          if (_mockedLocation)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.gps_off_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'الموقع المُلتقط مُحاكى وليس حقيقياً — اضغط على الخريطة '
                        'لتحديد موقعك الفعلي',
                        style: TextStyle(color: Colors.white, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // رسالة الخطأ
          if (_gpsError != null && !_mockedLocation)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _gpsError!,
                        style: const TextStyle(color: Colors.white, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // نص إرشادي
          Positioned(
            bottom: 90,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _selected == null
                      ? 'اضغط على الخريطة لتحديد موقعك'
                      : 'اضغط على الخريطة لتعديل الموقع',
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                ),
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              // لا تأكيد بلا موقع مختار: سابقاً كان الزر يعيد الموقع
              // الافتراضي (الرياض) حتى لو لم يُحدَّد شيء إطلاقاً.
              onPressed: _selected == null
                  ? null
                  : () => Navigator.pop(context, _selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: Text(
                _selected == null ? 'حدّد موقعاً أولاً' : 'تأكيد هذا الموقع',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}