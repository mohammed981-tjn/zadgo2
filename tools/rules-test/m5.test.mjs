/* دفعة م٥ الهيكلية — مرآة الإسناد drivers_public وحصر سرد الكباتن،
 * وربط إنشاء الشكوى بأطراف الطلب. حرّاس القواعد على المحاكي:
 *   cp ../../firestore.rules . && npx firebase-tools emulators:exec \
 *     --only firestore --project demo-zadgo "node m5.test.mjs"
 */
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, getDocs, setDoc, updateDoc, collection, query, where } from 'firebase/firestore';
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
  await setDoc(doc(db, 'users/cust1'), { role: 'customer' });
  await setDoc(doc(db, 'users/cust2'), { role: 'customer' });
  await setDoc(doc(db, 'users/capA'), { role: 'driver' });
  await setDoc(doc(db, 'users/capB'), { role: 'driver' });
  await setDoc(doc(db, 'users/rm1'), { role: 'restaurantManager', restaurantId: 'R1' });
  await setDoc(doc(db, 'users/sup1'), { role: 'support', isActive: true });
  await setDoc(doc(db, 'users/op1'), { role: 'fleetOperator' });
  await setDoc(doc(db, 'users/boss'), { role: 'admin' });
  await setDoc(doc(db, 'drivers/capA'),
      { name: 'أ', phone: '0500000001', balance: 120, operatorId: 'op1' });
  await setDoc(doc(db, 'drivers/capB'),
      { name: 'ب', phone: '0500000002', balance: 300, operatorId: '' });
  await setDoc(doc(db, 'drivers_public/capA'),
      { isOnline: true, isAvailable: true, activeOrders: 0 });
  await setDoc(doc(db, 'drivers_public/capB'),
      { isOnline: true, isAvailable: true, activeOrders: 1 });
  await setDoc(doc(db, 'orders/o1'),
      { customerId: 'cust1', restaurantId: 'R1', driverId: 'capA',
        status: 'delivered', orderNumber: '1001' });
});

const cust1 = env.authenticatedContext('cust1').firestore();
const cust2 = env.authenticatedContext('cust2').firestore();
const capA = env.authenticatedContext('capA').firestore();
const capB = env.authenticatedContext('capB').firestore();
const rm1 = env.authenticatedContext('rm1').firestore();
const sup1 = env.authenticatedContext('sup1').firestore();
const op1 = env.authenticatedContext('op1', { fleetOperator: true }).firestore();
const boss = env.authenticatedContext('boss', { admin: true }).firestore();

console.log('م٥ — سرد drivers الكامل صار للمدير والدعم (والمشغّل على كباتنه):');
await t('كابتن لا يسرد سجلّ الكباتن', () => assertFails(
  getDocs(collection(capA, 'drivers'))));
await t('مدير مطعم لا يسرد سجلّ الكباتن', () => assertFails(
  getDocs(collection(rm1, 'drivers'))));
await t('المدير يسرد', () => assertSucceeds(
  getDocs(collection(boss, 'drivers'))));
await t('الدعم يسرد', () => assertSucceeds(
  getDocs(collection(sup1, 'drivers'))));
await t('المشغّل يسرد كباتنه حصراً (استعلام مقيَّد)', () => assertSucceeds(
  getDocs(query(collection(op1, 'drivers'), where('operatorId', '==', 'op1')))));
await t('المشغّل لا يسرد القائمة كاملة', () => assertFails(
  getDocs(collection(op1, 'drivers'))));
await t('جلب مستند واحد يبقى لأي مسجَّل (تتبّع الطلب وإعادة تحقق الإسناد)',
  () => assertSucceeds(getDoc(doc(cust1, 'drivers/capA'))));

console.log('\nم٥ — المرآة drivers_public مقروءة للجميع وبقائمة حقول مغلقة:');
await t('مدير المطعم يسرد المرآة (الترشيح)', () => assertSucceeds(
  getDocs(collection(rm1, 'drivers_public'))));
await t('الكابتن يسرد المرآة (إعادة الترشيح بعد رفضه)', () => assertSucceeds(
  getDocs(collection(capA, 'drivers_public'))));
await t('الكابتن يبثّ استرشادياته على مرآته', () => assertSucceeds(
  updateDoc(doc(capA, 'drivers_public/capA'),
      { isOnline: true, lat: 24.47, lng: 39.61, activeOrders: 1 })));
await t('الكابتن لا يكتب مرآة زميله', () => assertFails(
  updateDoc(doc(capA, 'drivers_public/capB'), { isAvailable: false })));
await t('الكابتن لا يرفع حظره عبر المرآة (isActive خارج قائمته)', () => assertFails(
  updateDoc(doc(capA, 'drivers_public/capA'), { isActive: true })));
await t('الكابتن لا يهرّب حقلاً غريباً إلى المرآة', () => assertFails(
  updateDoc(doc(capA, 'drivers_public/capA'), { balance: 0 })));
await t('جهاز المطعم يقفل مرشَّحاً (isAvailable وحده)', () => assertSucceeds(
  updateDoc(doc(rm1, 'drivers_public/capB'), { isAvailable: false })));
await t('جهاز المطعم لا يمسّ غير القفل', () => assertFails(
  updateDoc(doc(rm1, 'drivers_public/capA'), { activeOrders: 0 })));
await t('المشغّل يعكس حظر كابتنه على المرآة', () => assertSucceeds(
  updateDoc(doc(op1, 'drivers_public/capA'), { isActive: false })));
await t('المشغّل لا يحظر كابتناً ليس من أسطوله', () => assertFails(
  updateDoc(doc(op1, 'drivers_public/capB'), { isActive: false })));
await t('العميل لا يكتب على المرآة', () => assertFails(
  updateDoc(doc(cust1, 'drivers_public/capA'), { isAvailable: false })));
await t('الكابتن يُنشئ مرآته أول نبضة (البذر الذاتي)', () => assertSucceeds(
  setDoc(doc(capB, 'drivers_public/capB'),
      { isOnline: true, isAvailable: true, activeOrders: 0 }, { merge: true })));

console.log('\nم٢٤ (النصف المتبقّي) — الشكوى المربوطة بطلب لطرفٍ فيه حصراً:');
await t('عميل الطلب يشتكي على طلبه', () => assertSucceeds(
  setDoc(doc(cust1, 'complaints/c1'),
      { orderId: 'o1', customerId: 'cust1', submittedByUid: 'cust1',
        type: 'order', description: 'وصل بارداً', status: 'open' })));
await t('كابتن الطلب يشتكي على طلبه', () => assertSucceeds(
  setDoc(doc(capA, 'complaints/c2'),
      { orderId: 'o1', customerId: 'cust1', submittedByUid: 'capA',
        type: 'order', description: 'العميل لم يرد', status: 'open' })));
await t('غريبٌ عن الطلب لا يفتح شكوى عليه', () => assertFails(
  setDoc(doc(cust2, 'complaints/c3'),
      { orderId: 'o1', customerId: 'cust2', submittedByUid: 'cust2',
        type: 'order', description: 'ملفَّقة', status: 'open' })));
await t('كابتن غريب لا يفتح شكوى على طلب زميله', () => assertFails(
  setDoc(doc(capB, 'complaints/c4'),
      { orderId: 'o1', customerId: 'cust1', submittedByUid: 'capB',
        type: 'order', description: 'ملفَّقة', status: 'open' })));
await t('التذكرة العامة (بلا طلب) تمرّ كما كانت', () => assertSucceeds(
  setDoc(doc(cust2, 'complaints/c5'),
      { orderId: '', customerId: 'cust2', submittedByUid: 'cust2',
        type: 'general', description: 'اقتراح', status: 'open' })));

console.log(`\nالنتيجة: ${pass} ✅  ${fail} ❌`);
await env.cleanup();
process.exit(fail === 0 ? 0 : 1);
