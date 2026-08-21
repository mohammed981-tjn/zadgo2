/* دفعة ٥ / نموّ العميل — حماية حقول الكاش باك وإحالة العميل على المحاكي.
 *   cp ../../firestore.rules . && npx firebase-tools emulators:exec \
 *     --only firestore --project demo-zadgo "node growth5.test.mjs"
 *
 * تُثبت أن القواعد خط الدفاع الوحيد يمنع:
 *   • سكّ العميل ختمَ referralRewarded أو تغيير referredByCode بعد الإنشاء.
 *   • إنشاء العميل حركةَ محفظة موجبة (سكّ رصيد وهمي في الدفتر).
 *   • إنشاء العميل علامةَ كاش باك (الصرف عملية مدير).
 *   • زيادة العميل رصيده مباشرةً.
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
  // عميل قائم برصيد ومكافأةٍ مصروفة، لاختبار التجميد.
  await setDoc(doc(db, 'users/cust1'), {
    role: 'customer', walletBalance: 100,
    referredByCode: 'ABC123', referralRewarded: false,
  });
  await setDoc(doc(db, 'users/cust2'), {
    role: 'customer', walletBalance: 0,
    referredByCode: '', referralRewarded: false,
  });
  await setDoc(doc(db, 'orders/ord1'), { customerId: 'cust1', status: 'delivered', itemsTotal: 40 });
});

const cust1 = env.authenticatedContext('cust1').firestore();
const admin = env.authenticatedContext('boss', { admin: true }).firestore();

console.log('\nإحالة العميل — التجميد:');
await t('العميل لا يسكّ ختم referralRewarded على نفسه', () => assertFails(
  updateDoc(doc(cust1, 'users/cust1'), { referralRewarded: true })));
await t('العميل لا يغيّر كود الداعي بعد الإنشاء', () => assertFails(
  updateDoc(doc(cust1, 'users/cust1'), { referredByCode: 'XYZ999' })));
await t('المدير يسكّ ختم referralRewarded', () => assertSucceeds(
  updateDoc(doc(admin, 'users/cust1'), { referralRewarded: true })));

console.log('\nإحالة العميل — الإنشاء:');
const newAuth = (uid) => env.authenticatedContext(uid).firestore();
await t('إنشاء ذاتي بكود داعٍ ورصيد صفر يمرّ', () => assertSucceeds(
  setDoc(doc(newAuth('newA'), 'users/newA'),
    { role: 'customer', walletBalance: 0, referredByCode: 'ABC123', referralRewarded: false })));
await t('إنشاء ذاتي بـ referralRewarded=true يُرفض', () => assertFails(
  setDoc(doc(newAuth('newB'), 'users/newB'),
    { role: 'customer', walletBalance: 0, referredByCode: 'ABC123', referralRewarded: true })));

console.log('\nالمحفظة والدفتر:');
await t('العميل لا يزيد رصيده مباشرةً', () => assertFails(
  updateDoc(doc(cust1, 'users/cust1'), { walletBalance: 5000 })));
await t('العميل يُنقص رصيده (دفع من محفظته)', () => assertSucceeds(
  updateDoc(doc(cust1, 'users/cust1'), { walletBalance: 90 })));
await t('العميل يُنشئ حركة محفظة سالبة (خصم)', () => assertSucceeds(
  setDoc(doc(cust1, 'wallet_transactions/wtx_neg'),
    { userId: 'cust1', amount: -10, type: 'orderPayment' })));
await t('العميل لا يُنشئ حركة محفظة موجبة (سكّ رصيد وهمي)', () => assertFails(
  setDoc(doc(cust1, 'wallet_transactions/wtx_pos'),
    { userId: 'cust1', amount: 1000, type: 'refund' })));
await t('المدير يُنشئ حركة محفظة موجبة (استرداد/كاش باك)', () => assertSucceeds(
  setDoc(doc(admin, 'wallet_transactions/wtx_admin'),
    { userId: 'cust1', amount: 1000, type: 'cashback' })));

console.log('\nعلامات الكاش باك:');
await t('العميل لا يُنشئ علامة كاش باك لطلبه', () => assertFails(
  setDoc(doc(cust1, 'cashback_grants/ord1'),
    { customerId: 'cust1', orderId: 'ord1', amount: 4 })));
await t('المدير يُنشئ علامة كاش باك', () => assertSucceeds(
  setDoc(doc(admin, 'cashback_grants/ord1'),
    { customerId: 'cust1', orderId: 'ord1', amount: 4 })));
await t('العميل يقرأ علامة كاش باك طلبه', () => assertSucceeds(
  (async () => { const { getDoc } = await import('firebase/firestore');
    await getDoc(doc(cust1, 'cashback_grants/ord1')); })()));
await t('لا أحد يعدّل علامة الكاش باك (سجلّ لا يُعاد)', () => assertFails(
  updateDoc(doc(admin, 'cashback_grants/ord1'), { amount: 999 })));

console.log(`\nالنتيجة: ${pass} ✅  ${fail} ❌`);
await env.cleanup();
process.exit(fail === 0 ? 0 : 1);
