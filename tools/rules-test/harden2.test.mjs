/* تحصين الفحص الشامل ٢ (مذكّرة مساعد الويب 2026-08-22) — الحرجة على المحاكي.
 *   cp ../../firestore.rules . && npx firebase-tools emulators:exec \
 *     --only firestore --project demo-zadgo "node harden2.test.mjs"
 *
 * يثبت سدّ: ح١ (تجميد وسيلة الدفع وسندُ غير النقدي)، ح٢ (فرع بلا سائق
 * محصور ولا خلع اسمٍ عن طلبٍ منتهٍ)، ح٣ (العمولة المجانية مجمَّدة)،
 * ح٤ (وثيقة الإثبات مربوطة بالطلب وكتابتها لمرة واحدة)، ح٥ (سقف قيمة
 * الوجبات)، ح٦ (سقف أول طلب نقدي حيّ)، ح٧ (ختم ردّ البطاقة)،
 * م١ (رفض المطعم لطلب المحفظة يعمل).
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

const order = (over = {}) => ({
  customerId: 'cust1', restaurantId: 'R1', paymentMethod: 'cash', paymentId: '',
  isPaid: false, discountAmount: 0, walletUsed: 0, driverTip: 0,
  itemsTotal: 40, status: 'restaurantPending', ...over,
});

await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/cust1'), { role: 'customer', walletBalance: 1000 });
  await setDoc(doc(db, 'users/capA'), { role: 'driver' });
  await setDoc(doc(db, 'users/capB'), { role: 'driver' });
  await setDoc(doc(db, 'users/rm1'), { role: 'restaurantManager', restaurantId: 'R1' });
  await setDoc(doc(db, 'drivers/capA'), { name: 'أ', balance: 0 });
  await setDoc(doc(db, 'drivers/capB'), { name: 'ب', balance: 0 });
  await setDoc(doc(db, 'restaurants/R1'), { name: 'مطعم', commissionPercent: 15, isOpen: true });
  await setDoc(doc(db, 'delivery_settings/incentives'),
      { firstCashOrderCap: 100, maxOrderItemsTotal: 500 });
  await setDoc(doc(db, 'verified_payments/pay1'), { uid: 'cust1', amountHalalas: 10000 });
  // طلبات مزروعة لفحوص التحديث.
  await setDoc(doc(db, 'orders/oCash'), order({ status: 'onTheWay', driverId: 'capA' }));
  await setDoc(doc(db, 'orders/oDone'),
      order({ status: 'delivered', driverId: 'capA', isPaid: true }));
  await setDoc(doc(db, 'orders/oFree'),
      order({ status: 'searchingDriver', driverId: null }));
  await setDoc(doc(db, 'orders/oFree2'),
      order({ status: 'searchingDriver', driverId: null }));
  await setDoc(doc(db, 'orders/oWallet'),
      order({ walletUsed: 30, paymentMethod: 'wallet', isPaid: true }));
  await setDoc(doc(db, 'orders/oPlain'), order({}));
  await setDoc(doc(db, 'orders/oCard'),
      order({ paymentMethod: 'card', paymentId: 'pay1', isPaid: true,
              status: 'created' }));
  await setDoc(doc(db, 'orders/oCardRest'),
      order({ paymentMethod: 'card', paymentId: 'pay1', isPaid: true }));
  // وثيقة إثباتٍ قائمة بختم تسليم — لفحص «لا يُعاد تحريرها».
  await setDoc(doc(db, 'order_proofs/oDone'),
      { driverId: 'capA', orderNumber: '1', deliveryAt: new Date(),
        deliveryLat: 1, deliveryLng: 1 });
});

const cust1 = env.authenticatedContext('cust1').firestore();
const capA = env.authenticatedContext('capA').firestore();
const capB = env.authenticatedContext('capB').firestore();
const rm1 = env.authenticatedContext('rm1').firestore();

console.log('ح١ — وسيلة الدفع مجمَّدة وسندُ غير النقدي:');
await t('الكابتن لا يقلب نقديّه «إلكترونياً»', () => assertFails(
  updateDoc(doc(capA, 'orders/oCash'), { paymentMethod: 'card' })));
await t('العميل لا يقلب وسيلة دفع طلبه', () => assertFails(
  updateDoc(doc(cust1, 'orders/oPlain'), { paymentMethod: 'wallet' })));
await t('طلب «محفظة» بلا رصيد مستعمل يُرفض إنشاؤه', () => assertFails(
  setDoc(doc(cust1, 'orders/atk1'),
      order({ paymentMethod: 'wallet', walletUsed: 0 }))));
await t('طلب «بطاقة» بلا دفعة يُرفض إنشاؤه', () => assertFails(
  setDoc(doc(cust1, 'orders/atk2'),
      order({ paymentMethod: 'card', paymentId: '' }))));
await t('الطلب النقدي العادي يمرّ', () => assertSucceeds(
  setDoc(doc(cust1, 'orders/ok1'), order({}))));

console.log('\nح٢ — فرع «بلا سائق» محصور ولا لفّ للطلب المنتهي:');
await t('كابتن لا يقفز طلباً بلا سائق إلى «مُسلَّم»', () => assertFails(
  updateDoc(doc(capB, 'orders/oFree'),
      { driverId: 'capB', driverName: 'ب', status: 'delivered' })));
await t('الإسناد الذاتي بشكله المشروع يمرّ', () => assertSucceeds(
  updateDoc(doc(capB, 'orders/oFree2'),
      { driverId: 'capB', driverName: 'ب', driverPhone: '05',
        driverAcknowledged: false, operatorId: '' })));
await t('الكابتن لا يخلع اسمه عن طلبٍ مُسلَّم', () => assertFails(
  updateDoc(doc(capA, 'orders/oDone'),
      { driverId: null, driverName: null })));

console.log('\nح٣ — «العمولة المجانية» مجمَّدة بيد المطعم:');
await t('مدير المطعم لا يكتب commissionFreeUntil', () => assertFails(
  updateDoc(doc(rm1, 'restaurants/R1'),
      { commissionFreeUntil: new Date('3000-01-01') })));
await t('ويظلّ يدير مفاتيحه العادية', () => assertSucceeds(
  updateDoc(doc(rm1, 'restaurants/R1'), { isOpen: false })));

console.log('\nح٤ — وثيقة الإثبات مربوطة بالطلب ولمرة واحدة:');
await t('العميل لا يحتلّ وثيقة إثبات طلبه', () => assertFails(
  setDoc(doc(cust1, 'order_proofs/oPlain'), { driverId: 'cust1' })));
await t('كابتنٌ غير مُسنَد لا يُنشئ وثيقة الطلب', () => assertFails(
  setDoc(doc(capB, 'order_proofs/oCash'), { driverId: 'capB' })));
await t('كابتن الطلب يُنشئ وثيقته', () => assertSucceeds(
  setDoc(doc(capA, 'order_proofs/oCash'),
      { driverId: 'capA', orderNumber: '9', arrivedAt: new Date(),
        arrivedLat: 1, arrivedLng: 1 })));
await t('ختم التسليم لا يُعاد تحريره بعد كتابته', () => assertFails(
  updateDoc(doc(capA, 'order_proofs/oDone'),
      { deliveryLat: 9, deliveryLng: 9 })));

console.log('\nح٥ — سقف قيمة الوجبات بيد المدير:');
await t('itemsTotal فوق السقف (500) يُرفض', () => assertFails(
  setDoc(doc(cust1, 'orders/atk3'), order({ itemsTotal: 99999 }))));
await t('itemsTotal مجمَّد بعد الإنشاء', () => assertFails(
  updateDoc(doc(cust1, 'orders/oPlain'), { itemsTotal: 99999 })));

console.log('\nح٦ — سقف أول طلب نقدي حيّ:');
await t('نقديٌّ أول بإجمالي فوق السقف (100) يُرفض', () => assertFails(
  setDoc(doc(cust1, 'orders/atk4'),
      order({ itemsTotal: 90, driverShare: 9, appShare: 3 }))));
await t('نقديٌّ أول تحت السقف يمرّ', () => assertSucceeds(
  setDoc(doc(cust1, 'orders/ok2'),
      order({ itemsTotal: 50, driverShare: 9, appShare: 3 }))));

console.log('\nح٧ + م١ — ردود البطاقة ورفض طلب المحفظة:');
await t('العميل يلغي طلب بطاقته بختم ردٍّ معلّق', () => assertSucceeds(
  updateDoc(doc(cust1, 'orders/oCard'),
      { status: 'cancelled', cardRefundPending: true })));
await t('ختم ردّ بطاقة على طلبٍ بلا دفعة يُرفض', () => assertFails(
  updateDoc(doc(cust1, 'orders/oPlain'),
      { status: 'cancelled', cardRefundPending: true })));
await t('المطعم يرفض طلب المحفظة بعلم الردّ (كان كوداً ميتاً)', () => assertSucceeds(
  updateDoc(doc(rm1, 'orders/oWallet'),
      { status: 'restaurantRejected', rejectionReason: 'مغلق',
        walletRefundPending: true })));
await t('المطعم يرفض طلب البطاقة بعلم ردّ البطاقة', () => assertSucceeds(
  updateDoc(doc(rm1, 'orders/oCardRest'),
      { status: 'restaurantRejected', rejectionReason: 'مغلق',
        cardRefundPending: true })));
await t('علم ردّ محفظة على طلبٍ بلا محفظة يُرفض', () => assertFails(
  updateDoc(doc(rm1, 'orders/oPlain'),
      { status: 'restaurantRejected', rejectionReason: 'x',
        walletRefundPending: true })));

console.log(`\nالنتيجة: ${pass} ✅  ${fail} ❌`);
await env.cleanup();
process.exit(fail === 0 ? 0 : 1);
