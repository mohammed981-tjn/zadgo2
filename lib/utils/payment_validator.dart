// lib/utils/payment_validator.dart

/// Validates credit-card fields without connecting to any real payment gateway.
class PaymentValidator {
  /// Validates a card number using the Luhn algorithm.
  /// Accepts digits with optional spaces or dashes.
  static bool validateCardNumber(String number) {
    final digits = number.replaceAll(RegExp(r'[\s\-]'), '');
    if (digits.length < 13 || digits.length > 19) return false;
    if (!RegExp(r'^\d+$').hasMatch(digits)) return false;

    int sum = 0;
    bool alternate = false;
    for (int i = digits.length - 1; i >= 0; i--) {
      int n = int.parse(digits[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  /// Validates an expiry date in MM/YY format and checks it is not expired.
  static bool validateExpiry(String expiry) {
    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(expiry.trim());
    if (match == null) return false;

    final month = int.parse(match.group(1)!);
    final year = int.parse(match.group(2)!);
    if (month < 1 || month > 12) return false;

    final now = DateTime.now();
    final currentYear = now.year % 100;
    final currentMonth = now.month;

    if (year < currentYear) return false;
    if (year == currentYear && month < currentMonth) return false;
    return true;
  }

  /// Validates a CVV: must be 3 or 4 digits.
  static bool validateCVV(String cvv) {
    return RegExp(r'^\d{3,4}$').hasMatch(cvv.trim());
  }

  /// Returns a combined error message, or null when all fields are valid.
  static String? validate({
    required String cardNumber,
    required String expiry,
    required String cvv,
    required String holderName,
  }) {
    if (holderName.trim().isEmpty) return 'أدخل اسم حامل البطاقة';
    if (!validateCardNumber(cardNumber)) return 'رقم البطاقة غير صحيح';
    if (!validateExpiry(expiry)) return 'تاريخ الانتهاء غير صحيح أو منتهي';
    if (!validateCVV(cvv)) return 'رمز CVV غير صحيح';
    return null;
  }
}
