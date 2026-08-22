/* هل يستطيع عميل الويب قراءة مرآة الكابتن `drivers_public`؟
 * وهل تحمل ما تحتاجه الصفحة (lat/lng) دون ما لا تحتاجه (جوّال/رصيد)؟ */
import { initializeTestEnvironment, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc } from 'firebase/firestore';
import { readFileSync } from 'node:fs';

const env = await initializeTestEnvironment({
  projectId: 'zadgo-web-mirror',
  firestore: { rules: readFileSync('../../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8181 },
});
const CUST = 'c1', DRV = 'd1';
await env.withSecurityRulesDisabled(async (c) => {
  const db = c.firestore();
  await setDoc(doc(db, 'users', CUST), { role: 'customer' });
  await setDoc(doc(db, 'drivers', DRV),
    { name: 'كابتن', phone: '0501112222', balance: -145.5, lat: 24.47, lng: 39.61 });
  await setDoc(doc(db, 'drivers_public', DRV),
    { isOnline: true, isAvailable: true, activeOrders: 1, lat: 24.47, lng: 39.61 });
});

const cust = env.authenticatedContext(CUST).firestore();
let pass = 0, fail = 0;
const t = async (n, fn) => { try { await fn(); console.log('  ✅', n); pass++; }
  catch (e) { console.log('  ❌', n, '—', String(e).slice(0, 90)); fail++; } };

await t('العميل يقرأ المرآة', () => assertSucceeds(getDoc(doc(cust, 'drivers_public', DRV))));

const m = await getDoc(doc(cust, 'drivers_public', DRV));
const d = m.data() || {};
await t('المرآة فيها الإحداثيات التي تحتاجها الصفحة',
  () => { if (d.lat == null || d.lng == null) throw new Error('لا إحداثيات'); });
await t('والمرآة **لا** تحمل جوّال الكابتن',
  () => { if ('phone' in d) throw new Error('الجوّال موجود!'); });
await t('والمرآة **لا** تحمل رصيده',
  () => { if ('balance' in d) throw new Error('الرصيد موجود!'); });

console.log('\n  حقول المرآة:', Object.keys(d).join(', '));
await env.cleanup();
console.log(`\n${fail === 0 ? '✅' : '❌'} ${pass} نجح · ${fail} فشل`);
process.exit(fail === 0 ? 0 : 1);
