/* دفعة ٠-أ (تحصين الفحص 2026-08-21) — اختبار القواعد الجديدة على المحاكي.
 * التشغيل (بعد cp ../../firestore.rules .):
 *   npx firebase-tools emulators:exec --only firestore --project demo-zadgo \
 *       "node harden0a.test.mjs"
 *
 * يغطّي: مصفوفة حالة الكابتن (H3)، إعادة لفّ العميل (H4)، تجميد walletUsed/
 * discountAmount (C2/H5)، قيد custodyDebited بالاستلام (C2)، قيد operatorId/
 * operatorShare (H1)، ربط ردّ المحفظة بالخصم الفعلي (H5)، وقصر الكوبون على
 * مطعمه + سقفه العام (H8/H6). لكل تحصين: هجوم محجوب + كتابة شرعية تمرّ.
 */
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, getDoc, writeBatch, increment } from 'firebase/firestore';
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

// طلب صالح كامل يمرّ كل شروط الإنشاء (غير نقدي، غير مدفوع، بلا خصم/محفظة).
const baseOrder = (uid, over = {}) => ({
  customerId: uid, restaurantId: 'R1', paymentMethod: 'cash', paymentId: '',
  isPaid: false, discountAmount: 0, walletUsed: 0, driverTip: 0,
  itemsTotal: 40, status: 'restaurantPending', ...over,
});
// دفعة إنشاء طلب خصم مع علامتَي الكوبون الذرّيتين (كما يفعل التطبيق في ٠-ب).
const couponOrder = (db, oid, code, over = {}) => {
  const b = writeBatch(db);
  b.set(doc(db, 'orders/' + oid), baseOrder('cust1', { couponCode: code, discountAmount: 10, ...over }));
  b.set(doc(db, 'coupon_usages/' + code + '_cust1'),
      { code, userId: 'cust1', count: increment(1), lastOrderId: oid }, { merge: true });
  b.update(doc(db, 'coupons/' + code), { usedCount: increment(1) });
  return b.commit();
};

await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/cust1'), { role: 'customer', walletBalance: 1000 });
  await setDoc(doc(db, 'users/cust2'), { role: 'customer', walletBalance: 1000 });
  await setDoc(doc(db, 'users/drv1'), { role: 'driver' });
  await setDoc(doc(db, 'users/opdrv'), { role: 'driver' });
  // كابتن مستقلّ (بلا مشغّل) وكابتن تابع لمشغّل op1 بحصّة 4.
  await setDoc(doc(db, 'drivers/drv1'), { balance: 0, totalEarnings: 0, warningCount: 0, operatorId: '' });
  await setDoc(doc(db, 'drivers/opdrv'),
      { balance: 0, totalEarnings: 0, warningCount: 0, operatorId: 'op1', operatorDriverShare: 4 });

  // طلبات لاختبار التحديثات.
  const mkOrder = (id, over) => setDoc(doc(db, 'orders/' + id), {
    customerId: 'cust1', restaurantId: 'R1', driverId: null, status: 'restaurantPending',
    driverShare: 10, driverTip: 0, custodyDebited: false, paymentMethod: 'cash',
    walletUsed: 0, discountAmount: 0, ...over,
  });
  // مستند مخصّص لكل اختبار يُعدّل، فلا يلوّث اختبارٌ ناجح (يلتزم فعلاً) غيرَه.
  await mkOrder('o_pickup', { driverId: 'drv1', status: 'readyForPickup' });
  await mkOrder('o_deliver', { driverId: 'drv1', status: 'onTheWay' });
  await mkOrder('o_fake', { driverId: 'drv1', status: 'readyForPickup' });
  await mkOrder('o_rewind', { driverId: 'drv1', status: 'onTheWay' });
  await mkOrder('o_nonstatus', { driverId: 'drv1', status: 'onTheWay' });
  await mkOrder('o_wallettamper', { driverId: 'drv1', status: 'readyForPickup', walletUsed: 0 });
  await mkOrder('o_custody_ok', { driverId: 'drv1', status: 'readyForPickup' });
  await mkOrder('o_custody_bad', { driverId: 'drv1', status: 'onTheWay', custodyDebited: false });
  await mkOrder('o_deliver_solo', { driverId: 'drv1', status: 'onTheWay' });
  await mkOrder('o_op_share0', { driverId: 'opdrv', status: 'readyForPickup' });
  await mkOrder('o_op_op2', { driverId: 'opdrv', status: 'readyForPickup' });
  await mkOrder('o_op_deliver', { driverId: 'opdrv', status: 'onTheWay' });
  await mkOrder('o_solo_claimop', { driverId: 'drv1', status: 'readyForPickup' });
  // طلبات العميل.
  await mkOrder('c_created', { status: 'created', walletUsed: 0, paymentMethod: 'card' });
  await mkOrder('c_created_wallet', { status: 'created', walletUsed: 50, paymentMethod: 'wallet' });
  await mkOrder('c_delivered', { status: 'delivered', walletUsed: 50, paymentMethod: 'wallet' });

  // كوبونات.
  await setDoc(doc(db, 'coupons/GLOBAL10'),
      { isActive: true, type: 'fixed', value: 10, perUserLimit: 0, usageLimit: 0, usedCount: 0, restaurantId: '', minOrderTotal: 0 });
  await setDoc(doc(db, 'coupons/R1ONLY'),
      { isActive: true, type: 'fixed', value: 10, perUserLimit: 0, usageLimit: 0, usedCount: 0, restaurantId: 'R1', minOrderTotal: 0 });
  await setDoc(doc(db, 'coupons/MAXED'),
      { isActive: true, type: 'fixed', value: 10, perUserLimit: 0, usageLimit: 5, usedCount: 5, restaurantId: '', minOrderTotal: 0 });
});

const cust1 = env.authenticatedContext('cust1').firestore();
const drv1 = env.authenticatedContext('drv1').firestore();
const opdrv = env.authenticatedContext('opdrv').firestore();
const admin = env.authenticatedContext('boss', { admin: true }).firestore();

// ---------- D: مصفوفة حالة الكابتن (H3) ----------
console.log('\nمصفوفة حالة الكابتن (H3):');
await t('الكابتن يؤكّد الاستلام (readyForPickup→onTheWay)', () => assertSucceeds(
  updateDoc(doc(drv1, 'orders/o_pickup'), { status: 'onTheWay' })));
await t('الكابتن يؤكّد التسليم (onTheWay→delivered)', () => assertSucceeds(
  updateDoc(doc(drv1, 'orders/o_deliver'), { status: 'delivered', isPaid: true, platformCommission: 1.5 })));
await t('الكابتن لا يختم delivered من readyForPickup (توصيل وهمي)', () => assertFails(
  updateDoc(doc(drv1, 'orders/o_fake'), { status: 'delivered', isPaid: true })));
await t('الكابتن لا يُرجع onTheWay إلى created', () => assertFails(
  updateDoc(doc(drv1, 'orders/o_rewind'), { status: 'created' })));
await t('الكابتن يكتب حقلاً غير الحالة (تعذّر التسليم) بحرية', () => assertSucceeds(
  updateDoc(doc(drv1, 'orders/o_nonstatus'), { deliveryFailed: true, undeliveredReason: 'غياب' })));

// ---------- D: إعادة لفّ العميل (H4) ----------
console.log('\nإعادة لفّ حالة العميل (H4):');
await t('العميل يُلغي ذاتياً (created→cancelled, بلا محفظة)', () => assertSucceeds(
  updateDoc(doc(cust1, 'orders/c_created'), { status: 'cancelled' })));
await t('العميل يُلغي مع ردّ محفظة (walletUsed>0)', () => assertSucceeds(
  updateDoc(doc(cust1, 'orders/c_created_wallet'),
      { status: 'cancelled', walletRefundPending: true, updatedAt: new Date(), statusChangedAt: new Date() })));
await t('العميل لا يُرجع مُسلَّماً إلى created (مزرعة ردّ)', () => assertFails(
  updateDoc(doc(cust1, 'orders/c_delivered'), { status: 'created' })));
await t('العميل لا يختم طلبه delivered', () => assertFails(
  updateDoc(doc(cust1, 'orders/c_created'), { status: 'delivered' })));
await t('العميل لا يُلغي مُسلَّماً (خارج الحالات المسموحة)', () => assertFails(
  updateDoc(doc(cust1, 'orders/c_delivered'),
      { status: 'cancelled', walletRefundPending: true, updatedAt: new Date(), statusChangedAt: new Date() })));

// ---------- B: تجميد walletUsed/discountAmount (C2/H5) ----------
console.log('\nتجميد walletUsed/discountAmount (C2/H5):');
await t('العميل لا يعدّل walletUsed بعد الإنشاء', () => assertFails(
  updateDoc(doc(cust1, 'orders/c_delivered'), { walletUsed: 999 })));
await t('العميل لا يعدّل discountAmount بعد الإنشاء', () => assertFails(
  updateDoc(doc(cust1, 'orders/c_created'), { discountAmount: 999 })));
await t('الكابتن لا يعدّل walletUsed', () => assertFails(
  updateDoc(doc(drv1, 'orders/o_wallettamper'), { walletUsed: 999 })));

// ---------- B: قيد custodyDebited بالاستلام (C2) ----------
console.log('\nقيد custodyDebited بالاستلام (C2):');
await t('custodyDebited=true مقروناً بالاستلام يمرّ', () => assertSucceeds(
  updateDoc(doc(drv1, 'orders/o_custody_ok'), { status: 'onTheWay', custodyDebited: true })));
await t('custodyDebited=true بلا انتقال الاستلام يُرفض', () => assertFails(
  updateDoc(doc(drv1, 'orders/o_custody_bad'), { custodyDebited: true })));

// ---------- B: قيد operatorId/operatorShare (H1) ----------
console.log('\nقيد مال المشغّل operatorId/operatorShare (H1):');
await t('الكابتن التابع يكتب حصّة المشغّل الصحيحة (6=10-4) عند التسليم', () => assertSucceeds(
  updateDoc(doc(opdrv, 'orders/o_op_deliver'),
      { status: 'delivered', isPaid: true, platformCommission: 1.5, operatorId: 'op1', operatorShare: 6 })));
await t('الكابتن لا يصفّر حصّة مشغّله (operatorShare=0)', () => assertFails(
  updateDoc(doc(opdrv, 'orders/o_op_share0'),
      { status: 'onTheWay', operatorShare: 0 })));
await t('الكابتن لا ينسب طلبه لمشغّل آخر (operatorId=op2)', () => assertFails(
  updateDoc(doc(opdrv, 'orders/o_op_op2'),
      { status: 'onTheWay', operatorId: 'op2' })));
await t('كابتن مستقلّ لا يدّعي تبعيةً لمشغّل', () => assertFails(
  updateDoc(doc(drv1, 'orders/o_solo_claimop'),
      { status: 'onTheWay', operatorId: 'op1', operatorShare: 5 })));
await t('كابتن مستقلّ يسلّم بلا حقول مشغّل (المسار الشائع)', () => assertSucceeds(
  updateDoc(doc(drv1, 'orders/o_deliver_solo'), { status: 'delivered', isPaid: true, platformCommission: 1.5 })));

// ---------- B: ربط ردّ المحفظة بالخصم الفعلي (H5) ----------
console.log('\nربط walletUsed بخصمٍ فعلي عند الإنشاء (H5):');
await t('طلب walletUsed=500 بلا خصم فعلي يُرفض', () => assertFails(
  setDoc(doc(cust1, 'orders/atk_wallet'),
      baseOrder('cust1', { paymentMethod: 'wallet', walletUsed: 500, isPaid: true }))));
await t('طلب walletUsed=50 مع خصم رصيد ذرّي يمرّ', () => assertSucceeds((async () => {
  const b = writeBatch(cust1);
  b.set(doc(cust1, 'orders/legit_wallet'),
      baseOrder('cust1', { paymentMethod: 'wallet', walletUsed: 50, isPaid: true }));
  b.update(doc(cust1, 'users/cust1'), { walletBalance: 950 });
  return b.commit();
})()));
await t('طلب بلا محفظة (walletUsed=0) يمرّ عادياً', () => assertSucceeds(
  setDoc(doc(cust1, 'orders/legit_nowallet'), baseOrder('cust1'))));

// ---------- E: قصر الكوبون على مطعمه + سقفه العام (H8/H6) ----------
console.log('\nقصر الكوبون على مطعمه + سقفه العام (H8/H6):');
await t('كوبون عام صالح يمرّ', () => assertSucceeds(
  couponOrder(cust1, 'cpn_global', 'GLOBAL10', { restaurantId: 'R1' })));
await t('كوبون مطعم R1 على طلب R1 يمرّ', () => assertSucceeds(
  couponOrder(cust1, 'cpn_r1', 'R1ONLY', { restaurantId: 'R1' })));
await t('كوبون مطعم R1 على طلب R2 يُرفض', () => assertFails(
  couponOrder(cust1, 'cpn_wrong', 'R1ONLY', { restaurantId: 'R2' })));
await t('كوبون مستنفَد عالمياً (usedCount==usageLimit) يُرفض', () => assertFails(
  couponOrder(cust1, 'cpn_maxed', 'MAXED', { restaurantId: 'R1' })));

console.log(`\nالنتيجة: ${pass} ✅  ${fail} ❌`);
await env.cleanup();
process.exit(fail === 0 ? 0 : 1);
