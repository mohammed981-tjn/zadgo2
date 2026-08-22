/* دفعة «المهم» (مذكّرة الفحص 2026-08-22) — حرّاس القواعد على المحاكي.
 *   cp ../../firestore.rules . && npx firebase-tools emulators:exec \
 *     --only firestore --project demo-zadgo "node harden3.test.mjs"
 */
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, writeBatch, increment } from 'firebase/firestore';
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
  await setDoc(doc(db, 'users/cust1'), { role: 'customer', walletBalance: 1000, createdAt: new Date() });
  await setDoc(doc(db, 'users/capA'), { role: 'driver' });
  await setDoc(doc(db, 'users/capB'), { role: 'driver' });
  await setDoc(doc(db, 'users/rm1'), { role: 'restaurantManager', restaurantId: 'R1' });
  await setDoc(doc(db, 'users/supX'), { role: 'support', isActive: false });
  await setDoc(doc(db, 'drivers/capA'),
      { name: 'أ', balance: 0, offersTotal: 10, offersAccepted: 5,
        activeOrders: 1, isAvailable: true, createdAt: new Date() });
  await setDoc(doc(db, 'drivers/capB'), { name: 'ب', balance: 0, isAvailable: true });
  await setDoc(doc(db, 'restaurants/R1'), { name: 'مطعم', isOpen: true });
  await setDoc(doc(db, 'orders/oDone'),
      { customerId: 'cust1', restaurantId: 'R1', driverId: 'capA',
        status: 'delivered', paymentMethod: 'cash', isPaid: true,
        driverShare: 9, driverTip: 2, custodyAmount: 50 });
  await setDoc(doc(db, 'orders/oWay'),
      { customerId: 'cust1', restaurantId: 'R1', driverId: 'capA',
        status: 'onTheWay', paymentMethod: 'card', paymentId: 'p1',
        isPaid: true, driverShare: 9, driverTip: 2, operatorShare: 0 });
  await setDoc(doc(db, 'coupons/BURN'),
      { isActive: true, type: 'fixed', value: 10, usageLimit: 1000,
        usedCount: 5, perUserLimit: 0, restaurantId: '', minOrderTotal: 0 });
  await setDoc(doc(db, 'coupons/REL'),
      { isActive: true, type: 'fixed', value: 10, usageLimit: 0,
        usedCount: 3, perUserLimit: 0, restaurantId: '', minOrderTotal: 0 });
  // إرجاع بلا خصم فعلي (م٣): طلب ملغى بالكود لكن discountAmount صفر.
  await setDoc(doc(db, 'coupon_usages/REL_cust1'),
      { code: 'REL', userId: 'cust1', count: 1, lastOrderId: 'relZero' });
  await setDoc(doc(db, 'orders/relZero'),
      { customerId: 'cust1', couponCode: 'REL', status: 'cancelled',
        couponReleased: false, discountAmount: 0 });
});

const cust1 = env.authenticatedContext('cust1').firestore();
const capA = env.authenticatedContext('capA').firestore();
const capB = env.authenticatedContext('capB').firestore();
const rm1 = env.authenticatedContext('rm1').firestore();
const supX = env.authenticatedContext('supX').firestore();

console.log('م٢ — فرع المطعم يفحص الحالة المصدر:');
await t('المطعم لا يرجع بالمُسلَّم إلى «جاهز للاستلام»', () => assertFails(
  updateDoc(doc(rm1, 'orders/oDone'), { status: 'readyForPickup' })));

console.log('\nم٤ — عدّاد الكوبون لا يُحرق بلا شراء:');
await t('زيادة العدّاد وحدها (بلا طلبٍ وعلامة) تُرفض', () => assertFails(
  updateDoc(doc(cust1, 'coupons/BURN'), { usedCount: increment(1) })));
await t('زيادة العدّاد مع طلبٍ حقيقي بخصمٍ في نفس الدفعة تمرّ', () => assertSucceeds((() => {
  const b = writeBatch(cust1);
  b.set(doc(cust1, 'orders/buyOk'),
      { customerId: 'cust1', restaurantId: 'R1', paymentMethod: 'cash',
        paymentId: '', isPaid: false, discountAmount: 10, walletUsed: 0,
        driverTip: 0, itemsTotal: 40, status: 'restaurantPending',
        couponCode: 'BURN' });
  b.set(doc(cust1, 'coupon_usages/BURN_cust1'),
      { code: 'BURN', userId: 'cust1', count: increment(1), lastOrderId: 'buyOk' },
      { merge: true });
  b.update(doc(cust1, 'coupons/BURN'), { usedCount: increment(1) });
  return b.commit();
})()));

console.log('\nم٣ — لا إرجاع كوبون لطلبٍ خصمُه صفر:');
await t('إنقاص العدّاد بواقعة «خصم صفر» يُرفض', () => assertFails((() => {
  const b = writeBatch(cust1);
  b.update(doc(cust1, 'orders/relZero'), { couponReleased: true });
  b.update(doc(cust1, 'coupons/REL'), { usedCount: increment(-1) });
  return b.commit();
})()));

console.log('\nم١٣ + م١٩ — حصّة المشغّل والتقييم بيد الكابتن:');
await t('الكابتن لا يكتب operatorShare بلا انتقال تسليم', () => assertFails(
  updateDoc(doc(capA, 'orders/oWay'), { operatorShare: 5 })));
await t('الكابتن لا يختم طلبه «مُقيَّماً»', () => assertFails(
  updateDoc(doc(capA, 'orders/oWay'), { isRated: true })));

console.log('\nم١٨ — مبالغ حركات الكابتن مسقوفة بطلبها:');
await t('حركة deliveryOnline بمبلغ منتفخ (500) تُرفض', () => assertFails((() => {
  const b = writeBatch(capA);
  b.update(doc(capA, 'orders/oWay'), { status: 'delivered', isPaid: true });
  b.set(doc(capA, 'driver_transactions/mint1'),
      { driverId: 'capA', type: 'deliveryOnline', amount: 500,
        orderId: 'oWay', balanceAfter: 500 });
  b.update(doc(capA, 'drivers/capA'), { balance: 500, lastLedgerTxId: 'mint1' });
  return b.commit();
})()));
await t('حركة deliveryOnline في حدود أجرته وإكراميته تمرّ', () => assertSucceeds((() => {
  const b = writeBatch(capA);
  b.update(doc(capA, 'orders/oWay'), { status: 'delivered', isPaid: true });
  b.set(doc(capA, 'driver_transactions/ok1'),
      { driverId: 'capA', type: 'deliveryOnline', amount: 11,
        orderId: 'oWay', balanceAfter: 11 });
  b.update(doc(capA, 'drivers/capA'), { balance: 11, lastLedgerTxId: 'ok1' });
  return b.commit();
})()));

console.log('\nم٢٠ + م٢١ + م٢٢ — مستند الكابتن:');
await t('قفزُ عدّاد العروض +5 يُرفض', () => assertFails(
  updateDoc(doc(capA, 'drivers/capA'), { offersTotal: 15 })));
await t('زيادة عدّاد العروض +1 تمرّ', () => assertSucceeds(
  updateDoc(doc(capA, 'drivers/capA'), { offersTotal: 11 })));
await t('كابتن لا يقلب توفّر زميله', () => assertFails(
  updateDoc(doc(capA, 'drivers/capB'), { isAvailable: false })));
await t('جهاز المطعم يقلب التوفّر (الإسناد التلقائي)', () => assertSucceeds(
  updateDoc(doc(rm1, 'drivers/capB'), { isAvailable: false })));
await t('الكابتن لا يمحو تاريخ انضمامه', () => assertFails(
  updateDoc(doc(capA, 'drivers/capA'), { createdAt: null })));

console.log('\nم٢٦ + م١١ — العميل والدور الموقوف:');
await t('العميل لا يحرّر تاريخ إنشاء حسابه', () => assertFails(
  updateDoc(doc(cust1, 'users/cust1'), { createdAt: new Date(2030, 1, 1) })));
await t('موظف دعم موقوف (isActive=false) لا يقرأ الطلبات', () => assertFails(
  getDoc(doc(supX, 'orders/oDone'))));

console.log(`\nالنتيجة: ${pass} ✅  ${fail} ❌`);
await env.cleanup();
process.exit(fail === 0 ? 0 : 1);
