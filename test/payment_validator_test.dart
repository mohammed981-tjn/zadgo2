import 'package:flutter_test/flutter_test.dart';
import 'package:zadam_delivery/utils/payment_validator.dart';

void main() {
  group('credit card validation', () {
    test('accepts a valid card with future expiry and correct cvv', () {
      final holderError = validateCreditCardHolderName('John Doe');
      final numberError = validateCreditCardNumber('4111 1111 1111 1111');
      final expiryError = validateCreditCardExpiry('12/2030');
      final cvvError = validateCreditCardCvv('123');

      expect(holderError, isNull);
      expect(numberError, isNull);
      expect(expiryError, isNull);
      expect(cvvError, isNull);
    });

    test('rejects invalid luhn numbers', () {
      final error = validateCreditCardNumber('4111 1111 1111 1112');
      expect(error, 'رقم البطاقة غير صحيح');
    });

    test('rejects expired cards', () {
      final now = DateTime.now();
      final month = now.month == 1 ? 12 : now.month - 1;
      final year = now.month == 1 ? now.year - 1 : now.year;
      final expiry = '$month/${year.toString().substring(2)}';
      final error = validateCreditCardExpiry(expiry);
      expect(error, isNotNull);
    });

    test('rejects invalid cvv length', () {
      final error = validateCreditCardCvv('12');
      expect(error, 'رمز الأمان غير صحيح');
    });

    test('accepts card numbers with separators and trims whitespace', () {
      expect(validateCreditCardNumber(' 4111-1111 1111 1111 '), isNull);
    });

    test('rejects single-word holder names', () {
      expect(
        validateCreditCardHolderName('John'),
        'أدخل الاسم كما يظهر على البطاقة',
      );
    });

    test('formats card numbers and expiry values', () {
      expect(formatCreditCardNumber('4111111111111111'), '4111 1111 1111 1111');
      expect(formatCreditCardExpiry('122030'), '12/2030');
    });
  });
}
