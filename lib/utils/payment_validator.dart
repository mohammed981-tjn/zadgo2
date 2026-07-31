import 'package:flutter/services.dart';

class CreditCardValidationResult {
  final bool isValid;
  final String? errorMessage;

  const CreditCardValidationResult({required this.isValid, this.errorMessage});
}

String? validateCreditCardHolderName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'أدخل اسم حامل البطاقة';
  if (trimmed.split(RegExp(r'\s+')).length < 2) {
    return 'أدخل الاسم كما يظهر على البطاقة';
  }
  return null;
}

String? validateCreditCardNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 13 || digits.length > 19) {
    return 'رقم البطاقة غير صحيح';
  }
  if (!isLuhnValid(digits)) {
    return 'رقم البطاقة غير صحيح';
  }
  return null;
}

String? validateCreditCardExpiry(String value) {
  final trimmed = value.trim();
  final match = RegExp(r'^(0[1-9]|1[0-2])\/(\d{2}|\d{4})$').firstMatch(trimmed);
  if (match == null) return 'تاريخ الانتهاء غير صحيح';

  final month = int.parse(match.group(1)!);
  final yearText = match.group(2)!;
  final year = yearText.length == 2 ? 2000 + int.parse(yearText) : int.parse(yearText);

  final now = DateTime.now();
  final expiryMonth = month;
  final expiryYear = year;

  if (expiryYear < now.year ||
      (expiryYear == now.year && expiryMonth < now.month)) {
    return 'البطاقة منتهية';
  }

  return null;
}

String? validateCreditCardCvv(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 3 && digits.length != 4) {
    return 'رمز الأمان غير صحيح';
  }
  return null;
}

String formatCreditCardNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final groups = <String>[];
  for (var i = 0; i < digits.length; i += 4) {
    final end = i + 4;
    groups.add(digits.substring(i, end < digits.length ? end : digits.length));
  }
  return groups.join(' ');
}

String formatCreditCardExpiry(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 2) return digits;
  return '${digits.substring(0, 2)}/${digits.substring(2)}';
}

bool isLuhnValid(String value) {
  if (value.isEmpty) return false;
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 2) return false;

  var sum = 0;
  var shouldDouble = false;
  for (var i = digits.length - 1; i >= 0; i--) {
    var digit = int.parse(digits[i]);
    if (shouldDouble) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
    shouldDouble = !shouldDouble;
  }
  return sum % 10 == 0;
}

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final formatted = formatCreditCardNumber(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final formatted = formatCreditCardExpiry(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
