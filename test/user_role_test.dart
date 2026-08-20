import 'package:flutter_test/flutter_test.dart';
import 'package:zadam_delivery/models/models.dart';

// الدور الخامس (موظف الدعم — دفعة 2026-08-20) دخل منظومةً كل مفاتيحها
// نصية في Firestore: هذه الاختبارات تثبّت أن اسمه يذهب ويعود سليماً، وأن
// حساباً قديماً بدورٍ لم يعرفه إصدارٌ سابق لا يكسر القراءة بل يسقط
// لعميل — فأخطر ما في توسيع الأدوار أن يُقفل تطبيقٌ قديم على استثناء.
void main() {
  group('دور موظف الدعم', () {
    test('يُكتب ويُقرأ باسمه النصي عبر مستند المستخدم', () {
      final u = AppUser.fromMap(const {
        'name': 'سارة',
        'email': 's@zadgo.co',
        'role': 'support',
      }, 'u1');
      expect(u.role, UserRole.support);
      expect(u.toMap()['role'], 'support');
    });

    test('له تسمية عربية ظاهرة لا فراغاً', () {
      expect(UserRole.support.label, 'موظف دعم');
    });

    test('دور غير معروف يسقط لعميل ولا يرمي — حماية الإصدارات القديمة', () {
      final u = AppUser.fromMap(const {
        'name': 'x',
        'email': 'x@x.co',
        'role': 'fleetOperator',
      }, 'u2');
      expect(u.role, UserRole.customer);
    });

    test('يقدّم شكوى بكل الأنواع كالمدير — يسجّلها نيابةً عن المتصلين', () {
      expect(ComplaintTypeScope.typesForRole(UserRole.support),
          ComplaintType.values);
    });
  });
}
