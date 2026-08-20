/* فحص «هل يوجد محتوى غير مرئي؟» — بالطريقة الصحيحة.
 *
 * ══════ الدرس الذي كلّفني وقتاً، فسُجّل هنا كي لا يتكرّر ══════
 *
 * الحركات المدفوعة بالتمرير (`animation-timeline: view()`) تجعل العنصر
 * شفافاً **ما دام خارج مداه**. فأيّ قياسٍ يلتقط الصفحة كاملةً، أو يقيس
 * بعد العودة إلى أعلاها، يرى عشرات العناصر على `opacity:0` — **وهذا هو
 * السلوك الصحيح لا عطباً**. لقطة `fullPage` تكذب للسبب نفسه.
 *
 * القياس الصادق واحد: **مرِّر كل عنصر إلى وسط الشاشة، ثم قِسه**. عنصرٌ
 * شفافٌ وهو في وسط الشاشة = عطبٌ حقيقي. وما عداه ضجيج.
 *
 * التشغيل:
 *   cd docs && python3 -m http.server 8899 &
 *   node tools/web-check/reveal-audit.js [مسار] [عرض×ارتفاع ...]
 */
const { chromium } = require(process.env.PW ||
  '/opt/node22/lib/node_modules/playwright');
const PORT = process.env.PORT || 8899;
const PATH_ = process.argv[2] || '/';
const VIEWPORTS = (process.argv.slice(3).length ? process.argv.slice(3)
  : ['360x640', '390x844', '768x1024', '1440x900'])
  .map(v => { const [w, h] = v.split('x').map(Number); return { width: w, height: h }; });

(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  let fails = 0;
  for (const vp of VIEWPORTS) {
    const p = await b.newPage({ viewport: vp });
    const errs = [];
    p.on('pageerror', e => errs.push(e.message));
    await p.goto(`http://127.0.0.1:${PORT}${PATH_}?cb=` + Math.random(),
      { waitUntil: 'domcontentloaded' });
    await p.waitForTimeout(350);
    const r = await p.evaluate(async () => {
      const sleep = ms => new Promise(r => setTimeout(r, ms));
      // كل عنصرٍ له محتوى نصّي أو صورة، لا `.reveal` وحدها — العطب قد
      // يصيب ما لم نُعلِّمه.
      const els = [...document.querySelectorAll('section *')].filter(e => {
        const t = (e.textContent || '').trim();
        return (t.length > 3 || e.tagName === 'IMG') && e.children.length < 4;
      });
      const bad = [];
      for (const el of els) {
        const r0 = el.getBoundingClientRect();
        if (!r0.width || !r0.height) continue;
        el.scrollIntoView({ block: 'center', behavior: 'instant' });
        await sleep(60);
        const s = getComputedStyle(el);
        if (+s.opacity < 0.9 && s.visibility !== 'hidden' && s.display !== 'none') {
          bad.push(`${el.tagName}.${(el.className || '').toString().split(' ')[0]}=${(+s.opacity).toFixed(2)}`);
        }
      }
      return { checked: els.length, bad };
    });
    const ok = r.bad.length === 0 && errs.length === 0;
    if (!ok) fails++;
    console.log(`${String(vp.width).padStart(4)}×${vp.height} | فُحص ${String(r.checked).padStart(3)} عنصراً | ` +
      (r.bad.length ? `❌ غير مرئي وهو في الشاشة: ${r.bad.slice(0, 6).join(', ')}` : '✅ لا شيء مخفيّ') +
      (errs.length ? ` | ❌ أخطاء: ${errs[0]}` : ''));
    await p.close();
  }
  await b.close();
  process.exit(fails ? 1 : 0);
})();
