/* فحص قاعدة `suggestions` (صندوق «قل لنا») على محاكي Firestore الحقيقي.
 * التشغيل وما يغطّيه: انظر README-ar.md بجانب هذا الملف.
 *
 * تُنسخ `firestore.rules` من جذر المستودع قبل التشغيل (مذكورة في
 * .gitignore هنا كي لا تُودَع نسخةٌ ثانية تتخلّف عن الأصل — نسختان من
 * القواعد أسوأ من غياب الفحص، فيُفحص ما لا يُنشر).
 */
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, collection, updateDoc, deleteDoc } from 'firebase/firestore';
import fs from 'fs';

const env = await initializeTestEnvironment({
  projectId: 'demo-zadgo',
  firestore: { rules: fs.readFileSync('firestore.rules', 'utf8'), host: '127.0.0.1', port: 8181 },
});

let pass = 0, fail = 0;
const t = async (name, fn) => {
  try { await fn(); console.log('  ✅ ' + name); pass++; }
  catch (e) { console.log('  ❌ ' + name + ' — ' + (e.message || e).slice(0, 120)); fail++; }
};

const good = (uid, over = {}) => ({
  text: 'التطبيق ممتاز لكن أتمنى إضافة الدفع بأبل باي', role: 'customer',
  name: '', contact: '', page: '/app/', lang: 'ar', uid, status: 'new',
  createdAt: new Date(), clientTime: true, ...over,
});

// الزائر المجهول = مسجَّل بلا صفة
const anon = env.authenticatedContext('anon1').firestore();
const anon2 = env.authenticatedContext('anon2').firestore();

console.log('\nالكتابة — الزائر المجهول:');
await t('يُنشئ اقتراحاً سليماً', () => assertSucceeds(setDoc(doc(anon, 'suggestions/s1'), good('anon1'))));
await t('يُنشئ مع اسم ووسيلة تواصل اختيارية', () => assertSucceeds(
  setDoc(doc(anon, 'suggestions/s2'), good('anon1', { name: 'محمد', contact: '0501234567' }))));
await t('يُرفض نصّ أقصر من خمسة أحرف', () => assertFails(
  setDoc(doc(anon, 'suggestions/s3'), good('anon1', { text: 'حلو' }))));
await t('يُرفض نصّ فوق ٢٠٠٠ حرف', () => assertFails(
  setDoc(doc(anon, 'suggestions/s4'), good('anon1', { text: 'ا'.repeat(2001) }))));
await t('يُرفض اسم فوق ٦٠ حرفاً', () => assertFails(
  setDoc(doc(anon, 'suggestions/s5'), good('anon1', { name: 'م'.repeat(61) }))));
await t('يُرفض تواصل فوق ٨٠ حرفاً', () => assertFails(
  setDoc(doc(anon, 'suggestions/s6'), good('anon1', { contact: '0'.repeat(81) }))));
await t('يُرفض نصّ ليس نصّاً (رقم)', () => assertFails(
  setDoc(doc(anon, 'suggestions/s7'), good('anon1', { text: 12345 }))));
await t('يُرفض اسم ليس نصّاً', () => assertFails(
  setDoc(doc(anon, 'suggestions/s8'), good('anon1', { name: 99 }))));
await t('يُرفض انتحال uid غيره', () => assertFails(
  setDoc(doc(anon2, 'suggestions/s9'), good('anon1'))));
await t('يُرفض status غير new', () => assertFails(
  setDoc(doc(anon, 'suggestions/s10'), good('anon1', { status: 'done' }))));
await t('يُرفض غياب النصّ كلياً', () => assertFails(
  setDoc(doc(anon, 'suggestions/s11'), { uid: 'anon1', status: 'new' })));

console.log('\nالقراءة:');
await t('الزائر لا يقرأ اقتراحه ولا غيره', () => assertFails(getDoc(doc(anon, 'suggestions/s1'))));
await t('الزائر لا يسرد المجموعة', () => assertFails(getDocs(collection(anon, 'suggestions'))));

const unauth = env.unauthenticatedContext().firestore();
await t('غير المسجَّل لا يكتب', () => assertFails(setDoc(doc(unauth, 'suggestions/s12'), good('x'))));
await t('غير المسجَّل لا يقرأ', () => assertFails(getDoc(doc(unauth, 'suggestions/s1'))));

console.log('\nالتعديل والحذف:');
await t('الزائر لا يعدّل اقتراحه', () => assertFails(
  updateDoc(doc(anon, 'suggestions/s1'), { status: 'done' })));
await t('الزائر لا يحذف', () => assertFails(deleteDoc(doc(anon, 'suggestions/s1'))));


console.log('\nالإدارة:');
// المدير بالادّعاء الموقّع — المسار الذي تعتمده اللوحة
const admin = env.authenticatedContext('boss', { admin: true }).firestore();
await t('المدير يقرأ اقتراحاً', () => assertSucceeds(getDoc(doc(admin, 'suggestions/s1'))));
await t('المدير يسرد المجموعة', () => assertSucceeds(getDocs(collection(admin, 'suggestions'))));
await t('المدير يغيّر الحالة', () => assertSucceeds(
  updateDoc(doc(admin, 'suggestions/s1'), { status: 'read' })));
await t('المدير لا يحرّف نصّ الزائر', () => assertFails(
  updateDoc(doc(admin, 'suggestions/s1'), { text: 'كلامٌ لم يكتبه' })));
await t('المدير يحذف', () => assertSucceeds(deleteDoc(doc(admin, 'suggestions/s2'))));

// موظف الدعم: يقرأ ولا يكتب. دوره من مستند users فيُزرع بلا قواعد.
await env.withSecurityRulesDisabled(async (c) => {
  await setDoc(doc(c.firestore(), 'users/helper'), { role: 'support' });
});
const sup = env.authenticatedContext('helper').firestore();
await t('الدعم يقرأ', () => assertSucceeds(getDocs(collection(sup, 'suggestions'))));
await t('الدعم لا يعدّل', () => assertFails(
  updateDoc(doc(sup, 'suggestions/s1'), { status: 'done' })));
await t('الدعم لا يحذف', () => assertFails(deleteDoc(doc(sup, 'suggestions/s1'))));

await env.cleanup();
console.log(`\nالنتيجة: ${pass} نجحت · ${fail} فشلت`);
process.exit(fail ? 1 : 0);
