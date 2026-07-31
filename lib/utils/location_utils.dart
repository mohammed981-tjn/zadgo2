import 'package:geolocator/geolocator.dart';

class LocationCheckResult {
  final bool isAvailable;
  final bool isWithinThreshold;
  final double? distanceMeters;
  final String? errorMessage;

  const LocationCheckResult({
    required this.isAvailable,
    required this.isWithinThreshold,
    this.distanceMeters,
    this.errorMessage,
  });
}

Future<LocationCheckResult> checkDriverProximity({
  required double targetLat,
  required double targetLng,
  required double thresholdMeters,
}) async {
  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return const LocationCheckResult(
          isAvailable: false,
          isWithinThreshold: false,
          errorMessage: 'تم رفض إذن الموقع',
        );
      }
    }

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    final distance = Geolocator.distanceBetween(targetLat, targetLng, position.latitude, position.longitude);
    return LocationCheckResult(
      isAvailable: true,
      isWithinThreshold: distance <= thresholdMeters,
      distanceMeters: distance,
    );
  } catch (_) {
    return const LocationCheckResult(
      isAvailable: false,
      isWithinThreshold: false,
      errorMessage: 'تعذر تحديد موقعك حالياً',
    );
  }
}
