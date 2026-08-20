/* فحص قاعدة التقييم (§٠: منع تكرار/تلفيق تقييم المطعم والسائق) على محاكي
 * Firestore الحقيقي. التشغيل كما في README-ar.md:
 *   cp ../../firestore.rules .
 *   npx firebase-tools emulators:exec --only firestore --project demo-zadgo \
 *       "node rating.test.mjs"
 *
 * الفكرة المفحوصة: زيادة عدّاد التقييم لا تُقبل إلا في دفعةٍ تُنشئ «علامة
 * تقييم» للطلب (restaurants|drivers/{id}/ratings/{orderId})، والعلامة
 * تشترط طلباً مسلَّماً يملكه العميل. فالمسار المباشر (تحديث العدّاد وحده)
 * مرفوض، والتكرار مرفوض (لا علامة مرتين)، والتلفيق مرفوض (لا طلب = لا علامة).
 */
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, writeBatch, serverTimestamp } from 'firebase/firestore';
import fs from 'fs';

const env = await initializeTestEnvironment({
  projectId: 'demo-zadgo',
  firestore: { rules: fs.readFileSync('firestore.rules', 'utf8'), host: '127.0.0.1', port: 8181 },
});

let pass = 0, fail = 0;
const t = async (name, fn) => {
  try { await fn(); console.log('  ✅ ' + name); pass++; }
  catch (e) { console.log('  ❌ ' + name + ' — ' + (e.message || e).slice(0, 140)); fail++; }
};

// بذر البيانات بلا قواعد: عميلان، طلبٌ مسلَّم وآخر قيد التحضير، مطعم وسائق.
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/cust1'), { role: 'customer' });
  await setDoc(doc(db, 'users/cust2'), { role: 'customer' });
  await setDoc(doc(db, 'orders/o1'),
      { customerId: 'cust1', restaurantId: 'r1', driverId: 'd1', status: 'delivered' });
  await setDoc(doc(db, 'orders/o2'), // لم يُسلَّم بعد
      { customerId: 'cust1', restaurantId: 'r1', driverId: 'd1', status: 'preparing' });
  await setDoc(doc(db, 'restaurants/r1'), { rating: 5, ratingCount: 2 });
  await setDoc(doc(db, 'drivers/d1'),
      { rating: 5, ratingCount: 2, balance: 0, totalEarnings: 0, warningCount: 0 });
});

const c1 = env.authenticatedContext('cust1').firestore();
const c2 = env.authenticatedContext('cust2').firestore();

// دفعةٌ سليمة: علامة + زيادة عدّاد معاً. المتوسط الجديد لـstars=4 على
// عدّادٍ 2 متوسطه 5: (5*2+4)/3 = 4.6667 → 4.7، والعدّاد 3.
const rateBatch = (db, coll, id, orderId, stars, newAvg, newCount) => {
  const b = writeBatch(db);
  b.set(doc(db, `${coll}/${id}/ratings/${orderId}`),
      { stars, customerId: 'cust1', createdAt: serverTimestamp() });
  b.update(doc(db, `${coll}/${id}`),
      { rating: newAvg, ratingCount: newCount, ratingOrderId: orderId });
  return b.commit();
};

console.log('\nتقييم المطعم:');
await t('العميل صاحب الطلب المسلَّم يقيّم مرة (علامة + عدّاد)', () =>
  assertSucceeds(rateBatch(c1, 'restaurants', 'r1', 'o1', 4, 4.7, 3)));

await t('التكرار على الطلب نفسه يُرفض (العلامة موجودة)', () =>
  assertFails(rateBatch(c1, 'restaurants', 'r1', 'o1', 1, 3.5, 4)));

await t('المسار المباشر (زيادة العدّاد بلا علامة) يُرفض — جوهر §٠', () =>
  assertFails(updateDoc(doc(c1, 'restaurants/r1'),
      { rating: 5, ratingCount: 99, ratingOrderId: 'o1' })));

await t('علامة لطلبٍ لا يملكه العميل تُرفض', () =>
  assertFails(rateBatch(c2, 'restaurants', 'r1', 'o1', 1, 4.0, 3)));

await t('علامة لطلبٍ لم يُسلَّم بعد تُرفض', () =>
  assertFails(rateBatch(c1, 'restaurants', 'r1', 'o2', 5, 5, 3)));

await t('قفزة في العدّاد (+2) مرفوضة رغم العلامة', () => {
  const b = writeBatch(c1);
  b.set(doc(c1, 'restaurants/r1/ratings/o2b'),
      { stars: 5, customerId: 'cust1', createdAt: serverTimestamp() });
  b.update(doc(c1, 'restaurants/r1'), { rating: 5, ratingCount: 5, ratingOrderId: 'o2b' });
  return assertFails(b.commit());
});

console.log('\nتقييم السائق:');
await t('العميل يقيّم سائق طلبه المسلَّم مرة', () =>
  assertSucceeds(rateBatch(c1, 'drivers', 'd1', 'o1', 4, 4.7, 3)));

await t('تكرار تقييم السائق على الطلب نفسه يُرفض', () =>
  assertFails(rateBatch(c1, 'drivers', 'd1', 'o1', 1, 3.5, 4)));

await t('زيادة عدّاد السائق مباشرةً بلا علامة تُرفض', () =>
  assertFails(updateDoc(doc(c1, 'drivers/d1'),
      { rating: 5, ratingCount: 99, ratingOrderId: 'o1' })));

console.log(`\nالنتيجة: ${pass} ✅  ${fail} ❌`);
await env.cleanup();
process.exit(fail === 0 ? 0 : 1);
