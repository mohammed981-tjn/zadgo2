// lib/providers/route_service.dart
//
// المسارات الحقيقية (دفعة و3) — غلاف openrouteservice.
//
// قبلها كانت كل مسافة في المنصّة خطاً مستقيماً (haversine) وكل وقتٍ
// قسمةً على ٢٠ كم/س: بطاقة التتبّع تكذب على العميل كلما فصل بين الكابتن
// وبيته جسرٌ أو دوران أو طريق مغلق. هذا الغلاف يجلب **مسافة الطريق
// الفعلية وزمنه** من openrouteservice (واجهتهم المجانية ~٢٠٠٠ نداء
// يومياً — أضعاف حجمنا)، ويسقط على الخط المستقيم بهدوء عند أي عطل.
//
// المفتاح يُمرَّر وقت البناء ولا يُكتب في الكود:
//   --dart-define=ORS_API_KEY=...
// (مفتاح مجاني من openrouteservice.org — يُضبط سرّاً في GitHub.)
// وبدونه يبقى التطبيق كما كان بالضبط: كل النداءات تُتجاهل، فالميزة
// «تعمل مظلمةً» حتى يصل المفتاح — لا كسر ولا انتظار إصدار جديد.
import 'package:flutter/foundation.dart';
import 'package:open_route_service/open_route_service.dart';

/// خلاصة مسارٍ واحد: مسافة الطريق وزمنه ونقاطه للرسم على الخريطة.
class RouteInfo {
  final double distanceKm;
  final double durationMinutes;

  /// نقاط المسار (خط سير الطريق) — أزواج [lat, lng] للرسم على flutter_map.
  final List<(double, double)> points;

  const RouteInfo({
    required this.distanceKm,
    required this.durationMinutes,
    required this.points,
  });
}

class RouteService {
  RouteService._();

  static const String _apiKey = String.fromEnvironment('ORS_API_KEY');

  static bool get isConfigured => _apiKey.trim().isNotEmpty;

  static OpenRouteService? _client;

  // مخبأ بمفتاح شبكي مقرَّب (~١١٠م لكل خانة ثالثة) وصلاحية ٩٠ ثانية:
  // الكابتن يتحرك فمن العبث نداء الواجهة مع كل تحديث موقع — والمسار بين
  // مربّعين شبكيين متجاورين لا يتغير جوهرياً. وهذا ما يُبقينا في حدود
  // الواجهة المجانية مهما فُتحت شاشة التتبّع.
  static final Map<String, (DateTime, RouteInfo)> _cache = {};
  static const Duration _ttl = Duration(seconds: 90);

  static String _key(double a, double b, double c, double d) =>
      '${a.toStringAsFixed(3)},${b.toStringAsFixed(3)}'
      '→${c.toStringAsFixed(3)},${d.toStringAsFixed(3)}';

  /// مسار القيادة من نقطة إلى نقطة، أو null (غير مهيّأ/عطل) — فيبقى
  /// المستدعي على حساب الخط المستقيم كما كان.
  static Future<RouteInfo?> drivingRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    if (!isConfigured) return null;
    final key = _key(fromLat, fromLng, toLat, toLng);
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.$1) < _ttl) {
      return hit.$2;
    }
    try {
      _client ??= OpenRouteService(
        apiKey: _apiKey.trim(),
        defaultProfile: ORSProfile.drivingCar,
      );
      final fc = await _client!.directionsRouteGeoJsonGet(
        startCoordinate: ORSCoordinate(latitude: fromLat, longitude: fromLng),
        endCoordinate: ORSCoordinate(latitude: toLat, longitude: toLng),
      );
      if (fc.features.isEmpty) return null;
      final feature = fc.features.first;
      // الحقول من properties الخام لا من نموذج مفروض: الواجهة تُرجع
      // summary{distance بالمتر, duration بالثانية} في مسار geojson.
      final summary =
          (feature.properties['summary'] as Map?)?.cast<String, dynamic>();
      if (summary == null) return null;
      final distanceM = (summary['distance'] as num?)?.toDouble() ?? 0;
      final durationS = (summary['duration'] as num?)?.toDouble() ?? 0;
      final coords = feature.geometry.coordinates;
      final points = <(double, double)>[
        for (final line in coords)
          for (final c in line) (c.latitude, c.longitude),
      ];
      final info = RouteInfo(
        distanceKm: distanceM / 1000,
        durationMinutes: durationS / 60,
        points: points,
      );
      _cache[key] = (DateTime.now(), info);
      // تنظيف بدائي يمنع نمو المخبأ بلا حد في جلسة طويلة.
      if (_cache.length > 40) {
        _cache.removeWhere(
            (_, v) => DateTime.now().difference(v.$1) > _ttl);
      }
      return info;
    } catch (e) {
      debugPrint('RouteService: $e');
      return null;
    }
  }
}
