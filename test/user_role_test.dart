import 'package:flutter_test/flutter_test.dart';
import 'package:zadam_delivery/models/models.dart';

// الدوران الخامس والسادس (موظف الدعم 2026-08-20، مشغّل الأسطول 2026-08-21)
// دخلا منظومةً كل مفاتيحها نصية في Firestore: هذه الاختبارات تثبّت أن اسم
// كلٍّ يذهب ويعود سليماً، وأن حساباً قديماً بدورٍ لم يعرفه إصدارٌ سابق لا
// يكسر القراءة بل يسقط لعميل — فأخطر ما في توسيع الأدوار أن يُقفل تطبيقٌ
// قديم على استثناء.
void main() {
  group('الأدوار المحدودة', () {
    test('موظف الدعم يُكتب ويُقرأ باسمه النصي', () {
      final u = AppUser.fromMap(const {
        'name': 'سارة',
        'email': 's@zadgo.co',
        'role': 'support',
      }, 'u1');
      expect(u.role, UserRole.support);
      expect(u.toMap()['role'], 'support');
    });

    test('مشغّل الأسطول يُكتب ويُقرأ باسمه النصي', () {
      final u = AppUser.fromMap(const {
        'name': 'مؤسسة نقل',
        'email': 'op@zadgo.co',
        'role': 'fleetOperator',
      }, 'op1');
      expect(u.role, UserRole.fleetOperator);
      expect(u.toMap()['role'], 'fleetOperator');
    });

    test('لكلٍّ تسمية عربية ظاهرة لا فراغاً', () {
      expect(UserRole.support.label, 'موظف دعم');
      expect(UserRole.fleetOperator.label, 'مشغّل الأسطول');
    });

    test('دور غير معروف يسقط لعميل ولا يرمي — حماية الإصدارات القديمة', () {
      final u = AppUser.fromMap(const {
        'name': 'x',
        'email': 'x@x.co',
        // اسمٌ لا يعرفه أي إصدار — لا يُقفل التطبيق بل يسقط لعميل.
        'role': 'galacticOverlord',
      }, 'u2');
      expect(u.role, UserRole.customer);
    });

    test('الدعم يقدّم شكوى بكل الأنواع كالمدير — يسجّلها نيابةً عن المتصلين', () {
      expect(ComplaintTypeScope.typesForRole(UserRole.support),
          ComplaintType.values);
    });
  });
}
