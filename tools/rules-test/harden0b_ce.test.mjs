/* دفعة ٠-ب / عنقودا C (C3 دفع ريال) وE (H6/H7/H8 الكوبونات) على المحاكي.
 *   cp ../../firestore.rules . && npx firebase-tools emulators:exec \
 *     --only firestore --project demo-zadgo "node harden0b_ce.test.mjs"
 */
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, collection, writeBatch, increment } from 'firebase/firestore';
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

// طلب صالح كامل (يمرّ كل شروط الإنشاء الأخرى) لعزل الفحص المطلوب.
const order = (over = {}) => ({
  customerId: 'cust1', restaurantId: 'R1', paymentMethod: 'cash', paymentId: '',
  isPaid: false, discountAmount: 0, walletUsed: 0, driverTip: 0,
  itemsTotal: 40, status: 'restaurantPending', ...over,
});

await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/cust1'), { role: 'customer', walletBalance: 1000 });
  // دفعات موثَّقة: كلٌّ 100 ريال (10000 هللة).
  await setDoc(doc(db, 'verified_payments/pay1'), { uid: 'cust1', amountHalalas: 10000 });
  await setDoc(doc(db, 'verified_payments/pay2'), { uid: 'cust1', amountHalalas: 10000 });
  await setDoc(doc(db, 'verified_payments/pay_used'), { uid: 'cust1', amountHalalas: 10000 });
  await setDoc(doc(db, 'payment_consumptions/pay_used'), { uid: 'cust1', orderId: 'old_order' });
  // كوبونات.
  await setDoc(doc(db, 'coupons/SAVE10'),
      { isActive: true, type: 'fixed', value: 10, perUserLimit: 0, usageLimit: 100, usedCount: 5, restaurantId: '', minOrderTotal: 0 });
  await setDoc(doc(db, 'coupons/MIN40'),
      { isActive: true, type: 'fixed', value: 10, perUserLimit: 0, usageLimit: 0, usedCount: 0, restaurantId: '', minOrderTotal: 40 });
  await setDoc(doc(db, 'coupons/BIG50'),
      { isActive: true, type: 'fixed', value: 50, perUserLimit: 0, usageLimit: 0, usedCount: 0, restaurantId: '', minOrderTotal: 0 });
  // إرجاع الكوبون (H7): كوبون + سجلّ استخدام + طلب ملغى لكلّ اختبار.
  for (const s of ['A', 'B', 'C']) {
    await setDoc(doc(db, 'coupons/REL_' + s), { isActive: true, type: 'fixed', value: 10, usedCount: 3, usageLimit: 0, perUserLimit: 0, restaurantId: '', minOrderTotal: 0 });
    await setDoc(doc(db, 'coupon_usages/REL_' + s + '_cust1'), { code: 'REL_' + s, userId: 'cust1', count: 1, lastOrderId: 'relord_' + s });
  }
  await setDoc(doc(db, 'orders/relord_A'), { customerId: 'cust1', couponCode: 'REL_A', status: 'cancelled', couponReleased: false });
  await setDoc(doc(db, 'orders/relord_B'), { customerId: 'cust1', couponCode: 'REL_B', status: 'cancelled', couponReleased: true });
  await setDoc(doc(db, 'orders/relord_C'), { customerId: 'cust1', couponCode: 'REL_C', status: 'cancelled', couponReleased: true });
});

const cust1 = env.authenticatedContext('cust1').firestore();

// دفعة إنشاء طلب بطاقة مع ختم الاستهلاك.
const cardOrderBatch = (oid, pid, halalas, withMarker = true) => {
  const b = writeBatch(cust1);
  b.set(doc(cust1, 'orders/' + oid), order({ paymentMethod: 'card', paymentId: pid, isPaid: true, cardAmountHalalas: halalas }));
  if (withMarker) b.set(doc(cust1, 'payment_consumptions/' + pid), { uid: 'cust1', orderId: oid });
  return b.commit();
};
// دفعة إنشاء طلب خصم مع علامتَي الكوبون.
const couponOrderBatch = (oid, code, discount, itemsTotal, { marker = true, incCoupon = true } = {}) => {
  const b = writeBatch(cust1);
  b.set(doc(cust1, 'orders/' + oid), order({ couponCode: code, discountAmount: discount, itemsTotal }));
  if (marker) b.set(doc(cust1, 'coupon_usages/' + code + '_cust1'),
      { code, userId: 'cust1', count: increment(1), lastOrderId: oid }, { merge: true });
  if (incCoupon) b.update(doc(cust1, 'coupons/' + code), { usedCount: increment(1) });
  return b.commit();
};

console.log('\nC3 — دفع ريال / إعادة استخدام الدفعة:');
await t('طلب بطاقة بمبلغ مطابق + ختم استهلاك يمرّ', () => assertSucceeds(
  cardOrderBatch('c_ok', 'pay1', 10000)));
await t('طلب بطاقة قيمته تفوق المدفوع (500 خلف 100) يُرفض', () => assertFails(
  cardOrderBatch('c_over', 'pay2', 50000)));
await t('طلب بطاقة بلا ختم استهلاك يُرفض', () => assertFails(
  cardOrderBatch('c_nomark', 'pay2', 10000, false)));
await t('إعادة استخدام دفعةٍ مستهلَكة (ختمها موجود) يُرفض', () => assertFails(
  cardOrderBatch('c_reuse', 'pay_used', 10000)));
await t('طلب نقدي (بلا paymentId) يمرّ بلا ختم', () => assertSucceeds(
  setDoc(doc(cust1, 'orders/c_cash'), order({ paymentMethod: 'cash', paymentId: '' }))));

console.log('\nH6 — تقييد الكوبون ذرّياً:');
await t('طلب خصم مع علامتَي الاستخدام يمرّ', () => assertSucceeds(
  couponOrderBatch('e_ok', 'SAVE10', 10, 40)));
await t('طلب خصم بلا علامة استخدام يُرفض', () => assertFails(
  couponOrderBatch('e_nomark', 'SAVE10', 10, 40, { marker: false })));
await t('طلب خصم بلا زيادة العدّاد العام يُرفض', () => assertFails(
  couponOrderBatch('e_noinc', 'SAVE10', 10, 40, { incCoupon: false })));

console.log('\nH8 — الحد الأدنى ومنع الخصم السالب:');
await t('كوبون حدّه ٤٠ على طلب ٢٥ يُرفض', () => assertFails(
  couponOrderBatch('e_min', 'MIN40', 10, 25)));
await t('خصم ٥٠ على وجبات ٣٠ (payable سالب) يُرفض', () => assertFails(
  couponOrderBatch('e_neg', 'BIG50', 50, 30)));

console.log('\nH7 — إرجاع الكوبون لمرّة واحدة:');
await t('إرجاع كوبون طلبٍ ملغى (لم يُرجَع بعد) يمرّ', () => assertSucceeds((async () => {
  const b = writeBatch(cust1);
  b.update(doc(cust1, 'coupons/REL_A'), { usedCount: increment(-1) });
  b.update(doc(cust1, 'coupon_usages/REL_A_cust1'), { count: increment(-1) });
  b.update(doc(cust1, 'orders/relord_A'), { couponReleased: true });
  return b.commit();
})()));
await t('إعادة الإنقاص على طلبٍ سبق إرجاعه يُرفض', () => assertFails((async () => {
  const b = writeBatch(cust1);
  b.update(doc(cust1, 'coupons/REL_C'), { usedCount: increment(-1) });
  b.update(doc(cust1, 'coupon_usages/REL_C_cust1'), { count: increment(-1) });
  b.update(doc(cust1, 'orders/relord_C'), { couponReleased: true });
  return b.commit();
})()));
await t('نكس الختم couponReleased من true إلى false يُرفض', () => assertFails(
  updateDoc(doc(cust1, 'orders/relord_B'), { couponReleased: false })));

console.log(`\nالنتيجة: ${pass} ✅  ${fail} ❌`);
await env.cleanup();
process.exit(fail === 0 ? 0 : 1);
