/* فحصٌ شامل لكل صفحات الموقع — يُشغَّل قبل كل دفعة كبيرة وبعدها.
 *
 * يفحص لكل صفحة × كل مقاس شاشة × كل لغة:
 *   · أخطاء جافاسكربت وأخطاء الوحدة (console errors)
 *   · التمرير الأفقي (أكثر أعطال RTL شيوعاً)
 *   · محتوىً غير مرئي وهو في الشاشة (انظر reveal-audit.js للدرس)
 *   · مفاتيح ترجمة فارغة (نصٌّ اختفى مع تبديل اللغة)
 *   · صورٌ لم تُحمَّل، وصورٌ بلا بديلٍ نصّي
 *   · أهدافُ لمسٍ أصغر من 40 بكسل
 *   · تباينٌ ضعيف في النصوص الظاهرة
 *   · وزن الصفحة وعدد الطلبات
 *
 * التشغيل:
 *   cd docs && python3 -m http.server 8899 &
 *   node tools/web-check/site-audit.js            # كل الصفحات
 *   node tools/web-check/site-audit.js /app/      # صفحة واحدة
 *   SHOTS=1 node tools/web-check/site-audit.js    # مع حفظ اللقطات
 *
 * يخرج برمز 1 إن وُجد عطب — فيصلح لبوّابة قبل الدفع.
 */
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const fs = require('fs');
const PORT = process.env.PORT || 8899;
const SHOTS = process.env.SHOTS === '1';
const SHOT_DIR = process.env.SHOT_DIR || '/tmp/zadgo-shots';

const PAGES = process.argv[2] ? [process.argv[2]]
  : ['/', '/app/', '/partner/', '/join/', '/contact.html',
     '/privacy-policy.html', '/terms.html', '/delete-account.html', '/404.html'];
const VIEWPORTS = [{ width: 360, height: 640, tag: 'صغير' },
                   { width: 390, height: 844, tag: 'جوّال' },
                   { width: 768, height: 1024, tag: 'لوحي' },
                   { width: 1440, height: 900, tag: 'سطح' }];
const LANGS = ['ar', 'en', 'ur'];

// تباينٌ نسبي حسب WCAG
function lum(rgb) {
  const c = rgb.map(v => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); });
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}

(async () => {
  if (SHOTS) fs.mkdirSync(SHOT_DIR, { recursive: true });
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  let problems = 0, checks = 0;

  for (const path_ of PAGES) {
    for (const vp of VIEWPORTS) {
      // اللغات تُفحص على مقاس الجوّال وحده — التبديل لا يتأثّر بالعرض،
      // وفحصُ كل لغة على كل مقاس يضاعف الزمن بلا كشفٍ جديد.
      const langs = vp.width === 390 ? LANGS : ['ar'];
      for (const lang of langs) {
        checks++;
        const p = await b.newPage({ viewport: { width: vp.width, height: vp.height } });
        const errs = [];
        p.on('pageerror', e => errs.push('JS: ' + e.message.slice(0, 90)));
        p.on('console', m => {
          const t = m.text();
          if (m.type() === 'error' &&
              !/ERR_CONNECTION|ERR_NAME|net::|frame-ancestors|Failed to load resource/.test(t)) {
            errs.push('CONSOLE: ' + t.slice(0, 90));
          }
        });
        let bytes = 0, reqs = 0;
        p.on('response', async r => { reqs++; try { bytes += (await r.body()).length; } catch (e) {} });
        await p.addInitScript(l => localStorage.setItem('zadgo-lang', l), lang);

        let res;
        try {
          await p.goto(`http://127.0.0.1:${PORT}${path_}?cb=${Math.random()}`,
            { waitUntil: 'domcontentloaded', timeout: 20000 });
          await p.waitForTimeout(700);
          res = await p.evaluate(async () => {
            const sleep = ms => new Promise(r => setTimeout(r, ms));
            // تمريرٌ كامل لتحميل الصور الكسولة وتشغيل الظهور
            for (let y = 0; y < document.body.scrollHeight; y += 400) {
              window.scrollTo(0, y); await sleep(40);
            }
            await sleep(250);

            const out = { issues: [] };
            out.hScroll = document.documentElement.scrollWidth > window.innerWidth + 1;
            if (out.hScroll) out.issues.push(`تمرير أفقي (${document.documentElement.scrollWidth} > ${window.innerWidth})`);

            // مفاتيح ترجمة فارغة
            const empty = [...document.querySelectorAll('[data-i18n]')]
              .filter(e => !e.textContent.trim() && !e.querySelector('img'))
              .map(e => e.dataset.i18n);
            if (empty.length) out.issues.push('مفاتيح فارغة: ' + empty.slice(0, 5).join(','));

            // صور لم تُحمَّل / بلا بديل نصّي
            const imgs = [...document.querySelectorAll('img')];
            // «مكسورة» = لها مصدرٌ **وفشل**. أمّا عنصرٌ بلا `src` أصلاً فهو
            // لوحةٌ تُملأ عند الحاجة (عارض المستندات في اللوحة مثلاً) — لا
            // عطب. كان الفاحص يبلّغ عنه بـ«صور مكسورة: » وقائمةٍ فارغة،
            // فيُقرأ عطباً وليس كذلك؛ والإنذار الكاذب يُفقد الثقة بالأداة.
            const broken = imgs
              .filter(i => { const s = i.getAttribute('src'); return s !== null && s !== ''; })
              .filter(i => i.complete && i.naturalWidth === 0)
              .map(i => i.getAttribute('src'));
            if (broken.length) out.issues.push('صور مكسورة: ' + broken.slice(0, 3).join(','));
            const noAlt = imgs.filter(i => !i.hasAttribute('alt')).length;
            if (noAlt) out.issues.push(`${noAlt} صورة بلا alt`);

            // محتوى غير مرئي وهو في الشاشة
            const cand = [...document.querySelectorAll('section *, main *, header *, footer *')]
              .filter(e => ((e.textContent || '').trim().length > 3 || e.tagName === 'IMG') && e.children.length < 4);
            const invis = [];
            for (const el of cand) {
              const r = el.getBoundingClientRect();
              if (!r.width || !r.height) continue;
              el.scrollIntoView({ block: 'center', behavior: 'instant' });
              await sleep(35);
              const s = getComputedStyle(el);
              if (+s.opacity < 0.9 && s.visibility !== 'hidden' && s.display !== 'none') {
                invis.push(`${el.tagName}.${(el.className || '').toString().split(' ')[0]}`);
              }
            }
            if (invis.length) out.issues.push('غير مرئي وهو في الشاشة: ' + invis.slice(0, 5).join(','));

            /* أهداف لمس صغيرة — مع استثناء المعيار نفسه.
             * WCAG 2.5.8 يستثني **الرابط السطري داخل فقرة**: لا يُتوقّع من
             * كلمةٍ موصولة وسط جملةٍ أن تكون ٤٤px، ورفع ارتفاعها يفكّك
             * الفقرة. فيُستثنى ما كان داخل `p`/`li` ولم يكن وحده فيها —
             * وإلا صار الفحص يُنذر على كل مقالٍ في الموقع فيُهمَل. */
            const inlineInText = e => {
              /* قائمةُ وسومٍ ثابتة (p,li,td) كانت تُنذر كذباً على رابطٍ
                 داخل جملةٍ في `div` — وهي حالةٌ شائعة. فالمعيار الآن
                 **الكتلة الأقرب أياً كان وسمها**: إن كان حولها نصٌّ
                 آخر فالرابط سطريّ ومستثنى بنصّ WCAG 2.5.8. */
              const own = (e.textContent || '').trim();
              let par = e.parentElement;
              while (par && par !== document.body) {
                const d = getComputedStyle(par).display;
                if (d !== 'inline' && d !== 'contents') break;
                par = par.parentElement;
              }
              if (!par || par === document.body) return false;
              const txt = (par.textContent || '').trim();
              return txt.length > own.length + 3;   // حوله نصٌّ آخر = سطريّ
            };
            const small = [...document.querySelectorAll('a,button,select,input,[role=button]')]
              .filter(e => { const r = e.getBoundingClientRect();
                return r.width && r.height && (r.height < 40 || r.width < 40) && !inlineInText(e); })
              .map(e => `${e.tagName}«${(e.textContent || '').trim().slice(0, 14)}»`);
            if (small.length) out.issues.push(`${small.length} هدف لمس <40px: ` + small.slice(0, 3).join(','));

            // تباين النصوص
            const px = v => (v.match(/[\d.]+/g) || [0, 0, 0]).slice(0, 3).map(Number);
            /* الخلفية الفعلية لا تُحسب إلا إن كانت **لوناً مصمتاً**.
             * التدرّج والصورة لا يُعطيان لوناً واحداً، فحسابهما يُنتج
             * إنذاراً كاذباً — وأداةٌ تُنذر كذباً تُهمَل يوم تصدق.
             * فتُرجَع null، ويُستثنى العنصر من الحكم ويُعدّ «غير مقيس». */
            const bgOf = el => {
              let n = el;
              while (n && n !== document.documentElement) {
                const s = getComputedStyle(n);
                if (s.backgroundImage && s.backgroundImage !== 'none') return null;
                const c = s.backgroundColor;
                if (c && !/rgba\(0, 0, 0, 0\)|transparent/.test(c)) {
                  const a = (c.match(/[\d.]+/g) || [])[3];
                  if (a !== undefined && +a < 0.9) return null;   // شبه شفاف
                  return px(c);
                }
                n = n.parentElement;
              }
              return [255, 255, 255];
            };
            out.lowContrast = [];
            for (const el of [...document.querySelectorAll('p,h1,h2,h3,li,span,b,a,button')].slice(0, 250)) {
              const t = (el.textContent || '').trim();
              if (!t || el.children.length) continue;
              const r = el.getBoundingClientRect();
              if (!r.width || +getComputedStyle(el).opacity < 0.5) continue;
              const bg = bgOf(el);
              if (!bg) { out.unmeasured = (out.unmeasured || 0) + 1; continue; }
              out.lowContrast.push({ fg: px(getComputedStyle(el).color), bg,
                size: parseFloat(getComputedStyle(el).fontSize),
                weight: getComputedStyle(el).fontWeight, t: t.slice(0, 24) });
            }
            out.docH = document.documentElement.scrollHeight;
            out.nodes = document.querySelectorAll('*').length;
            return out;
          });
        } catch (e) {
          res = { issues: ['تعذّر الفحص: ' + e.message.slice(0, 70)], lowContrast: [] };
        }

        // التباين يُحسب هنا لا في الصفحة (رياضياتٌ أسهل خارجها)
        const bad = (res.lowContrast || []).map(x => {
          const L1 = lum(x.fg), L2 = lum(x.bg);
          x.ratio = ((Math.max(L1, L2) + 0.05) / (Math.min(L1, L2) + 0.05)).toFixed(1);
          x.big = x.size >= 24 || (x.size >= 18.66 && +x.weight >= 700);
          return x;
        }).filter(x => +x.ratio < (x.big ? 3 : 4.5));
        if (bad.length) res.issues.push(`${bad.length} نصّاً بتباين ضعيف: ` +
          bad.slice(0, 3).map(x => `«${x.t}» ${x.ratio}:1`).join(' · '));
        if (errs.length) res.issues.push(...errs.slice(0, 3));

        const label = `${path_} · ${vp.tag}${vp.width} · ${lang}`;
        if (res.issues.length) {
          problems++;
          console.log(`❌ ${label}`);
          res.issues.forEach(i => console.log(`     ${i}`));
        } else {
          console.log(`✅ ${label}  (${(bytes / 1024).toFixed(0)}ك · ${reqs} طلباً · ${res.nodes} عقدة · ${res.docH}px)`);
        }
        if (SHOTS) {
          const n = (path_.replace(/[^\w]/g, '_') || 'root') + `_${vp.width}_${lang}.png`;
          await p.screenshot({ path: `${SHOT_DIR}/${n}`, fullPage: false }).catch(() => {});
        }
        await p.close();
      }
    }
  }
  await b.close();
  console.log(`\n${problems ? '❌' : '✅'} ${checks - problems}/${checks} فحصاً سليماً` +
    (problems ? ` — ${problems} بها مشاكل` : ''));
  process.exit(problems ? 1 : 0);
})();
