/* هل يقبل عقدُ القواعد ما تكتبه صفحة الطلب على الويب بعد إصلاح م٢٧؟
 * يحاكي `submitRating` حرفياً: دفعة واحدة فيها علامة التقييم وتحديث
 * المتوسّط بثلاثة حقول. والضابط: النسخة القديمة (كتابة مفردة) يجب أن تُرفض. */
import { initializeTestEnvironment, assertSucceeds, assertFails }
  from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, writeBatch, getDoc } from 'firebase/firestore';
import { readFileSync } from 'node:fs';
import assert from 'node:assert';

const env = await initializeTestEnvironment({
  projectId: 'zadgo-web-rating',
  firestore: { rules: readFileSync('../../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8181 },
});

const CUST = 'cust1', RID = 'rest1', DID = 'drv1', OID = 'order1';

await env.withSecurityRulesDisabled(async (c) => {
  const db = c.firestore();
  await setDoc(doc(db, 'users', CUST), { role: 'customer', name: 'عميل' });
  await setDoc(doc(db, 'restaurants', RID), { name: 'مطعم', rating: 4.0, ratingCount: 2 });
  await setDoc(doc(db, 'drivers', DID), { name: 'كابتن', rating: 5.0, ratingCount: 1, balance: 0 });
  await setDoc(doc(db, 'orders', OID), {
    customerId: CUST, restaurantId: RID, driverId: DID, status: 'delivered',
  });
});

const cust = env.authenticatedContext(CUST).firestore();
let pass = 0, fail = 0;
const t = async (name, fn) => {
  try { await fn(); console.log('  ✅', name); pass++; }
  catch (e) { console.log('  ❌', name, '—', String(e).slice(0, 120)); fail++; }
};

console.log('\n— الضابط: النسخة القديمة (كتابة مفردة) —');
await t('تُرفض كتابةُ المتوسّط وحدها بلا علامة (السلوك القديم)', () =>
  assertFails(updateDoc(doc(cust, 'restaurants', RID), { rating: 4.3, ratingCount: 3 })));

console.log('\n— الجديد: دفعةٌ ذرّية كما تكتبها الصفحة الآن —');
await t('تُقبل دفعةُ المطعم (علامة + ثلاثة حقول)', () => {
  const b = writeBatch(cust);
  b.set(doc(cust, 'restaurants', RID, 'ratings', OID),
    { stars: 5, customerId: CUST, createdAt: new Date() });
  b.update(doc(cust, 'restaurants', RID),
    { rating: 4.3, ratingCount: 3, ratingOrderId: OID });
  return assertSucceeds(b.commit());
});

await t('تُقبل دفعةُ الكابتن', () => {
  const b = writeBatch(cust);
  b.set(doc(cust, 'drivers', DID, 'ratings', OID),
    { stars: 4, customerId: CUST, createdAt: new Date() });
  b.update(doc(cust, 'drivers', DID),
    { rating: 4.5, ratingCount: 2, ratingOrderId: OID });
  return assertSucceeds(b.commit());
});

console.log('\n— حراسٌ يجب أن تبقى قائمة —');
await t('يُرفض تكرار التقييم لنفس الطلب', () => {
  const b = writeBatch(cust);
  b.set(doc(cust, 'restaurants', RID, 'ratings', OID),
    { stars: 5, customerId: CUST, createdAt: new Date() });
  b.update(doc(cust, 'restaurants', RID),
    { rating: 4.5, ratingCount: 4, ratingOrderId: OID });
  return assertFails(b.commit());
});

await t('يُرفض حقلٌ رابع في التحديث', () => {
  const b = writeBatch(cust);
  b.set(doc(cust, 'restaurants', RID, 'ratings', 'o2'),
    { stars: 5, customerId: CUST, createdAt: new Date() });
  b.update(doc(cust, 'restaurants', RID),
    { rating: 4.4, ratingCount: 4, ratingOrderId: 'o2', name: 'مطعمي أنا' });
  return assertFails(b.commit());
});

let snap;
await env.withSecurityRulesDisabled(async (c) => {
  snap = (await getDoc(doc(c.firestore(), 'restaurants', RID))).data();
});
console.log(`\nالمتوسّط بعد الدفعة: ${snap.rating} من ${snap.ratingCount} تقييماً`);
assert.strictEqual(snap.ratingCount, 3, 'العدّاد لم يزد');

await env.cleanup();
console.log(`\n${fail === 0 ? '✅' : '❌'} ${pass} نجح · ${fail} فشل`);
process.exit(fail === 0 ? 0 : 1);
