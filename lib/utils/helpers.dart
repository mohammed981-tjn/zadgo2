import 'package:flutter/material.dart';
import '../utils/theme.dart';

String formatCurrency(double amount) => '${amount.toStringAsFixed(2)} ر.س';

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