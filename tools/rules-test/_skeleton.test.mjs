/* هيكل اختبار أدنى للنسخ: يبذر مستخدماً وسائقاً وطلباً، ثم يؤكّد نجاحاً
 * واحداً وفشلاً واحداً. انسخه لعنقود جديد. التشغيل كما في README-ar.md:
 *   cp ../../firestore.rules .
 *   npx firebase-tools emulators:exec --only firestore --project demo-zadgo \
 *       "node _skeleton.test.mjs"
 */
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, getDoc, writeBatch, serverTimestamp } from 'firebase/firestore';
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

// بذر بلا قواعد: عميل، سائق (بحقوله المالية المحروسة)، وطلب مسلَّم يملكه العميل.
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/cust1'), { role: 'customer' });
  await setDoc(doc(db, 'users/drv1'),  { role: 'driver' });
  await setDoc(doc(db, 'drivers/drv1'),
      { balance: 0, totalEarnings: 0, warningCount: 0 });
  await setDoc(doc(db, 'orders/o1'),
      { customerId: 'cust1', restaurantId: 'r1', driverId: 'drv1', status: 'delivered' });
});

const cust1 = env.authenticatedContext('cust1').firestore();
const drv1  = env.authenticatedContext('drv1').firestore();
const admin = env.authenticatedContext('boss', { admin: true }).firestore();

console.log('\nعيّنة:');
await t('العميل يقرأ طلبه (نجاح متوقّع)', () =>
  assertSucceeds(getDoc(doc(cust1, 'orders/o1'))));
await t('السائق لا يضخّم رصيده مباشرةً (فشل متوقّع)', () =>
  assertFails(updateDoc(doc(drv1, 'drivers/drv1'), { balance: 99999 })));

console.log(`\nالنتيجة: ${pass} ✅  ${fail} ❌`);
await env.cleanup();
process.exit(fail === 0 ? 0 : 1);
