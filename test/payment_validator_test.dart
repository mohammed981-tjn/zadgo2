// test/payment_validator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zadam_delivery/utils/payment_validator.dart';

void main() {
  // ---------------------------------------------------------------------------
  // validateCardNumber – Luhn algorithm
  // ---------------------------------------------------------------------------
  group('PaymentValidator.validateCardNumber', () {
    test('accepts a valid Visa test number', () {
      expect(PaymentValidator.validateCardNumber('4111111111111111'), isTrue);
    });

    test('accepts number with spaces', () {
      expect(PaymentValidator.validateCardNumber('4111 1111 1111 1111'), isTrue);
    });

    test('accepts number with dashes', () {
      expect(PaymentValidator.validateCardNumber('4111-1111-1111-1111'), isTrue);
    });

    test('rejects a number that fails the Luhn check', () {
      expect(PaymentValidator.validateCardNumber('4111111111111112'), isFalse);
    });

    test('rejects empty string', () {
      expect(PaymentValidator.validateCardNumber(''), isFalse);
    });

    test('rejects a number that is too short', () {
      expect(PaymentValidator.validateCardNumber('411111111'), isFalse);
    });

    test('rejects non-digit characters', () {
      expect(PaymentValidator.validateCardNumber('4111abcd11111111'), isFalse);
    });

    test('accepts a valid Mastercard test number', () {
      expect(PaymentValidator.validateCardNumber('5500005555555559'), isTrue);
    });

    test('accepts a valid Amex test number (15 digits)', () {
      expect(PaymentValidator.validateCardNumber('378282246310005'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // validateExpiry
  // ---------------------------------------------------------------------------
  group('PaymentValidator.validateExpiry', () {
    final now = DateTime.now();
    final currentYear = now.year % 100;
    final currentMonth = now.month;

    test('accepts a valid future date', () {
      final futureYear = (currentYear + 2).toString().padLeft(2, '0');
      expect(PaymentValidator.validateExpiry('12/$futureYear'), isTrue);
    });

    test('accepts current month/year', () {
      final month = currentMonth.toString().padLeft(2, '0');
      final year = currentYear.toString().padLeft(2, '0');
      expect(PaymentValidator.validateExpiry('$month/$year'), isTrue);
    });

    test('rejects an expired past year', () {
      final pastYear = (currentYear - 1).toString().padLeft(2, '0');
      expect(PaymentValidator.validateExpiry('12/$pastYear'), isFalse);
    });

    test('rejects an expired past month in current year', () {
      if (currentMonth > 1) {
        final pastMonth = (currentMonth - 1).toString().padLeft(2, '0');
        final year = currentYear.toString().padLeft(2, '0');
        expect(PaymentValidator.validateExpiry('$pastMonth/$year'), isFalse);
      }
    });

    test('rejects invalid month 00', () {
      expect(PaymentValidator.validateExpiry('00/30'), isFalse);
    });

    test('rejects invalid month 13', () {
      expect(PaymentValidator.validateExpiry('13/30'), isFalse);
    });

    test('rejects wrong format (MMYY without slash)', () {
      expect(PaymentValidator.validateExpiry('1230'), isFalse);
    });

    test('rejects empty string', () {
      expect(PaymentValidator.validateExpiry(''), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // validateCVV
  // ---------------------------------------------------------------------------
  group('PaymentValidator.validateCVV', () {
    test('accepts 3-digit CVV', () {
      expect(PaymentValidator.validateCVV('123'), isTrue);
    });

    test('accepts 4-digit CVV (Amex)', () {
      expect(PaymentValidator.validateCVV('1234'), isTrue);
    });

    test('rejects 2-digit CVV', () {
      expect(PaymentValidator.validateCVV('12'), isFalse);
    });

    test('rejects 5-digit CVV', () {
      expect(PaymentValidator.validateCVV('12345'), isFalse);
    });

    test('rejects letters', () {
      expect(PaymentValidator.validateCVV('abc'), isFalse);
    });

    test('rejects empty string', () {
      expect(PaymentValidator.validateCVV(''), isFalse);
    });

    test('accepts CVV with surrounding whitespace', () {
      expect(PaymentValidator.validateCVV(' 123 '), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // validate (combined)
  // ---------------------------------------------------------------------------
  group('PaymentValidator.validate', () {
    const validNumber = '4111111111111111';
    const validCVV = '123';

    String validExpiry() {
      final now = DateTime.now();
      final month = now.month.toString().padLeft(2, '0');
      final year = (now.year % 100 + 2).toString().padLeft(2, '0');
      return '$month/$year';
    }

    test('returns null when all fields are valid', () {
      expect(
        PaymentValidator.validate(
          holderName: 'Ahmed Ali',
          cardNumber: validNumber,
          expiry: validExpiry(),
          cvv: validCVV,
        ),
        isNull,
      );
    });

    test('returns error when holder name is empty', () {
      expect(
        PaymentValidator.validate(
          holderName: '   ',
          cardNumber: validNumber,
          expiry: validExpiry(),
          cvv: validCVV,
        ),
        isNotNull,
      );
    });

    test('returns error when card number is invalid', () {
      expect(
        PaymentValidator.validate(
          holderName: 'Ahmed',
          cardNumber: '1234567890123456',
          expiry: validExpiry(),
          cvv: validCVV,
        ),
        isNotNull,
      );
    });

    test('returns error when expiry is invalid', () {
      expect(
        PaymentValidator.validate(
          holderName: 'Ahmed',
          cardNumber: validNumber,
          expiry: '01/01',
          cvv: validCVV,
        ),
        isNotNull,
      );
    });

    test('returns error when CVV is invalid', () {
      expect(
        PaymentValidator.validate(
          holderName: 'Ahmed',
          cardNumber: validNumber,
          expiry: validExpiry(),
          cvv: '12',
        ),
        isNotNull,
      );
    });
  });
}
