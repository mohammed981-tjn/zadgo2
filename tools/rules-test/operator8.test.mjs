/* دفعة ٨ / المشغّل بأحدث طراز — صلاحيات المشغّل الجديدة على المحاكي.
 *   cp ../../firestore.rules . && npx firebase-tools emulators:exec \
 *     --only firestore --project demo-zadgo "node operator8.test.mjs"
 *
 * تُثبت أن المشغّل:
 *   • يقرأ طلبات كباتنه (المختومة operatorId) ودفاترهم — ولا يقرأ لغيره.
 *   • يحظر/يفعّل كابتنه ويفصله عن أسطوله — ولا يمسّ كابتن مشغّلٍ آخر
 *     ولا الحصّة/الإنذارات، ولا ينقل كابتنه لمشغّلٍ آخر.
 *   • يسوّي رصيد كابتنه فقط بحركة operatorSettlement ذرّية مطابقة المبلغ.
 *   • يُصدر أكواد كباتن لأسطوله حصراً (لا أدواراً أخرى ولا مشغّلاً آخر).
 *   • وختم التبعية عند الإسناد: المطعم يسند بتبعيةٍ مطابقة لمستند السائق،
 *     والكابتن الرافض يُجرِّد التبعية مع التجريد.
 */
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, writeBatch, collection, query, where } from 'firebase/firestore';
import fs from 'fs';

const env = await initializeTestEnvironment({
  projectId: 'demo-zadgo',
  firestore: { rules: fs.readFileSync('firestore.rules', 'utf8'), host: '127.0.0.1', port: 8181 },
});
let pass = 0, fail = 0;
const t = async (name, fn) => {
  try { await fn(); console.log('  ✅ ' + name); pass++; }
  catch (e) { console.log('  ❌ ' + name + ' — ' + (e.message || e).toString().slice(0, 160)); fail++; }
};

await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/op1'), { role: 'fleetOperator', name: 'مشغل ١' });
  await setDoc(doc(db, 'users/op2'), { role: 'fleetOperator', name: 'مشغل ٢' });
  await setDoc(doc(db, 'users/rm1'), { role: 'restaurantManager', restaurantId: 'R1' });
  await setDoc(doc(db, 'fleet_operators/op1'), { balance: 0 });
  await setDoc(doc(db, 'drivers/capA'),
      { name: 'كابتن أ', operatorId: 'op1', operatorDriverShare: 2, balance: -50, isActive: true, isAvailable: true, warningCount: 1 });
  await setDoc(doc(db, 'drivers/capB'),
      { name: 'كابتن ب', operatorId: 'op2', balance: 0, isActive: true });
  await setDoc(doc(db, 'orders/o1'),
      { customerId: 'c1', restaurantId: 'R1', driverId: 'capA', operatorId: 'op1', status: 'onTheWay' });
  await setDoc(doc(db, 'orders/o2'),
      { customerId: 'c1', restaurantId: 'R1', driverId: 'capB', operatorId: 'op2', status: 'onTheWay' });
  await setDoc(doc(db, 'orders/oAssign'),
      { customerId: 'c1', restaurantId: 'R1', driverId: null, status: 'searchingDriver' });
  await setDoc(doc(db, 'orders/oReject'),
      { customerId: 'c1', restaurantId: 'R1', driverId: 'capA', operatorId: 'op1',
        status: 'searchingDriver', driverAcknowledged: false });
  await setDoc(doc(db, 'driver_transactions/txA1'),
      { driverId: 'capA', type: 'deliveryCash', amount: -50 });
  await setDoc(doc(db, 'driver_transactions/txB1'),
      { driverId: 'capB', type: 'deliveryCash', amount: -10 });
  // كود مشغّل مستهلَك باسم newcap — لاختبار إنشاء مستند السائق بالتبعية.
  await setDoc(doc(db, 'registrationCodes/OPCODE1'),
      { role: 'driver', operatorId: 'op1', isUsed: true, usedByUid: 'newcap' });
  await setDoc(doc(db, 'registrationCodes/OPUNUSED'),
      { role: 'driver', operatorId: 'op1', isUsed: false });
  // كود مدير عادي (بلا تبعية) وكود مشغّل حي — لاختبار بوابة «الإدارة توافق».
  await setDoc(doc(db, 'registrationCodes/PLAIN1'),
      { role: 'driver', isUsed: false });
  await setDoc(doc(db, 'registrationCodes/OPGATE'),
      { role: 'driver', operatorId: 'op1', isUsed: false });
});

const op1 = env.authenticatedContext('op1').firestore();
const rm1 = env.authenticatedContext('rm1').firestore();
const capA = env.authenticatedContext('capA').firestore();

console.log('\nالقراءة — طلبات ودفاتر كباتنه فقط:');
await t('المشغّل يفتح طلب كابتنه الجاري', () => assertSucceeds(getDoc(doc(op1, 'orders/o1'))));
await t('المشغّل لا يفتح طلب كابتن مشغّلٍ آخر', () => assertFails(getDoc(doc(op1, 'orders/o2'))));
await t('المشغّل يسرد طلباته بشرط التبعية', () => assertSucceeds(
  getDocs(query(collection(op1, 'orders'), where('operatorId', '==', 'op1')))));
await t('المشغّل يقرأ حركة دفتر كابتنه', () => assertSucceeds(getDoc(doc(op1, 'driver_transactions/txA1'))));
await t('المشغّل لا يقرأ حركة دفتر كابتنِ غيره', () => assertFails(getDoc(doc(op1, 'driver_transactions/txB1'))));

console.log('\nالحظر والفصل:');
await t('المشغّل يحظر كابتنه (isActive=false)', () => assertSucceeds(
  updateDoc(doc(op1, 'drivers/capA'), { isActive: false })));
await t('المشغّل يعيد تفعيل كابتنه', () => assertSucceeds(
  updateDoc(doc(op1, 'drivers/capA'), { isActive: true })));
await t('المشغّل لا يمسّ كابتن مشغّلٍ آخر', () => assertFails(
  updateDoc(doc(op1, 'drivers/capB'), { isActive: false })));
await t('المشغّل لا يعدّل حصّته من كابتنه', () => assertFails(
  updateDoc(doc(op1, 'drivers/capA'), { operatorDriverShare: 9 })));
await t('المشغّل لا يصفّر إنذارات كابتنه', () => assertFails(
  updateDoc(doc(op1, 'drivers/capA'), { warningCount: 0 })));
await t('المشغّل لا ينقل كابتنه لمشغّلٍ آخر', () => assertFails(
  updateDoc(doc(op1, 'drivers/capA'), { operatorId: 'op2' })));

console.log('\nالتسوية المالية الذرّية:');
await t('تسوية مطابقة المبلغ تمرّ (‎-50 → 0 مع حركة +50)', () => assertSucceeds((() => {
  const b = writeBatch(op1);
  b.set(doc(op1, 'driver_transactions/set1'),
      { driverId: 'capA', type: 'operatorSettlement', createdBy: 'op1', amount: 50 });
  b.update(doc(op1, 'drivers/capA'), { balance: 0, lastLedgerTxId: 'set1' });
  return b.commit();
})()));
await t('تغيير رصيدٍ بلا حركة يُرفض', () => assertFails(
  updateDoc(doc(op1, 'drivers/capA'), { balance: 100, lastLedgerTxId: 'txA1' })));
await t('تسوية بمبلغ لا يطابق التغيير تُرفض', () => assertFails((() => {
  const b = writeBatch(op1);
  b.set(doc(op1, 'driver_transactions/set2'),
      { driverId: 'capA', type: 'operatorSettlement', createdBy: 'op1', amount: 30 });
  b.update(doc(op1, 'drivers/capA'), { balance: 50, lastLedgerTxId: 'set2' });
  return b.commit();
})()));
await t('حركة تسوية على كابتنِ غيره تُرفض', () => assertFails(
  setDoc(doc(op1, 'driver_transactions/set3'),
      { driverId: 'capB', type: 'operatorSettlement', createdBy: 'op1', amount: 10 })));
await t('حركة بنوع bonus من مشغّل تُرفض', () => assertFails(
  setDoc(doc(op1, 'driver_transactions/set4'),
      { driverId: 'capA', type: 'bonus', createdBy: 'op1', amount: 10 })));

console.log('\nأكواد «أضف كابتناً»:');
await t('المشغّل يُصدر كود كابتنٍ لأسطوله', () => assertSucceeds(
  setDoc(doc(op1, 'registrationCodes/OP1NEW'),
      { role: 'driver', operatorId: 'op1', isUsed: false })));
await t('كود بدور admin يُرفض', () => assertFails(
  setDoc(doc(op1, 'registrationCodes/OP1BAD'),
      { role: 'admin', operatorId: 'op1', isUsed: false })));
await t('كود بتبعية مشغّلٍ آخر يُرفض', () => assertFails(
  setDoc(doc(op1, 'registrationCodes/OP1BAD2'),
      { role: 'driver', operatorId: 'op2', isUsed: false })));
await t('المشغّل يسرد أكواده', () => assertSucceeds(
  getDocs(query(collection(op1, 'registrationCodes'), where('operatorId', '==', 'op1')))));
await t('المشغّل يحذف كوده غير المستهلَك', () => assertSucceeds(
  deleteDoc(doc(op1, 'registrationCodes/OPUNUSED'))));
await t('المشغّل لا يحذف كوداً مستهلَكاً', () => assertFails(
  deleteDoc(doc(op1, 'registrationCodes/OPCODE1'))));

console.log('\nبوابة «الأسطول يضيف والإدارة توافق» (أمر المالك 2026-08-22):');
const applicant = env.authenticatedContext('applicant1').firestore();
await t('متقدّمٌ لا يستهلك كود مشغّل بالتسجيل الذاتي', () => assertFails(
  updateDoc(doc(applicant, 'registrationCodes/OPGATE'),
      { isUsed: true, usedAt: new Date(), usedByUid: 'applicant1',
        usedByName: 'متقدم' })));
await t('كود المدير العادي يُستهلك بالتسجيل الذاتي كما كان', () => assertSucceeds(
  updateDoc(doc(applicant, 'registrationCodes/PLAIN1'),
      { isUsed: true, usedAt: new Date(), usedByUid: 'applicant1',
        usedByName: 'متقدم' })));
const admin = env.authenticatedContext('boss', { admin: true }).firestore();
await t('المدير يختم كود المشغّل مستهلَكاً عند اعتماد الطلب', () => assertSucceeds(
  updateDoc(doc(admin, 'registrationCodes/OPGATE'),
      { isUsed: true, usedAt: new Date(), usedByUid: 'applicant1',
        usedByName: 'متقدم' })));

console.log('\nإنشاء مستند الكابتن بتبعيةٍ من كود المشغّل:');
const newcap = env.authenticatedContext('newcap').firestore();
await t('كابتن الكود يُنشئ مستنده بتبعية op1', () => assertSucceeds(
  setDoc(doc(newcap, 'drivers/newcap'),
      { name: 'جديد', operatorId: 'op1', registrationCode: 'OPCODE1',
        balance: 0, totalEarnings: 0, warningCount: 0, isActive: true })));
await t('منتحلٌ لا يستخدم كود غيره', () => assertFails(
  setDoc(doc(env.authenticatedContext('imposter').firestore(), 'drivers/imposter'),
      { name: 'منتحل', operatorId: 'op1', registrationCode: 'OPCODE1',
        balance: 0, totalEarnings: 0, warningCount: 0 })));
await t('ادّعاء تبعية بلا كود يُرفض', () => assertFails(
  setDoc(doc(env.authenticatedContext('liar').firestore(), 'drivers/liar'),
      { name: 'مدّعٍ', operatorId: 'op1',
        balance: 0, totalEarnings: 0, warningCount: 0 })));

console.log('\nختم التبعية عند الإسناد:');
await t('المطعم يسند بتبعيةٍ مطابقة لمستند السائق', () => assertSucceeds(
  updateDoc(doc(rm1, 'orders/oAssign'),
      { driverId: 'capA', driverName: 'كابتن أ', operatorId: 'op1',
        status: 'driverAssigned', driverAcknowledged: false })));
await t('المطعم لا يختم تبعيةً مخالفة لمستند السائق', () => assertFails(
  updateDoc(doc(rm1, 'orders/oReject'),
      { driverId: 'capB', driverName: 'ب', operatorId: 'op1' })));
await t('الكابتن الرافض يُجرِّد التبعية مع التجريد', () => assertSucceeds(
  updateDoc(doc(capA, 'orders/oReject'),
      { driverId: null, driverName: null, operatorId: '', driverAcknowledged: true })));

console.log(`\nالنتيجة: ${pass} ✅  ${fail} ❌`);
await env.cleanup();
process.exit(fail === 0 ? 0 : 1);
