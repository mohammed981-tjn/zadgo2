/* دفعة قوائم السماح (أمر المالك 2026-08-22) — فرع الكابتن hasOnly صريحة:
 * الحقل الذي لم يُسمّ يولد ممنوعاً، والدورة المشروعة تمرّ كما كانت.
 *   cp ../../firestore.rules . && npx firebase-tools emulators:exec \
 *     --only firestore --project demo-zadgo "node allowlist.test.mjs"
 */
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc } from 'firebase/firestore';
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
  await setDoc(doc(db, 'users/capA'), { role: 'driver' });
  await setDoc(doc(db, 'users/rm1'), { role: 'restaurantManager', restaurantId: 'R1' });
  await setDoc(doc(db, 'drivers/capA'), { name: 'أ', operatorId: '' });
  const base = {
    customerId: 'cust1', restaurantId: 'R1', driverId: 'capA',
    paymentMethod: 'cash', isPaid: false, itemsTotal: 40, appShare: 3,
    driverShare: 9, driverTip: 0, walletUsed: 0, discountAmount: 0,
    custodyDebited: false, operatorShare: 0,
  };
  await setDoc(doc(db, 'orders/oWay'), { ...base, status: 'onTheWay', custodyDebited: true });
  await setDoc(doc(db, 'orders/oReady'), { ...base, status: 'readyForPickup' });
  await setDoc(doc(db, 'orders/oPend'), { ...base, driverId: null, status: 'restaurantPending' });
});

const capA = env.authenticatedContext('capA').firestore();
const rm1 = env.authenticatedContext('rm1').firestore();

console.log('فرع الكابتن — قائمة سماح صريحة:');
await t('حقل مستقبلي لم يُسمَّ (bonusPayout) يولد ممنوعاً', () => assertFails(
  updateDoc(doc(capA, 'orders/oWay'), { bonusPayout: 500 })));
await t('حقل موجود خارج القائمة (customerName) ممنوع', () => assertFails(
  updateDoc(doc(capA, 'orders/oWay'), { customerName: 'انتحال' })));
await t('حقل مالي قديم (driverShare) ما زال ممنوعاً', () => assertFails(
  updateDoc(doc(capA, 'orders/oWay'), { driverShare: 99 })));
await t('استلامٌ مشروع: onTheWay + قيد العُهدة يمرّ', () => assertSucceeds(
  updateDoc(doc(capA, 'orders/oReady'),
      { status: 'onTheWay', custodyDebited: true })));
await t('تسليمٌ مشروع: delivered + isPaid يمرّ', () => assertSucceeds(
  updateDoc(doc(capA, 'orders/oWay'), { status: 'delivered', isPaid: true })));
await t('تعذّر التسليم بحقوله الثلاثة يمرّ', () => assertSucceeds(
  updateDoc(doc(capA, 'orders/oReady'),
      { deliveryFailed: true, undeliveredReason: 'العميل لا يرد' })));
await t('ختم الوصول للمطعم يمرّ', () => assertSucceeds(
  updateDoc(doc(capA, 'orders/oReady'), { arrivedAtRestaurantAt: new Date() })));

console.log('\nفرع المطعم — القائمة الصريحة القائمة تصمد:');
await t('حقل مستقبلي على فرع المطعم ممنوع', () => assertFails(
  updateDoc(doc(rm1, 'orders/oReady'), { bonusPayout: 500 })));
await t('قبولٌ مشروع من المطعم يمرّ', () => assertSucceeds(
  updateDoc(doc(rm1, 'orders/oPend'),
      { status: 'restaurantAccepted', prepMinutes: 20 })));

console.log(`\nالنتيجة: ${pass} ✅  ${fail} ❌`);
await env.cleanup();
process.exit(fail === 0 ? 0 : 1);
