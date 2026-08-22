/* دفعة التحسينات (الفحص الشامل 2026-08-22) — حرّاس القواعد الجدد:
 * ت١ (استهلاك الكود ذرّي باسم صاحبه)، ت٢ (تعذّر التسليم بيد الكابتن
 * على توصيلة جارية حصراً)، ت٢٨ (عدّادا البنر +1)، ت٣ (عدّاد الموقع
 * المُحاكى تصاعدي).
 *   cp ../../firestore.rules . && npx firebase-tools emulators:exec \
 *     --only firestore --project demo-zadgo "node improvements.test.mjs"
 */
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, increment } from 'firebase/firestore';
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
  await setDoc(doc(db, 'users/cust1'), { role: 'customer' });
  await setDoc(doc(db, 'users/capA'), { role: 'driver' });
  await setDoc(doc(db, 'drivers/capA'), { name: 'أ', mockLocationCount: 2 });
  await setDoc(doc(db, 'registrationCodes/AAA111'),
      { role: 'driver', isUsed: false, operatorId: '' });
  await setDoc(doc(db, 'registrationCodes/BBB222'),
      { role: 'driver', isUsed: true, operatorId: '' }); // مستخدَم بلا مالك (إرث)
  await setDoc(doc(db, 'banners/ban1'),
      { imageUrl: 'x', isActive: true, impressions: 5, clicks: 1 });
  await setDoc(doc(db, 'orders/oGo'),
      { customerId: 'cust1', restaurantId: 'R1', driverId: 'capA',
        status: 'onTheWay', paymentMethod: 'cash', itemsTotal: 40,
        appShare: 3, driverShare: 9, walletUsed: 0, discountAmount: 0 });
  await setDoc(doc(db, 'orders/oDone'),
      { customerId: 'cust1', restaurantId: 'R1', driverId: 'capA',
        status: 'delivered', paymentMethod: 'cash' });
});

const cust1 = env.authenticatedContext('cust1').firestore();
const capA = env.authenticatedContext('capA').firestore();
const anon = env.authenticatedContext('anonUser').firestore();

console.log('ت١ — استهلاك الكود ذرّي باسم مستهلكه:');
await t('ختم «مستخدَم» بلا اسم المستهلك يُرفض (كان باب الحرق)', () => assertFails(
  updateDoc(doc(anon, 'registrationCodes/AAA111'),
      { isUsed: true, usedAt: new Date() })));
await t('الاستهلاك الكامل (ختم + اسم الكاتب) يمرّ', () => assertSucceeds(
  updateDoc(doc(anon, 'registrationCodes/AAA111'),
      { isUsed: true, usedAt: new Date(),
        usedByUid: 'anonUser', usedByName: 'متقدم' })));
await t('انتحال كودٍ مستخدَمٍ بلا مالك يُرفض (أُغلق فرع الإرث)', () => assertFails(
  updateDoc(doc(anon, 'registrationCodes/BBB222'),
      { usedByUid: 'anonUser', usedByName: 'منتحل' })));

console.log('\nت٢ — «تعذّر التسليم» على توصيلةٍ جارية حصراً:');
await t('الكابتن يرفع العلم على توصيلته الجارية', () => assertSucceeds(
  updateDoc(doc(capA, 'orders/oGo'),
      { deliveryFailed: true, undeliveredReason: 'العميل لا يرد' })));
await t('لا يرفعه على طلبٍ منتهٍ بأثر رجعي', () => assertFails(
  updateDoc(doc(capA, 'orders/oDone'), { deliveryFailed: true })));
await t('لا يمحو العلم بعد رفعه (المحو للمدير)', () => assertFails(
  updateDoc(doc(capA, 'orders/oGo'), { deliveryFailed: false })));

console.log('\nت٢٨ — عدّادا البنر استرشاديان مقيّدان:');
await t('انطباع +1 من عميل يمرّ', () => assertSucceeds(
  updateDoc(doc(cust1, 'banners/ban1'), { impressions: increment(1) })));
await t('نقرة +1 تمرّ', () => assertSucceeds(
  updateDoc(doc(cust1, 'banners/ban1'), { clicks: increment(1) })));
await t('قفزة +50 تُرفض', () => assertFails(
  updateDoc(doc(cust1, 'banners/ban1'), { impressions: increment(50) })));
await t('مسّ حقلٍ آخر مع العدّاد يُرفض', () => assertFails(
  updateDoc(doc(cust1, 'banners/ban1'),
      { impressions: increment(1), isActive: false })));

console.log('\nت٣ — عدّاد الموقع المُحاكى تصاعدي:');
await t('جهاز الكابتن يزيد عدّاده +1', () => assertSucceeds(
  updateDoc(doc(capA, 'drivers/capA'), { mockLocationCount: 3 })));
await t('لا يصفّره صاحبه', () => assertFails(
  updateDoc(doc(capA, 'drivers/capA'), { mockLocationCount: 0 })));

console.log(`\nالنتيجة: ${pass} ✅  ${fail} ❌`);
await env.cleanup();
process.exit(fail === 0 ? 0 : 1);
