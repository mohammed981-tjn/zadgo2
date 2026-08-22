/* دفعة «سُدّ الثغرة» (فحص دفعة ٨ + أمر المالك 2026-08-22) — حرّاس القواعد:
 * 🔴١ التسوية لا تسكّ رصيداً (جِدّة الحركة، نوع المبلغ، نحو الصفر، القيد
 * المرآتي على دفتر المشغّل)، 🔴٢ بوابة الأكواد من البابين، 🔴٣ شبح
 * السائق، 🔴٤ المحظور لا يلتقط طلباً، 🟠١ الحصّة إلزامية عند التسليم،
 * انحدار ١ لا تجريدَ على المُسلَّم، وسردُ الدفتر بخمس وعشرين حركة.
 *   cp ../../firestore.rules . && npx firebase-tools emulators:exec \
 *     --only firestore --project demo-zadgo "node operator9.test.mjs"
 */
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDocs, setDoc, updateDoc, writeBatch, collection, query, where } from 'firebase/firestore';
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
  await setDoc(doc(db, 'users/op1'), { role: 'fleetOperator' });
  await setDoc(doc(db, 'users/capA'), { role: 'driver' });
  await setDoc(doc(db, 'users/capB'), { role: 'driver' });
  await setDoc(doc(db, 'users/capBan'), { role: 'driver' });
  await setDoc(doc(db, 'users/capNew'), { role: 'driver' });
  await setDoc(doc(db, 'users/cust1'), { role: 'customer' });
  await setDoc(doc(db, 'users/rm1'), { role: 'restaurantManager', restaurantId: 'R1' });
  await setDoc(doc(db, 'drivers/capA'),
      { name: 'أ', balance: -500, operatorId: 'op1', operatorDriverShare: 7,
        lastLedgerTxId: 'oldTx1', isActive: true });
  await setDoc(doc(db, 'drivers/capB'),
      { name: 'ب', balance: 300, operatorId: 'op1', lastLedgerTxId: '' });
  await setDoc(doc(db, 'drivers/capBan'),
      { name: 'م', balance: 0, isActive: false, isOnline: true });
  await setDoc(doc(db, 'driver_transactions/oldTx1'),
      { driverId: 'capA', type: 'operatorSettlement', amount: 250,
        createdBy: 'op1' });
  await setDoc(doc(db, 'orders/oFree'),
      { customerId: 'cust1', restaurantId: 'R1', driverId: null,
        status: 'searchingDriver', paymentMethod: 'cash' });
  await setDoc(doc(db, 'orders/oFree2'),
      { customerId: 'cust1', restaurantId: 'R1', driverId: null,
        status: 'searchingDriver', paymentMethod: 'cash' });
  await setDoc(doc(db, 'orders/oWayA'),
      { customerId: 'cust1', restaurantId: 'R1', driverId: 'capA',
        status: 'onTheWay', paymentMethod: 'card', isPaid: true,
        itemsTotal: 40, appShare: 3, walletUsed: 0, discountAmount: 0,
        driverShare: 9, driverTip: 0, custodyDebited: true, operatorShare: 0 });
  await setDoc(doc(db, 'orders/oDoneA'),
      { customerId: 'cust1', restaurantId: 'R1', driverId: 'capA',
        driverName: 'أ', operatorId: 'op1', status: 'delivered',
        paymentMethod: 'cash' });
  await setDoc(doc(db, 'registrationCodes/OPCODE'),
      { role: 'driver', operatorId: 'op1', isUsed: false });
  await setDoc(doc(db, 'registrationCodes/STAMPED'),
      { role: 'driver', operatorId: '', isUsed: false, usedByUid: 'muleGuy' });
  // ٢٥ حركة لسرد الدفتر.
  for (let i = 0; i < 25; i++) {
    await setDoc(doc(db, `driver_transactions/hist$${i}`),
        { driverId: 'capB', type: 'deliveryOnline', amount: 5,
          orderId: 'x', createdAt: new Date(2026, 7, i + 1) });
  }
});

const op1 = env.authenticatedContext('op1', { fleetOperator: true }).firestore();
const capA = env.authenticatedContext('capA').firestore();
const capB = env.authenticatedContext('capB').firestore();
const capBan = env.authenticatedContext('capBan').firestore();
const capNew = env.authenticatedContext('capNew').firestore();
const cust1 = env.authenticatedContext('cust1').firestore();
const muleGuy = env.authenticatedContext('muleGuy').firestore();
const rm1 = env.authenticatedContext('rm1').firestore();

const settle = (db, { txId, amount, balance, mirror = true, txAmount = amount,
    omitTxAmount = false, keepOldId = false }) => {
  const b = writeBatch(db);
  if (txId) {
    b.set(doc(db, `driver_transactions/${txId}`), {
      driverId: 'capA', type: 'operatorSettlement',
      ...(omitTxAmount ? {} : { amount: txAmount }),
      balanceAfter: balance, note: '', performedBy: 'op1',
      createdBy: 'op1', createdAt: new Date(),
    });
  }
  if (mirror && txId) {
    b.set(doc(db, `operator_transactions/${txId}`), {
      operatorId: 'op1', driverId: 'capA', driverName: 'أ',
      type: 'driverSettlement', amount: -txAmount, note: '',
      createdBy: 'op1', createdAt: new Date(),
    });
  }
  b.update(doc(db, 'drivers/capA'), {
    balance: balance,
    lastLedgerTxId: keepOldId ? 'oldTx1' : (txId ?? 'oldTx1'),
  });
  return b.commit();
};

console.log('🔴١ — التسوية لا تسكّ رصيداً:');
await t('تحصيل كامل مشروع (-500→0) بحركة جديدة وقيد مرآتي يمرّ', () =>
  assertSucceeds(settle(op1, { txId: 'sNew1', amount: 500, balance: 0 })));
await env.withSecurityRulesDisabled(async (ctx) => {
  // إرجاع الرصيد للتجارب السالبة التالية.
  await setDoc(doc(ctx.firestore(), 'drivers/capA'),
      { name: 'أ', balance: -500, operatorId: 'op1', operatorDriverShare: 7,
        lastLedgerTxId: 'oldTx1', isActive: true });
});
await t('بلا قيدٍ مرآتي على دفتر المشغّل تُرفض (الدفتر المزدوج)', () =>
  assertFails(settle(op1, { txId: 'sNoMirror', amount: 500, balance: 0,
      mirror: false })));
await t('إعادة استعمال حركة قديمة (المعرّف لم يتغيّر) تُرفض', () =>
  assertFails(settle(op1, { txId: null, amount: 250, balance: -250,
      keepOldId: true })));
await t('حركة بلا حقل مبلغ تُرفض (كانت تمرّر أي فرق)', () =>
  assertFails(settle(op1, { txId: 'sNoAmt', amount: 500, balance: 0,
      omitTxAmount: true })));
await t('تجاوز الصفر (-500→+100) يُرفض', () =>
  assertFails(settle(op1, { txId: 'sCross', amount: 600, balance: 100 })));
await t('سكٌّ فوق رصيدٍ موجب (300→1000000) يُرفض', () => assertFails((() => {
  const b = writeBatch(op1);
  b.set(doc(op1, 'driver_transactions/sMint'), {
    driverId: 'capB', type: 'operatorSettlement', amount: 999700,
    balanceAfter: 1000000, createdBy: 'op1', createdAt: new Date(),
  });
  b.set(doc(op1, 'operator_transactions/sMint'), {
    operatorId: 'op1', driverId: 'capB', type: 'driverSettlement',
    amount: -999700, createdBy: 'op1', createdAt: new Date(),
  });
  b.update(doc(op1, 'drivers/capB'),
      { balance: 1000000, lastLedgerTxId: 'sMint' });
  return b.commit();
})()));

console.log('\n🔴٢ — بوابة «الأسطول يضيف والإدارة توافق» من البابين:');
await t('المشغّل لا يسكّ كوداً مختوماً باسم مستهلِكه', () => assertFails(
  setDoc(doc(op1, 'registrationCodes/PRESTAMP'),
      { role: 'driver', operatorId: 'op1', isUsed: false,
        usedByUid: 'muleUid', createdAt: new Date() })));
await t('منح الدور بكودٍ مختومٍ غير مستهلَك يُرفض', () => assertFails(
  setDoc(doc(muleGuy, 'users/muleGuy'),
      { role: 'driver', registrationCode: 'STAMPED', name: 'بغل' })));
await t('مستند سائقٍ بتبعيّة كودٍ غير مستهلَك يُرفض', () => assertFails(
  setDoc(doc(capNew, 'drivers/capNew'),
      { name: 'جديد', balance: 0, totalEarnings: 0, warningCount: 0,
        isOnline: false, activeOrders: 0, operatorId: 'op1',
        registrationCode: 'OPCODE', operatorDriverShare: 0 })));

console.log('\n🔴٣ — لا «كابتن شبح»:');
await t('عميلٌ لا ينشئ مستند سائق', () => assertFails(
  setDoc(doc(cust1, 'drivers/cust1'),
      { name: 'شبح', balance: 0, totalEarnings: 0, warningCount: 0,
        isOnline: false, activeOrders: 0 })));
await t('سائقٌ لا يولد «متصلاً» أو بإحداثيات', () => assertFails(
  setDoc(doc(capNew, 'drivers/capNew'),
      { name: 'جديد', balance: 0, totalEarnings: 0, warningCount: 0,
        isOnline: true, activeOrders: 0, lat: 24.4, lng: 39.6 })));
await t('ميلادٌ سليم (دور سائق، غير متصل، بلا موقع) يمرّ', () => assertSucceeds(
  setDoc(doc(capNew, 'drivers/capNew'),
      { name: 'جديد', balance: 0, totalEarnings: 0, warningCount: 0,
        isOnline: false, activeOrders: 0 })));

console.log('\n🔴٤ — المحظور لا يلتقط طلباً حراً:');
await t('كابتن محظور (isActive=false) يُرفض التقاطه', () => assertFails(
  updateDoc(doc(capBan, 'orders/oFree'),
      { driverId: 'capBan', driverName: 'م', driverAcknowledged: true,
        operatorId: '', updatedAt: new Date() })));
await t('كابتن مفعّل يلتقط الطلب الحر', () => assertSucceeds(
  updateDoc(doc(capB, 'orders/oFree2'),
      { driverId: 'capB', driverName: 'ب', driverAcknowledged: true,
        operatorId: 'op1', updatedAt: new Date() })));

console.log('\n🟠١ — حصّة المشغّل إلزامية عند تسليم كابتن الأسطول:');
await t('تسليمٌ بلا كتابة الحصّة يُرفض (كانت اختيارية)', () => assertFails(
  updateDoc(doc(capA, 'orders/oWayA'),
      { status: 'delivered', isPaid: true, updatedAt: new Date() })));
await t('تسليمٌ بالحصّة المحسوبة (9−7=2) يمرّ', () => assertSucceeds(
  updateDoc(doc(capA, 'orders/oWayA'),
      { status: 'delivered', isPaid: true, operatorShare: 2,
        updatedAt: new Date() })));

console.log('\nانحدار ١ — لا تجريد تبعيةٍ على طلبٍ مُسلَّم:');
await t('الكابتن لا يمحو تبعية المشغّل عن المُسلَّم', () => assertFails(
  updateDoc(doc(capA, 'orders/oDoneA'),
      { driverId: null, driverName: null, operatorId: '',
        updatedAt: new Date() })));
await t('المطعم لا يمحوها أيضاً', () => assertFails(
  updateDoc(doc(rm1, 'orders/oDoneA'),
      { driverId: null, driverName: null, operatorId: '',
        updatedAt: new Date() })));

console.log('\nسرد الدفتر — ٢٥ حركة دفعةً واحدة (هاجس سقف القراءات):');
await t('الكابتن يسرد دفتره الخاص (٢٥ حركة)', () => assertSucceeds(
  getDocs(query(collection(capB, 'driver_transactions'),
      where('driverId', '==', 'capB')))));
await t('المشغّل يقرأ دفتر كابتنه ويسرد دفتره هو', () => assertSucceeds((async () => {
  await getDocs(query(collection(op1, 'operator_transactions'),
      where('operatorId', '==', 'op1')));
})()));

console.log(`\nالنتيجة: ${pass} ✅  ${fail} ❌`);
await env.cleanup();
process.exit(fail === 0 ? 0 : 1);
