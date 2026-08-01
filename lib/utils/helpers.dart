import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/theme.dart';

String formatCurrency(double amount) => '${amount.toStringAsFixed(2)} ر.س';

/// Breakdown of a delivery fee: how much goes to the driver vs. the platform.
class DeliveryFeeBreakdown {
  final double driverEarning;
  final double platformFee;
  const DeliveryFeeBreakdown({required this.driverEarning, required this.platformFee});
  double get total => driverEarning + platformFee;
}

/// Computes the delivery fee split between driver and platform based on the
/// distance (in kilometers) between the restaurant and the customer.
///
/// Rules:
/// - Fractions of a kilometer are always rounded UP (e.g. 7.5 km → 8 km).
/// - Up to 7 km: the driver earns a flat 9 ر.س, plus a fixed 3 ر.س platform fee
///   (12 ر.س total delivery fee for the customer).
/// - Beyond 7 km: every extra whole kilometer adds 1 ر.س to the driver's
///   share, on top of the same fixed 3 ر.س platform fee.
DeliveryFeeBreakdown calculateDeliveryFee(double distanceKm) {
  final kmCeil = distanceKm.ceil();
  const double baseDriverEarning = 9.0;
  const double platformFee = 3.0;
  const int baseKm = 7;
  double driverEarning;
  if (kmCeil <= baseKm) {
    driverEarning = baseDriverEarning;
  } else {
    final extraKm = kmCeil - baseKm;
    driverEarning = baseDriverEarning + extraKm;
  }
  return DeliveryFeeBreakdown(driverEarning: driverEarning, platformFee: platformFee);
}

/// Distance in kilometers between two lat/lng points using the haversine
/// formula (avoids adding a dependency on the map package in this file).
double distanceKmBetween(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * (pi / 180);

void showSuccess(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.success));
}

void showError(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
}

Future<bool?> showConfirmDialog(BuildContext context, {required String title, required String content,
    String confirmLabel = 'تأكيد', Color? confirmColor}) => showDialog<bool>(
  context: context,
  barrierColor: Colors.black54,
  builder: (_) => AlertDialog(title: Text(title), content: Text(content), actions: [
    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
    ElevatedButton(onPressed: () => Navigator.pop(context, true),
        style: ElevatedButton.styleFrom(backgroundColor: confirmColor ?? AppColors.primary),
        child: Text(confirmLabel)),
  ]),
);

String? validateRequired(String? v, [String label = 'هذا الحقل']) =>
    (v == null || v.trim().isEmpty) ? '$label مطلوب' : null;

String? validateEmail(String? v) {
  if (v == null || v.trim().isEmpty) return 'البريد الإلكتروني مطلوب';
  if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) return 'صيغة غير صالحة';
  return null;
}

String? validatePassword(String? v) {
  if (v == null || v.isEmpty) return 'كلمة المرور مطلوبة';
  if (v.length < 6) return 'يجب أن تكون 6 أحرف على الأقل';
  return null;
}

String? validatePhone(String? v) => (v == null || v.trim().length < 9) ? 'رقم هاتف غير صالح' : null;

String? validatePrice(String? v) {
  if (v == null || v.trim().isEmpty) return 'السعر مطلوب';
  final n = double.tryParse(v.trim());
  if (n == null || n < 0) return 'سعر غير صالح';
  return null;
}