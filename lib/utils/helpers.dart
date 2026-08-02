import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/theme.dart';

String formatCurrency(double amount) => '${amount.toStringAsFixed(2)} ر.س';

void showSuccess(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.success));
}

void showError(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
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

/// المسافة بالكيلومترات بين نقطتين باستخدام معادلة Haversine.
double haversineDistanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLng = _deg2rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _deg2rad(double deg) => deg * (math.pi / 180.0);

/// عدد الكيلومترات الإضافية بعد المسافة المجانية — لا تُحسب كسور الكيلومتر،
/// بل تُجبر للأعلى دائماً (Ceil) حتى لو كان الكسر بسيطاً.
int ceilExtraKm(double distanceKm, double freeKm) {
  final extra = distanceKm - freeKm;
  if (extra <= 0) return 0;
  return extra.ceil();
}

/// أجرة الكيلومترات الإضافية بعد إجبار التقريب للأعلى — بدون كسور.
double calculateExtraKmFee(double distanceKm, double freeKm, double perKmFee) =>
    ceilExtraKm(distanceKm, freeKm) * perKmFee;