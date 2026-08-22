/* دفعة ٠-ب / عنقود A (C1 تصفير الرصيد + H2 تلفيق الدفتر) على المحاكي.
 *   cp ../../firestore.rules . && npx firebase-tools emulators:exec \
 *     --only firestore --project demo-zadgo "node harden0b_a.test.mjs"
 * يثبت: لا يتغيّر رصيد الكابتن إلا مقروناً بحركة دفتر مطابقة (نفس الدفعة)،
 * والزيادة مربوطةٌ بلحظة التسليم الفعلية ومسقوفةٌ بالأجرة — فلا تصفير دَين
 * ولا تضخيم مستحق ولا قبض مزدوج، وكلٌّ من مسارَي الاستلام/التسليم الشرعيين يمرّ.
 */
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, collection, addDoc, writeBatch, increment } from 'firebase/firestore';
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
  for (const id of ['drv1', 'drv_cust', 'drv_del', 'drv_other'])
    await setDoc(doc(db, 'users/' + id), { role: 'driver' });
  await setDoc(doc(db, 'drivers/drv1'), { balance: -30, totalEarnings: 0, warningCount: 0, operatorId: '' });
  await setDoc(doc(db, 'drivers/drv_cust'), { balance: 0, totalEarnings: 0, warningCount: 0, operatorId: '' });
  await setDoc(doc(db, 'drivers/drv_del'), { balance: -30, totalEarnings: 0, warningCount: 0, operatorId: '' });
  await setDoc(doc(db, 'drivers/drv_other'), { balance: 0, totalEarnings: 0, warningCount: 0, operatorId: '' });
  const mk = (id, o) => setDoc(doc(db, 'orders/' + id), {
    customerId: 'cust1', restaurantId: 'R1', driverShare: 10, driverTip: 2,
    // itemsTotal لازمة الآن: عُهدة الطلب تُشتق منها في القاعدة (م١٨)
    // كما يشتقّها النموذج — والطلب الحقيقي يكتبها دائماً عند الإنشاء.
    itemsTotal: 40, appShare: 0,
    custodyDebited: false, paymentMethod: 'card', walletUsed: 0, discountAmount: 0, ...o });
  await mk('od_ready', { driverId: 'drv_cust', status: 'readyForPickup', paymentMethod: 'cash' });
  await mk('od_ontheway', { driverId: 'drv_del', status: 'onTheWay' });
  await mk('od_delivered', { driverId: 'drv1', status: 'delivered' });
  await mk('od_other', { driverId: 'drv_other', status: 'onTheWay' });
});

const drv1 = env.authenticatedContext('drv1').firestore();
const drvCust = env.authenticatedContext('drv_cust').firestore();
const drvDel = env.authenticatedContext('drv_del').firestore();
const admin = env.authenticatedContext('boss', { admin: true }).firestore();

console.log('\nهجمات الرصيد المباشر (C1):');
await t('تضخيم الرصيد مباشرةً (بلا حركة) يُرفض', () => assertFails(
  updateDoc(doc(drv1, 'drivers/drv1'), { balance: 99999 })));
await t('تصفير الدَّين مباشرةً (بلا حركة) يُرفض', () => assertFails(
  updateDoc(doc(drv1, 'drivers/drv1'), { balance: 0 })));

console.log('\nالمسارات الشرعية (استلام/تسليم):');
await t('قيد عُهدة الاستلام (رصيد↓ + حركة orderCustody + انتقال) يمرّ', () => assertSucceeds((async () => {
  const b = writeBatch(drvCust);
  const txRef = doc(collection(drvCust, 'driver_transactions'));
  b.update(doc(drvCust, 'orders/od_ready'), { status: 'onTheWay', custodyDebited: true });
  b.update(doc(drvCust, 'drivers/drv_cust'), { balance: increment(-40), lastLedgerTxId: txRef.id });
  b.set(txRef, { driverId: 'drv_cust', type: 'orderCustody', amount: -40, balanceAfter: -40, orderId: 'od_ready', orderNumber: 1 });
  return b.commit();
})()));
await t('إيداع أجرة التسليم (رصيد↑=12 + حركة deliveryOnline + تحوّل delivered) يمرّ', () => assertSucceeds((async () => {
  const b = writeBatch(drvDel);
  const txRef = doc(collection(drvDel, 'driver_transactions'));
  b.update(doc(drvDel, 'orders/od_ontheway'), { status: 'delivered', isPaid: true, platformCommission: 1.5 });
  b.update(doc(drvDel, 'drivers/drv_del'),
      { totalDeliveries: increment(1), balance: increment(12), lastLedgerTxId: txRef.id, isAvailable: true });
  b.set(txRef, { driverId: 'drv_del', type: 'deliveryOnline', amount: 12, balanceAfter: -18, orderId: 'od_ontheway', orderNumber: 2 });
  return b.commit();
})()));

console.log('\nهجمات التلفيق (H2):');
await t('قبض مزدوج: حركة على طلبٍ مُسلَّم سابقاً (لا تحوّل) يُرفض', () => assertFails((async () => {
  const b = writeBatch(drv1);
  const txRef = doc(collection(drv1, 'driver_transactions'));
  b.update(doc(drv1, 'drivers/drv1'), { balance: increment(12), lastLedgerTxId: txRef.id });
  b.set(txRef, { driverId: 'drv1', type: 'deliveryOnline', amount: 12, balanceAfter: -18, orderId: 'od_delivered', orderNumber: 3 });
  return b.commit();
})()));
await t('زيادة الرصيد بحركة يتجاوز مبلغُها الأجرة تُرفض (السقف)', () => assertFails((async () => {
  const b = writeBatch(drv1);
  const txRef = doc(collection(drv1, 'driver_transactions'));
  // نحاول على طلب في الطريق (يخصّ drv_del) — ليس ملكه أصلاً، فالحركة والرصيد يُرفضان.
  b.update(doc(drv1, 'drivers/drv1'), { balance: increment(99999), lastLedgerTxId: txRef.id });
  b.set(txRef, { driverId: 'drv1', type: 'deliveryOnline', amount: 99999, balanceAfter: 1, orderId: 'od_delivered', orderNumber: 4 });
  return b.commit();
})()));
await t('حركة بلا orderId تُرفض', () => assertFails(
  addDoc(collection(drv1, 'driver_transactions'),
      { driverId: 'drv1', type: 'deliveryOnline', amount: 5, balanceAfter: 5, orderId: '' })));
await t('حركة تشير لطلب كابتنٍ آخر تُرفض', () => assertFails(
  addDoc(collection(drv1, 'driver_transactions'),
      { driverId: 'drv1', type: 'deliveryOnline', amount: 5, balanceAfter: 5, orderId: 'od_other' })));

console.log('\nالمدير يتخطّى القيد:');
await t('المدير يسجّل تسوية رصيد بلا orderId', () => assertSucceeds((async () => {
  const b = writeBatch(admin);
  const txRef = doc(collection(admin, 'driver_transactions'));
  b.update(doc(admin, 'drivers/drv1'), { balance: increment(100) });
  b.set(txRef, { driverId: 'drv1', type: 'adjustment', amount: 100, balanceAfter: 70 });
  return b.commit();
})()));

console.log(`\nالنتيجة: ${pass} ✅  ${fail} ❌`);
await env.cleanup();
process.exit(fail === 0 ? 0 : 1);
