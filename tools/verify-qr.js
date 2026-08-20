/* فحص مولّد QR — الخطوة الأولى: يولّد مصفوفات الحالات إلى ملفٍ مؤقّت.
 *
 * الخطوة الثانية `tools/verify-qr.py` ترسمها صوراً ويفكّها ماسحٌ حقيقي.
 * قُسّم الفحص ملفّين لأن المولّد جافاسكربت (يعمل في المتصفح) والماسح
 * المتاح بايثون — ولا معنى لأن يفحص المولّدُ نفسَه بمنطقه هو.
 *
 * التشغيل:  node tools/verify-qr.js && python3 tools/verify-qr.py
 */
const fs = require('fs');
const path = require('path');

const src = fs.readFileSync(path.join(__dirname, '..', 'docs', 'poster', 'qr.js'), 'utf8');
eval(src);                                    // يُعرّف global.ZadQR

const base = 'https://zadgo.co/order/?r=';
const cases = [
  'A',
  '1234567890',
  'مطعم فطائر المدينة',
  'https://zadgo.co',
  'https://zadgo.co/join/',
  'https://zadgo.co/order/'
];
// أطوالٌ متدرّجة تعبر حدود الإصدارات ١..٩ — الحدود هي مواضع الخلل عادةً
for (const n of [1, 5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170])
  cases.push(base + 'x'.repeat(n));

const out = {};
for (const t of cases) {
  const q = ZadQR.encode(t);
  out[t] = { ver: q.ver, n: q.n, mask: q.mask, m: q.m };
}
const dest = path.join(__dirname, 'verify-qr-cases.json');
fs.writeFileSync(dest, JSON.stringify(out));
console.log('وُلِّدت ' + cases.length + ' حالة → ' + path.relative(process.cwd(), dest));
