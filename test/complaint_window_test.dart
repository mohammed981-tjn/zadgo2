import 'package:flutter_test/flutter_test.dart';
import 'package:zadam_delivery/widgets/complaint_window.dart';

void main() {
  group('صياغة المدة المتبقية بالعربية', () {
    test('الساعات: مفرد ومثنّى وجمع قلّة وجمع كثرة', () {
      expect(formatRemaining(const Duration(hours: 1)), 'ساعة واحدة');
      expect(formatRemaining(const Duration(hours: 2)), 'ساعتان');
      expect(formatRemaining(const Duration(hours: 5)), '5 ساعات');
      expect(formatRemaining(const Duration(hours: 10)), '10 ساعات');
      expect(formatRemaining(const Duration(hours: 23)), '23 ساعة');
    });

    test('الدقائق تظهر حين يتبقّى أقل من ساعة', () {
      expect(formatRemaining(const Duration(minutes: 59)), '59 دقيقة');
      expect(formatRemaining(const Duration(minutes: 10)), '10 دقائق');
      expect(formatRemaining(const Duration(minutes: 2)), 'دقيقتان');
      expect(formatRemaining(const Duration(minutes: 1)), 'دقيقة واحدة');
    });

    test('ما دون الدقيقة لا يُعرض صفراً', () {
      expect(formatRemaining(const Duration(seconds: 40)), 'أقل من دقيقة');
      expect(formatRemaining(Duration.zero), 'أقل من دقيقة');
    });

    test('الساعة والدقائق معاً تُقرَّب للساعات — لا خلط بين الوحدتين', () {
      expect(formatRemaining(const Duration(hours: 1, minutes: 45)), 'ساعة واحدة');
      expect(formatRemaining(const Duration(hours: 3, minutes: 59)), '3 ساعات');
    });
  });
}
