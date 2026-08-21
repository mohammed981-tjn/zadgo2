/* فحص قواعد مشغّل الأسطول (دفعة «ابدأ المشغل») على محاكي Firestore.
 * التشغيل كما في README-ar.md:
 *   cp ../../firestore.rules .
 *   npx firebase-tools emulators:exec --only firestore --project demo-zadgo \
 *       "node operator.test.mjs"
 *
 * ما يُثبِته: المشغّل يسرد كباتنه وحدهم، يقرأ ملفه لا ملف غيره، ولا يعدّل
 * نسبته ولا دفتره ولا كباتنه؛ والكابتن لا يدّعي تبعيةً لمشغّل بنفسه؛ والمدير
 * وحده يسند التبعيّة ويضبط النسب والدفتر.
 */
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, getDoc, getDocs, collection, query, where } from 'firebase/firestore';
import fs from 'fs';

const env = await initializeTestEnvironment({
  projectId: 'demo-zadgo',
  firestore: { rules: fs.readFileSync('firestore.rules', 'utf8'), host: '127.0.0.1', port: 8181 },
});

let pass = 0, fail = 0;
const t = async (name, fn) => {
  try { await fn(); console.log('  ✅ ' + name); pass++; }
  catch (e) { console.log('  ❌ ' + name + ' — ' + (e.message || e).slice(0, 140)); fail++; }
};

await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/op1'), { role: 'fleetOperator' });
  await setDoc(doc(db, 'users/op2'), { role: 'fleetOperator' });
  await setDoc(doc(db, 'users/drv1'), { role: 'driver' });
  await setDoc(doc(db, 'drivers/drv1'),
      { operatorId: 'op1', operatorDriverShare: 0, balance: 0, totalEarnings: 0, warningCount: 0 });
  await setDoc(doc(db, 'drivers/drv2'),
      { operatorId: 'op2', operatorDriverShare: 0, balance: 0, totalEarnings: 0, warningCount: 0 });
  await setDoc(doc(db, 'drivers/drvFree'), { balance: 0, totalEarnings: 0, warningCount: 0 });
  await setDoc(doc(db, 'fleet_operators/op1'),
      { name: 'مشغّل ١', driverSharePerDelivery: 0, monthlyFee: 0, balance: 0 });
  await setDoc(doc(db, 'fleet_operators/op2'),
      { name: 'مشغّل ٢', driverSharePerDelivery: 0, monthlyFee: 0, balance: 0 });
});

const op1 = env.authenticatedContext('op1').firestore();
const drv1 = env.authenticatedContext('drv1').firestore();
const admin = env.authenticatedContext('boss', { admin: true }).firestore();

console.log('\nسرد الكباتن:');
await t('المشغّل يسرد كباتنه (operatorId == uid)', () => assertSucceeds(
  getDocs(query(collection(op1, 'drivers'), where('operatorId', '==', 'op1')))));
await t('المشغّل لا يسرد كل الكباتن (استعلام غير مقيَّد)', () => assertFails(
  getDocs(collection(op1, 'drivers'))));
await t('المشغّل لا يسرد كباتن مشغّلٍ آخر', () => assertFails(
  getDocs(query(collection(op1, 'drivers'), where('operatorId', '==', 'op2')))));

console.log('\nملف المشغّل ودفتره:');
await t('المشغّل يقرأ ملفه', () => assertSucceeds(getDoc(doc(op1, 'fleet_operators/op1'))));
await t('المشغّل لا يقرأ ملف مشغّلٍ آخر', () => assertFails(getDoc(doc(op1, 'fleet_operators/op2'))));
await t('المشغّل لا يعدّل نسبته', () => assertFails(
  updateDoc(doc(op1, 'fleet_operators/op1'), { driverSharePerDelivery: 9 })));
await t('المشغّل لا يضخّم دفتره', () => assertFails(
  updateDoc(doc(op1, 'fleet_operators/op1'), { balance: 99999 })));

console.log('\nالتبعيّة:');
await t('الكابتن لا يدّعي تبعيةً لمشغّل', () => assertFails(
  updateDoc(doc(drv1, 'drivers/drv1'), { operatorId: 'op2' })));
await t('الكابتن لا يرفع حصّته من المشغّل', () => assertFails(
  updateDoc(doc(drv1, 'drivers/drv1'), { operatorDriverShare: 9 })));

console.log('\nالمدير:');
await t('المدير يسند كابتناً لمشغّل', () => assertSucceeds(
  updateDoc(doc(admin, 'drivers/drvFree'), { operatorId: 'op1', operatorDriverShare: 7.5 })));
await t('المدير يضبط نسبة المشغّل', () => assertSucceeds(
  updateDoc(doc(admin, 'fleet_operators/op1'), { driverSharePerDelivery: 7.5 })));
await t('المدير يسجّل دفعةً في دفتر المشغّل', () => assertSucceeds(
  updateDoc(doc(admin, 'fleet_operators/op1'), { balance: -50 })));

console.log(`\nالنتيجة: ${pass} ✅  ${fail} ❌`);
await env.cleanup();
process.exit(fail === 0 ? 0 : 1);
