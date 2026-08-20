# مواصفة البناء النهائية — «ليلُ المدينة» (الاتجاه ١ مُطعَّماً)
### الصفحة الرئيسية `https://zadgo.co/` — ملف التنفيذ الحرفي
**الملف الهدف:** `/home/user/zadgo2/docs/index.html`
**ملفات جديدة:** `/home/user/zadgo2/docs/home.css` · `/home/user/zadgo2/docs/home.js` · `/home/user/zadgo2/docs/images/noise.svg` (مشروط) · `/home/user/zadgo2/test/web_home_guard_test.dart` · `/home/user/zadgo2/test/web_budget_test.dart` · `/home/user/zadgo2/test/i18n_parity_test.dart`
**فرع التطوير:** الحالي. **لا دفع إلى `copilot/split-customer-app` إلا بأمر صريح (بند أ١/أ٢).**

---

## ٠ — كيف تُقرأ هذه المواصفة

1. كل شيفرة هنا **تُنسخ كما هي** ما لم يُنصّ صراحةً على أنها «تقريبية». القيم مقصودة لا مقترحة.
2. **قيم الهوية لا تُخترع ولا تُعدَّل** (الكحلي الأربعة والذهبي الثلاثة والأبيض) — اعتمدها المالك بعد جولتَي تصحيح.
3. كل بند فيه «**تنبيه بند**» يعني: **لا يُنفَّذ قبل إبلاغ المالك برقم البند ونصّه** (بند ز٢) — والتنفيذ يقع بعد ردّه لا قبله.
4. كل بند فيه «**فحص مُلزِم**» يدخل قائمة المراجعة قبل الدمج، ويُنفَّذ على **جهاز أندرويد متوسط حقيقي** لا على شاشة المطوّر.
5. ترتيب الدفعات في §٩ **مُلزِم**: دفعتان تسبقان أي بكسل جديد، وسببهما مذكور هناك.

---

# ١ — القرار

## ١.١ الفائز

**الاتجاه ١ — «الليل والذهب: نزولٌ في ليل المدينة».**

الحساب من درجات المحكّمين الثلاثة (أثر بصري + صمود تقني + خدمة العمل):

| الاتجاه | الأثر البصري | الصمود التقني | خدمة العمل | المجموع |
|---|---|---|---|---|
| **١ — الليل والذهب** | **٩** | **٩** | ٦ | **٢٤** |
| ٤ — ثلاثة أبواب | ٨ | ٧ | ٧ | ٢٢ |
| ٢ — الفاتورة المكشوفة | ٤ | ٨ | ٩ | ٢١ |
| ٣ — رحلة طلبٍ واحد | ٦ | ٥ | ٥ | ١٦ |

ومحكّمان من ثلاثة سمّياه فائزاً بالنصّ. فوزه ليس بفارق الدرجات وحده بل بنوعها: **هو الوحيد الذي لا ينهار حين تنهار التقنية**. جرّب معيار الزائر السعودي على جوّاله في الواحدة ليلاً: الاتجاه ٢ يعرض عليه وثيقة منظّمة (تُعجب المحكّم لا الجائع)، والاتجاه ٣ يعده بفيلمٍ بعد ثلاث شاشات ويسقط كلّه في فايرفوكس وتحت تقليل الحركة، والاتجاه ٤ لا يُبهر إلا **بعد** أن يضغط. الاتجاه ١ وحده يضع المشهد كاملاً في الشاشة الأولى ويبقى قائماً **بصفر جافاسكربت وصفر جدولٍ زمني**.

والسبب الأعمق: هو الوحيد الذي يملك **نظام ذوقٍ لا حزمة حِيَل**. قاعدة «الذهب مصدر ضوء لا مساحة» قرارٌ واحد يولّد المصابيح والقنديل وموتيف الأفق، ويحلّ في الوقت نفسه مخالفة التباين القائمة (`--gold-dk` على الأبيض = ٢٫١٥:١)، ويقينا قراءة «هنقرستيشن آخر». وهذا بالضبط الفرق بين «موقعٍ جميل» و«علامةٍ محترمة»: النظام يُقرأ احتراماً، واللمسة تُقرأ زينة.

## ١.٢ الاعتراض الوجيه الوحيد — وكيف عولج

عدسة **خدمة العمل** أعطته ٦/١٠ لسببٍ صحيح لا يُتجاهل: أطروحته المركزية («الليل = ذروة طلب العميل») **بصيرةٌ عن جمهورٍ لا نملك له زرّاً** في وضع التجربة. الصفحة اليوم تبيع الانضمام لصاحب مطعم وكابتن، لا وجبةً لعميل.

**لم يُعالَج هذا بالتجاهل بل بثلاثة تعديلات جوهرية على الفائز نفسه:**

1. **إعادة صياغة أطروحة الليل من نداءٍ للعميل إلى حجّةٍ تجارية.** القسم لم يعد يقول «حين تجوع أنت»، بل يقول لصاحب المطعم: *أعلى ساعات مبيعاتك تقع بعد المغرب وبعد منتصف الليل — ونحن نعمل فيها*، وللكابتن: *أعلى ساعات دخلك هي أطول ساعات الليل*. نفس المشهد، نفس الجمال، وجمهورٌ يملك زرّاً.
2. **ترقية «إلى أين يذهب ريالك» من رسمٍ نسبي إلى فاتورةٍ حرفية** (تطعيم من الاتجاه ٢) — وهي المادة التجارية التي غابت عن الفائز.
3. **إسقاط أطروحة الكشيدة عن كتف الهوية**: التوقيع الأثمن في الاتجاه ١ كان مرهوناً بقرار خطٍّ لا نملكه. هنا يُشحن التوقيع بلا Readex ولا HEXP، وترقيتهما دفعةٌ مشروطة منفصلة (§٩ دفعة ٦).

## ١.٣ التطعيمات المُلزِمة — من أين، وأين تظهر

| # | من الاتجاه | ما يُنقل | لماذا | مكانه هنا |
|---|---|---|---|---|
| ط١ | ٤ | **العتبة المتشكّلة**: الأبواب تتمدّد فعلاً بانتقال `grid-template-rows` عند اللمس | يعالج أضعف نقطة في الفائز: إبهارٌ صامت لا يحدث فيه شيء تحت الإصبع | §٧ لمسة ٢ |
| ط٢ | ٤ | **ختم الزاي `<symbol id="zay">` وشبكة الـ٦٠°** | أصلُ هويةٍ **نملكه**؛ الليل يعطينا جوّاً، والزاي تعطينا توقيعاً | §٧ لمسة ٢ + §٤ |
| ط٣ | ٤ | **لا يبدأ كشفٌ من `opacity:0` بل من `.35`** | تأمينٌ بصفر كلفة ضدّ الجدول الخامل/العالق الذي أصاب المشروع مرّتين | §٦ |
| ط٤ | ٤ | **`[popover]` بأساس `display:none` + `@supports selector(:popover-open)`** | لا تبقى قائمةٌ معلّقة مكسورة على iOS الأقدم — وهو منفذ اللغة الذي يحتاجه الكابتن البنغالي | §٣ الترويسة |
| ط٥ | ٤ | **صياغة «من أنت؟»** سطراً فوق صفوف الأبواب **بعد** ادّعاء القيمة لا بدلاً منه | نكسب أمانة السؤال وتمايزه بلا سكربتٍ حاجب ولا localStorage ولا مسار عميلٍ فارغ | §٢ قسم ٢ |
| ط٦ | ٤ | **بندٌ مُلزِم: باب العميل لا يُحذف في وضع التجربة — يتغيّر نصّه فقط** | النصّ اليوم يعد بثلاثة ويعرض بابين: مخالفة و٣ صريحة | §٢ + §١١ بند و٤ |
| ط٧ | ٢ | **«إلى أين يذهب ريالك» فاتورةً حرفية**: حافّتان مسنّنتان، مبالغ `——`، خطّ تدقيق ذهبيّ ينزل بالتمرير | جزيرةٌ باردة صادقة وسط الليل، وصفر رقمٍ يصير وعداً تعاقدياً | §٧ لمسة ٣ |
| ط٨ | ٢ | **الخطّة الطباعية التي تُشحن اليوم بلا استئذان**: Plex `400;700` (−٨٧ ك.ب)، Alexandria `100..900` (صفر بايت)، إخراج Nastaliq/Bengali من الرأس | تحترم القيد المكتوب حرفياً وتوفّر ثلث وزن الصفحة | §٥ |
| ط٩ | ٢ | **انضباط `<bdi>`/`tabular-nums`**، وقاعدة قياس التباين **عند كل نقطة من التدرّج**، وفاصل `.perf` بصفر بايت | ثلاثة أعطاب صامتة يقرأها السعودي إهمالاً | §٤ + §٥ |
| ط١٠ | ٣ | **تدرّج الأشقّاء بإزاحة `animation-range`** (`calc(6% + var(--i)*4%)`) لا بـ`animation-delay` | التأخير الزمني بلا معنى على مقياس تمرير | §٦ |
| ط١١ | ٣ | **الطرد الذهبي على `offset-path`** داخل مرحلة «الطريق» | برهانٌ سرديّ للتتبّع بدل قوله للمرّة الخامسة | §٧ لمسة ٤ |
| ط١٢ | ٣ | **«العبور»** `@view-transition{navigation:auto}` في الرئيسية و`/partner/` و`/join/` + اختبار فرادة الأسماء | أرخص مكسبٍ تحويليّ في اللوحة كلّها | §٩ دفعة ٧ |
| ط١٣ | ١ (داخلي) | **الصوت الطباعي الثالث** Reem Kufi بسقف ثلاثة عناصر | جواب شكوى «الخطوط غير منظّمة» من جذرها: تباينٌ صنفيّ لا وزنيّ | §٥ + §٩ دفعة ٦ (مشروط) |

## ١.٤ ما رُفض من التطعيمات — وسبب الرفض

| المرفوض | من | سبب الرفض |
|---|---|---|
| **المسرح اللاصق ٣٠٠svh (وحتى ١٥٠svh)** | ٣ | `position:sticky` طويل يعطّل زخم التمرير على سفاري iOS، ويطيل الصفحة ٠٫٧ شاشة، ويخاطر بإحساس «الصفحة لا تتقدّم». **البديل المعتمد: الطرد يُقاد بـ`view()` على قسمٍ بارتفاع طبيعي — نكسب اللقطة السردية بصفر تمريرٍ إضافي وصفر لزوجة.** (المحكّم اشترط «≤١٥٠svh»، و٩٠svh تستوفي الشرط بفائض.) |
| **الثلاثة بيوت «استلمنا ← في الطريق ← وصل»** | ٣ | ادّعاء أداءٍ تشغيليّ لخدمة لم توصّل طلباً واحداً — أقرب إلى الرقم التسويقي الممنوع مما يبدو. **البديل: بيوتٌ زمنية لا أدائية** (سحور/إفطار/ما بعد العشاء) وهي حقائق وقتٍ لا ادّعاءات عنّا. |
| **سكربت الدور الحاجب في `<head>` + `localStorage`** | ٤ | سكربت حاجب = TBT ثم INP على أندرويد المتوسط، و«الصفحة تعرفني» عند العائد. **البديل: العتبة تتمدّد بصرياً بلا حفظ حالة** — نكسب اللحظة تحت الإصبع بلا تخصيصٍ يصير حبساً. |
| **إعادة ترتيب DOM بـ`startViewTransition`** | ٤ | مكسبٌ يخصّ وضعاً مؤقّتاً بكلفة هندسية عالية، ويطلب محتوى مسار عميلٍ لا نملكه. |
| **هجرة خطّ النصّ إلى Readex Pro** | ١ | القيد يسمّي IBM Plex صراحةً، والمالك شكا مرّتين. **مؤجّلة إلى دفعة مشروطة بلقطتين متقابلتين.** |
| **لمسة الكشيدة (محور HEXP)** | ١ | لا وجود للمحور في Plex؛ تسقط بسقوط قرار الخطّ. **بديلها الجاهز: تدرّج ذهبي على مستوى الكلمة** (وحدة تشكيلٍ آمنة). |
| **استضافة الخطوط ذاتياً** | كشف الأداء | يحتاج تعديل CSP (`font-src 'self'`) — بندٌ أمنيّ يستحق قرار مالك، والميزانية تُحقَّق بدونه. |
| **`prerender` في Speculation Rules** | كشف أحدث-الويب | ينفّذ الصفحة في تبويبٍ خفيّ فتُحتسب زيارةً وهمية. **prefetch بـ`eagerness:"moderate"` وحده.** |

---

# ٢ — بنية الصفحة النهائية

## ٢.١ المبدأ الحاكم للترتيب

> **كل قسمٍ داكن يحمل نداءً، وكل قسمٍ فاتح يحمل دليلاً — وبينهما «الأفق الذهبي» دائماً.**

والإيقاع الحالي عشوائي (داكن×٣ ← فاتح×٢ ← داكن ← فاتح ← **داكن×٤ = ٢٫٥ شاشة كحلية متّصلة في الذيل**)، والذيل هو بالضبط حيث يُتخذ قرار «انضمّ» — أي أضعف مكانٍ بصرياً في الصفحة. الترتيب الجديد ينهي ذلك.

## ٢.٢ الجدول الحاكم

| # | القسم | الحالة | الأرضية | الحشو الرأسي | سقف الارتفاع على 360×740 | السبب |
|---|---|---|---|---|---|---|
| ٠ | **الترويسة** — خطٌّ في الليل | يبقى، يُعاد بناؤه | `--n900` مصمتة | 10px | 56px (لاصقة) | الفيض المقيس ≈٣٦٩px داخل ٣٦٠ يقصّ زرّ التحويل الوحيد اليوم |
| ١ | **البطل** — السماء | يُعاد بناؤه | `--n900` + سماء مرسومة | `clamp(64px,11vh,120px)` / `clamp(72px,12vh,128px)` | **620px** (`min-height:82svh`) | ادّعاء قيمةٍ واحد + مؤهِّل عمليّ واحد + قرارٌ واحد |
| ٢ | **الأبواب الثلاثة** — مستوى الشارع | يترقّى ويُعاد بناؤه | `--n800` | 28px / 40px | **590px** | أذكى فكرة استراتيجية في الملف، مدفونةٌ اليوم في الشاشة الثانية |
| ٣ | **من مطبخ أوّل شركائنا** — الجزيرة المضيئة | **يستبدل** شريط الأطباق التسعة | `--paper` | 56px | **490px** | ينهي التناقض الأخلاقي، ويعالج الاعتراض الوحيد الوجيه على الداكن |
| ٤ | **نعمل حين تعمل المدينة** — الليل والطريق | **جديد** | `--n900` + طريق مرسوم | 56px / 64px | **640px** (`min-height:88svh`) | أطروحة الاتجاه + برهان التتبّع، مصاغةً لجمهورٍ يملك زرّاً |
| ٥ | **إلى أين يذهب ريالك** — الفاتورة المكشوفة | **جديد** | `--paper` | 64px | **600px** | يحوّل بند د١ من التزامٍ داخلي إلى مادة تسويق |
| ٦ | **لأصحاب المطاعم** | يبقى، يُعاد تصفيفه | `--n800`→`--n900` | **96px** | **620px** | نصف التحويل الأول — يستحقّ ضِعف الفراغ |
| ٧ | **للكباتن** — بلغتك | يبقى، ينتقل إلى الورق | `--mist` | **96px** | **700px** | نصف التحويل الثاني، وثلاث فجوات سوقية صافية في مكانٍ واحد |
| ٨ | **التذييل** — والأدلة مدموجة فيه | يُدمج | `--n900` | 36px / 44px | **400px** | إنهاء الصفحة بلا قسمٍ تاسع، وتقصير الذيل الكحلي |

**المجموع المقيس المستهدف: ٤٬٦٦٠px ≈ ٦٫٣ شاشة** (اليوم ٧٫٢). **السقف الصارم: ٦٫٥ شاشة.** يُقاس فعلياً بأداة المطوّر على 360×740 قبل الدمج، ولا يُخمَّن.

**الإيقاع الناتج:** داكن، داكن، **فاتح**، داكن، **فاتح**، داكن، **فاتح**، داكن.
القسمان ١ و٢ داكنان متتاليان **عمداً**: هما مشهدٌ واحد ينزل من السماء إلى الشارع، فلا يُقطع بينهما بأفق — بل بتدرّج نغميّ (`--n900` ← `--n800`) وخيطٍ ذهبيٍّ رفيع. **ما عدا ذلك: كل انتقال داكن↔فاتح يحمل «الأفق الذهبي» بلا استثناء.**

## ٢.٣ ما يُحذف — وبرهان كل حذف

| المحذوف | البرهان | المكسب |
|---|---|---|
| **شريط الأطباق التسعة** (`#taste`) | يعرض رامن وكيمتشي ونودلز وديم سَم تحت عنوان «من مطابخ **مدينتك**»، ثم يَعِد القسم التالي بـ«صور حقيقية من مطابخ شركائنا». تناقضٌ يكذّبه القارئ في ثانية، وأوقع أثراً من رقمٍ وهمي. وتسع تسميات عربية بلا `data-i18n` في موقعٍ بخمس لغات. | **−٤٥٨ ك.ب**، −٩ نصوص عربية ثابتة، −٠٫٨ شاشة |
| **قسم «اطلب بثلاث خطوات»** (`#why`) | يبيع طلباً لا زرّ له في وضع التجربة، ونصّه يدعو إلى «تصفّحٍ» لا مدخل له. وأرقامه ١ ٢ ٣ عند **١٫٢٩:١** وهي الترقيم الوحيد (لا `<ol>` ولا نصّ بديل). | −٠٫٧ شاشة، −مخالفة تباين |
| **قسم «العميل أولاً»** (`#values`) | `v1` = `.honest` + `chip1` حرفياً، `v3` = `chip3` + `f2` + `s2`. و`v2` (صدق الصورة) هو الادّعاء الذي تكذّبه الصور فوقه. | **−١٠٥ ك.ب** (`bg-dining.jpg`)، −٠٫٧ شاشة. `v2` ينتقل إلى القسم ٣ حيث يصدق |
| **الشرائح الزجاجية الثلاث + شريط الثقة** | `f2.t`/`f2.d` و`f1.d` و`f4.d` — **نفس مفاتيح i18n** مرسومةً مرّتين في نفس الصفحة. أي تعديل نصّي مستقبلي يظهر مرّتين. | −٠٫٥ شاشة، −٥ عقد بطاقات |
| **أربع من البطاقات الست** (`f1,f2,f4,f6`) | إعادة طباعة بايت-ببايت لما سبق. **يبقى**: `f3` (الكوبونات) ينتقل إلى قسم الفاتورة، و`f5` (السعرات) ينتقل إلى قسم المطبخ. | −٠٫٤ شاشة، صفر خسارة معلوماتية |
| **شارة `.pill`** | أعلى صوتٍ في الصفحة (لون + حركة + موضع) ورسالتها «لسنا مفتوحين»؛ وتحمل في وضع التجربة ٥٣ حرفاً داخل `border-radius:999px` فتلتفّ سطرين وتصير حبّةً بارتفاع ٦٠px والنقطة النابضة معلّقة في وسطها. | −أسوأ عنصر مصفوف في الصفحة، −حركة دائمة على `box-shadow` |
| **قسم الأدلة المستقل** | يُدمج في التذييل — الذيل الكحلي المتّصل ينزل من ٢٫٥ شاشة إلى ١٫١ | −٠٫٣ شاشة |
| **زرّ «تطبيق المطعم» من الترويسة** | ينتقل إلى قسم المطاعم حيث ينتمي — الترويسة تحمل نداءً واحداً لا ثلاثة | −٦٥px من عرض الترويسة |
| **`drift 28s infinite` و`will-change` الدائم و`backdrop-filter` على الترويسة و`animation:p` على `.dot`** | ثلاث حركات دائمة هي كل كلفة الحركة تقريباً؛ و`backdrop-filter` يُعيد التضبيب كل إطار لأن ما خلفه متحرّك. | −استنزاف بطارية ملموس، −تلعثم أول تمرير |

## ٢.٤ تفصيل الأقسام الجديدة والمعدَّلة

### القسم ٢ — الأبواب الثلاثة (مستوى الشارع)

- **العنوان:** `<h2>` «ادخل من <span class="kufi">بابك</span>».
- **السطر التمهيدي (تطعيم ط٥):** «زادقو منصّةٌ لثلاثة: من يطلب، ومن يطبخ، ومن يوصّل — اختر بابك.» يقع **بعد** ادّعاء القيمة في البطل لا بدلاً منه، فلا نطلب من الزائر أن يصنّف نفسه قبل أن نعطيه سبباً.
- **الأبواب `<a>` لا `<button>`:** الباب يقود فعلاً إلى `/partner/` و`/join/`، والتمدّد يقع بـ`:focus-within`/`:hover`/`:active` لا بحالةٍ محفوظة. (هذا هو الفرق الجوهري عن الاتجاه ٤: نكسب اللحظة تحت الإصبع بلا سكربت حاجب ولا `localStorage` ولا مسار عميلٍ فارغ.)
- **الترتيب في وضع التجربة:** المطعم أولاً، ثم الكابتن، ثم العميل — لأن الصفحة تبيع الانضمام.
- **باب العميل (بند مُلزِم ط٦):** **لا يُحذف أبداً.** يبقى في مكانه ويتغيّر نصّه عبر مفتاح i18n بديل يُبدَّل في كتلة `TRIAL_MODE` بنفس آلية `hero.note`←`hero.trial` القائمة: `doors.c.d` ← `doors.c.d.trial` («نفتح الطلب للجميع قريباً — وسنعلن هنا أولاً»)، و`doors.go` ← `doors.go.trial` («تعرّف على المنصّة») مع `href="/guide/"`.
- **ختم الزاي:** `<svg class="door-k"><use href="#zay"/></svg>` في زاوية كل باب بـ`opacity:.30`.

### القسم ٤ — «نعمل حين تعمل المدينة» (الليل والطريق)

- **العنوان:** «نعمل حين <span class="kufi">تعمل المدينة</span>».
- **النصّ (صياغة مُلزِمة — بصفر نسبة وصفر رقم):**
  > «أعلى ساعات المطبخ في المدينة ليست الظهر. هي ما بعد المغرب، وما بعد العشاء، وساعات السحور الطويلة. من يوصّل في تلك الساعات يكسب أكثر، ومن يطبخ فيها يبيع أكثر — ونحن مبنيّون لها.»
- **ثلاثة بيوت زمنية** (لا أدائية): «قبيل المغرب» / «بعد العشاء» / «١٢ص — ٤ص». تُقاد بالتمرير على المسار المرسوم.
- **الطريق:** SVG مضمَّن بـ`viewBox="0 0 320 620"` يُرسم بـ`stroke-dashoffset`، والطرد الذهبي **داخل نفس الـSVG** فيتجاوب مجّاناً (§٧ لمسة ٤).
- **بند مُلزِم:** لا نسبة، لا مبلغ، لا ادّعاء زمن توصيل، ولا لوحة تقول «وصل».

### القسم ٥ — «إلى أين يذهب ريالك» (الفاتورة المكشوفة)

**بنية الفاتورة مأخوذة من منطق الطلب الفعلي في المستودع لا مخترعة** — طابقها قبل الكتابة مع:
`/home/user/zadgo2/test/order_money_test.dart` و `/home/user/zadgo2/test/vat_test.dart` و `/home/user/zadgo2/test/delivery_fee_test.dart`.

المستخلص الموثَّق:
- `itemsTotal` = مجموع (سعر × كمية) → **الوجبات**
- `deliveryFee` = `driverShare + appShare` **في سطرٍ واحد** (بند ب٢: الرسم الثابت يُعرض داخل سطر التوصيل لا بنداً مستقلاً) → **التوصيل**
- `grandTotal` = وجبات + توصيل ؛ `payableTotal` = الإجمالي − الخصم
- **الأسعار شاملة الضريبة وتُستخرج منها** (`vatIncludedIn`) → **لا سطر ضريبة يُضاف عند الدفع**
- خصم الكوبون **تموّله المنصّة وحدها** (بند ب٥) → لا يمسّ المطعم ولا الكابتن

**فالادّعاء البصري صادقٌ وقابلٌ للإثبات: «فاتورتك ثلاثة بنود وإجمال — ولا بند رابع.»**

جدولان متجاوران (يتراصّان رأسياً تحت 760px):

| جدول «ما تدفعه أنت» | جدول «وأين يذهب» |
|---|---|
| الوجبات `——` | إلى المطعم `——` |
| التوصيل `——` | إلى الكابتن `——` |
| خصم الكوبون `——` | إلى زادقو `——` |
| **الإجمالي** `——` | |

حاشيتان تحت الجدولين:
1. «الأسعار شاملة ضريبة القيمة المضافة — لا سطر يُضاف عند الدفع.»
2. «الخصم تموّله زادقو وحدها؛ لا يُخصم من المطعم ولا من الكابتن.» (نصّ ب٥ حرفاً — و`f3` القديم يذوب هنا.)
3. «لو أُلغي طلبك، يعود إليك ما دفعته.»

**تنبيه بند (ب١):** الوثيقة المُلزِمة تنصّ على أن العمولة **١٥٪ من مبيعات المطعم تُخصم منه، والعميل يدفع سعر الوجبة الحقيقي بلا زيادة**. هذا رقمٌ معتمدٌ داخلياً، **لكن نشره علناً على صفحة تسويقية قرارٌ تجاري لا هندسي** (يراه المنافس، ويصير وعداً تعاقدياً للمطاعم). **النسخة المشحونة: صفر رقم — كل القيم `——`.** والنصّ الجاهز إن أذن المالك، في قسم المطاعم لا في الفاتورة:
> «عمولتنا ١٥٪ من مبيعاتك، تُخصم منك أنت — والعميل يدفع سعر وجبتك كما هو، بلا زيادة.»

### القسم ٧ — للكباتن (على الورق)

- **حاسبة الصافي** (`docs/home.js`): خمسة حقول `<input type="number" inputmode="decimal">` **بلا قيمة افتراضية واحدة** (`value=""`، `placeholder="—"`): ساعات اليوم، عدد التوصيلات، متوسط ما تقاضيته للتوصيلة، وقود اليوم، مصاريف أخرى.
  `صافي = (توصيلات × متوسط) − وقود − أخرى` ؛ `للساعة = صافي ÷ ساعات`.
  المخرَج في `<output aria-live="polite" class="fig">` بـ`tabular-nums` وملفوفٌ في `<bdi>` مع «ر.س».
  **إفصاحٌ ملاصقٌ للنتيجة لا في حاشية:** «هذا حسابٌ من أرقامك أنت. زادقو لا تَعِد بأي مبلغ، ولا يوجد رقمٌ مبرمَج في هذه الحاسبة.»
  **التزامٌ حرفي ببند ج١** (لا رقم مبرمَج للحوافز): صفر ريالٍ لكل طلب، صفر عدد طلبات، صفر نسبة.
- **صفّ اللغات الخمس** بحروفها + المكافئ اللاتيني أصغر تحته (`বাংলা / Bangla`) — فيبقى الزرّ مفهوماً حتى قبل وصول الخطّ. `dir="ltr"` على bn/id داخل صفحة rtl. خطّا البنغالية والأردية يُحقنان عند أول دخول `#riders` مجال الرؤية عبر `IntersectionObserver`.
- **بلا جافاسكربت:** تظهر الحقول والتسميات كاملةً والمخرَج `—`. لا شيء يختفي ولا شيء يكذب.

---

# ٣ — البطل بالتفصيل

## ٣.١ الترويسة (تسبق البطل)

```html
<a class="skip" href="#main" data-i18n="a11y.skip">تخطَّ إلى المحتوى</a>
<header>
  <div class="wrap hrow">
    <a class="logo" href="/" aria-label="ZadGo زادقو">
      <img src="images/zadgo-logo-192.png" alt="ZadGo زادقو" width="192" height="60">
    </a>
    <nav aria-label="أدوات">
      <button class="langbtn" popovertarget="langpop"
              aria-label="اللغة / Language" data-i18n-aria="a11y.lang">
        <svg class="i" aria-hidden="true" width="20" height="20"><use href="#globe"/></svg>
        <span aria-hidden="true">ع</span>
      </button>
      <div id="langpop" popover>
        <button data-lang="ar" dir="rtl">العربية</button>
        <button data-lang="en" dir="ltr">English</button>
        <button data-lang="bn" dir="ltr">বাংলা <small>Bangla</small></button>
        <button data-lang="ur" dir="rtl">اردو <small>Urdu</small></button>
        <button data-lang="id" dir="ltr">Indonesia</button>
      </div>
      <a class="btn gold sm" href="/partner/" data-i18n="nav.partner">ضمّ مطعمك</a>
    </nav>
  </div>
</header>
```

```css
header{position:sticky;top:0;z-index:50;background:var(--n900);
  border-block-end:1px solid var(--line)}           /* بلا backdrop-filter */
.hrow{display:flex;align-items:center;gap:8px;min-block-size:56px}
.logo img{block-size:26px;inline-size:auto}
nav{margin-inline-start:auto;display:flex;align-items:center;gap:8px}
.langbtn{inline-size:44px;block-size:44px;display:grid;place-items:center;
  gap:2px;background:transparent;border:1px solid var(--line);
  border-radius:var(--r-sm);color:#EAF1FD;font-size:.8rem;cursor:pointer}
/* منفذ اللغة — الأساس المخفيّ تماماً حيث لا popover (تطعيم ط٤) */
#langpop{display:none}
@supports selector(:popover-open){ #langpop{display:revert} }
#langpop{margin:0;inset:auto;position:fixed;inset-block-start:60px;
  inset-inline-end:12px;background:var(--n800);border:1px solid var(--line);
  border-radius:var(--r-md);padding:8px;min-inline-size:180px}
#langpop button{display:flex;justify-content:space-between;align-items:baseline;
  gap:10px;inline-size:100%;min-block-size:44px;padding:0 12px;
  background:transparent;border:0;color:#fff;font-size:1rem;border-radius:10px}
#langpop button small{color:#9FB3D4;font-size:.8rem}
```

**حساب العرض عند 360px:** ‏20 (حشو) + 92 (شعار) + 8 + 44 (اللغة) + 8 + ~96 (الزرّ) + 20 = **≈288px < 360**. الفيض ينتهي بالحساب لا بالقصّ.
**فحص مُلزِم:** يُقاس على جهاز 360×740 فعليّ **في اللغات الخمس** — أعرض نصٍّ ليس العربية بالضرورة.
**بديل بلا `popover`:** `home.js` يلتقط ضغطة `.langbtn` (أربعة أسطر) ويمرّرها إلى `document.getElementById('langrow').scrollIntoView()` — صفّ اللغات الخمس في قسم الكباتن. أسوأ حالة: المفتاح ينقلك إلى منفذٍ يعمل. إخفاءٌ لا كسر.

## ٣.٢ البطل — الوسم

```html
<main id="main">
<section class="hero" id="home" aria-labelledby="h-hero">
  <div class="sky"        aria-hidden="true"></div>
  <div class="lamps far"  aria-hidden="true"></div>
  <div class="lamps near" aria-hidden="true"></div>
  <div class="mesh"       aria-hidden="true"></div>
  <picture class="horizon-img" aria-hidden="true">
    <source srcset="images/city-band.avif" type="image/avif">
    <source srcset="images/city-band.webp" type="image/webp">
    <img src="images/city-band.jpg" alt="" width="1440" height="420"
         loading="eager" decoding="async" fetchpriority="low">
  </picture>
  <svg class="zay-seal" aria-hidden="true" viewBox="0 0 40 40"><use href="#zay"/></svg>

  <div class="wrap heroin">
    <p class="eyebrow">
      <span class="lamp" aria-hidden="true"></span>
      <span data-i18n="hero.trial">نجرّب الخدمة الآن مع أوّل شركائنا</span>
    </p>

    <h1 id="h-hero" data-i18n-html="hero.h1">مطاعمك… <span class="kufi gold-word">أقرب لك</span></h1>

    <p class="honest" data-i18n="hero.honest">السعر الذي تراه هو الذي تدفعه.</p>
    <p class="where"  data-i18n="hero.where">نبدأ من حيٍّ واحد في المدينة المنورة، ونتوسّع حيّاً حيّاً.</p>

    <div class="ctas">
      <a class="btn gold sweep" href="/partner/" data-i18n="partners.cta">ضمّ مطعمك</a>
      <a class="btn edge"       href="/join/"    data-i18n="riders.cta">انضم كابتناً</a>
    </div>
  </div>
</section>
```

**قواعد مُلزِمة في البطل:**
1. **عنصر LCP هو `h1` نصّاً** — لذلك `fetchpriority="low"` على صورة الأفق. **يُقاس في Lighthouse ولا يُفترض.**
2. **لا `.pill`** — الحقيقة تُقال في `.eyebrow` بهدوء ولا تُصرَخ.
3. **زرّان فقط**، والذهبي هو الوحيد المصمت في الشاشة.
4. **لا `backdrop-filter`، لا `drift`، ولا `will-change` دائم على أي عنصر** — بما فيه `.lamps` (تصحيحٌ داخلي في الفائز: كان يخالف بنده الخاص).
5. **`decoding="async"` يبقى على صورة الأفق** لأنها ليست عنصر LCP.
6. صورة `city-night.jpg` (٩٤ ك.ب) تُقصّ إلى شريط 1440×420 وتُصدَّر AVIF ≤ **٣٤ ك.ب** + WebP + JPEG احتياطاً.

## ٣.٣ البطل — الطبقات (CSS حقيقي)

```css
.hero{position:relative;isolation:isolate;overflow:clip;color:#fff;
  background:var(--n900);min-block-size:82svh;
  display:grid;align-content:center;
  padding-block:clamp(64px,11vh,120px) clamp(72px,12vh,128px)}

/* ١ — السماء: قبّة ضوء المدينة + وهج الأفق + عمود الليل. صفر بايت. */
.sky{position:absolute;inset:0;z-index:-5;background:
  radial-gradient(120% 78% at 72% -12%, #24407D 0%, rgba(36,64,125,0) 58%),
  radial-gradient(92% 56% at 50% 106%, rgba(255,193,7,.15) 0%, rgba(255,193,7,0) 62%),
  linear-gradient(180deg,#0B1935 0%,#13224A 54%,#0B1935 100%)}

/* ٢ و٣ — حقلا المصابيح: نقاطٌ ذهبية بحجمين وكثافتين = عمقٌ بالمنظور.
   لا will-change: الطبقتان مرتبطتان بجدولٍ زمنيّ يتوقّف تلقائياً، وترقيةُ
   طبقتين بملء البطل ترقيةٌ دائمة تُدفع ولا تُسترد على كرت رسومٍ رخيص. */
.lamps{position:absolute;inset:-10% 0;z-index:-4;pointer-events:none;
  transform:translate3d(0,0,0)}
.lamps.far {opacity:.50;--dy:-3%;
  background-image:radial-gradient(#FFD65A 1px, transparent 1.6px);
  background-size:34px 34px}
.lamps.near{opacity:.30;--dy:-9%;
  background-image:radial-gradient(#FFC107 1.7px, transparent 2.4px);
  background-size:92px 92px}

/* حارس التشريط (banding) على شاشات LCD الرخيصة — أول درجة: تخفيف الكثافة */
@media (max-width:400px){
  .lamps.far {opacity:.40;background-size:40px 40px}
  .lamps.near{opacity:.24;background-size:104px 104px}
}

/* ٤ — شبكة الزاي: زاويتا ±٦٠° (زاوية قلم الخط العربي) لا زخرفةٌ منسوخة */
.mesh{position:absolute;inset:0;z-index:-3;pointer-events:none;opacity:.9;
  background-image:
    repeating-linear-gradient( 60deg, rgba(255,255,255,.05) 0 1px, transparent 1px 46px),
    repeating-linear-gradient(-60deg, rgba(255,255,255,.05) 0 1px, transparent 1px 46px);
  -webkit-mask-image:linear-gradient(to bottom,#000 0%,transparent 62%);
          mask-image:linear-gradient(to bottom,#000 0%,transparent 62%)}

/* ٥ — الأفق المصوَّر: شريطٌ لا خلفية. الصورة تذوب في السماء المرسومة. */
.horizon-img{position:absolute;inset-inline:0;bottom:0;z-index:-2;block-size:42%;
  -webkit-mask-image:linear-gradient(180deg,transparent 0,#000 52%,#000 100%);
          mask-image:linear-gradient(180deg,transparent 0,#000 52%,#000 100%)}
.horizon-img img{inline-size:100%;block-size:100%;object-fit:cover;
  object-position:50% 62%;filter:saturate(.66) brightness(.62) contrast(1.04)}

/* ٦ — حجاب القاع: يضمن 4.5:1 للنصّ فوق أي بكسل من الصورة. */
.hero::after{content:'';position:absolute;inset-inline:0;bottom:0;
  block-size:48%;z-index:-1;pointer-events:none;
  background:linear-gradient(180deg,rgba(11,25,53,0),rgba(11,25,53,.88) 66%,#0B1935 100%)}

/* ٧ — ختم الزاي */
.zay-seal{position:absolute;inset-block-start:calc(56px + 16px);inset-inline-end:16px;
  inline-size:88px;block-size:88px;opacity:.16;fill:var(--gold-lt);z-index:-1}
@media (max-width:400px){ .zay-seal{inline-size:62px;block-size:62px;opacity:.13} }
```

## ٣.٤ البطل — النصّ

```css
.heroin{position:relative;z-index:1}

.eyebrow{display:flex;align-items:center;gap:9px;color:#C9D6EE;
  font-size:var(--fs-meta);font-weight:700;margin-block-end:20px}
.eyebrow .lamp{inline-size:8px;block-size:8px;border-radius:50%;
  background:var(--gold);box-shadow:var(--sh-gold);flex:0 0 8px}  /* ظلٌّ ثابت، لا نبض */

h1{font-family:'Alexandria','IBM Plex Sans Arabic',Tahoma,sans-serif;
  font-weight:800;font-size:var(--fs-h1);line-height:1.28;
  word-spacing:.02em;letter-spacing:0;text-wrap:balance;max-inline-size:13ch}

/* الكلمة الذهبية — على الكحلي وحده (10.7:1). ممنوعة على أي أرضية فاتحة. */
.gold-word{display:inline-block;padding-block:.09em;position:relative;
  background:linear-gradient(102deg,#FFD65A 0%,#FFC107 54%,#FFE9A8 100%);
  -webkit-background-clip:text;background-clip:text;color:transparent}
.gold-word::after{content:'';position:absolute;inset-inline:0;bottom:-.16em;
  block-size:.055em;border-radius:99px;
  background:linear-gradient(90deg,var(--gold-dk),var(--gold-lt));
  transform:scaleX(1);transform-origin:right;               /* الأساس = النهاية */
  animation:draw var(--t-draw) 380ms var(--e-glide) backwards}
:root[dir=ltr] .gold-word::after{transform-origin:left}
@keyframes draw{from{transform:scaleX(0)}}

.honest{margin-block-start:20px;font-size:clamp(1.05rem,3.9vw,1.28rem);
  font-weight:700;color:#EAF1FD;line-height:1.7;
  border-inline-start:4px solid var(--gold);padding-inline-start:14px}

.where{margin-block-start:14px;color:#B9C7E2;font-size:1rem;
  line-height:1.8;max-inline-size:28em}

.ctas{display:flex;gap:12px;flex-wrap:wrap;margin-block-start:30px}

.btn{display:inline-flex;align-items:center;justify-content:center;
  min-block-size:48px;padding:0 22px;border-radius:var(--r-pill);
  font-family:'Alexandria',Tahoma,sans-serif;font-weight:700;font-size:1rem;
  transition:transform var(--t-press) var(--e-tap)}
.btn:active{transform:scale(.975)}
.btn.gold{background:linear-gradient(160deg,var(--gold-lt),var(--gold));color:var(--n900)}
.btn.edge{border:1.5px solid rgba(255,255,255,.34);color:#fff}
```

**التباين المقيس في البطل (وعند كل نقطة من التدرّج لا عند طرفيه — تطعيم ط٩):**

| النصّ | على `#0B1935` | على أفتح نقطة `#24407D` |
|---|---|---|
| أبيض `#FFFFFF` | 17.43:1 | 8.6:1 |
| `#EAF1FD` (سطر الصدق) | 15.4:1 | 7.6:1 |
| `#C9D6EE` (الحاجب) | 11.9:1 | 5.9:1 |
| `#B9C7E2` (المؤهِّل) | 9.9:1 | 4.9:1 |
| `#FFC107` (الذهب) | 10.69:1 | 5.3:1 |

ولذلك يُحصر `#24407D` في **قبّة الضوء أعلى اليمين** ولا يُسمح له بالامتداد خلف نصّ.

---

# ٤ — منظومة التصميم

## ٤.١ الجذر الكامل

```css
:root{
  /* ── الهوية (لا تُغيَّر — اعتمدها المالك) ── */
  --n900:#0B1935; --n800:#13224A; --n700:#1A2E5E; --n600:#24407D;
  --gold:#FFC107; --gold-lt:#FFD65A; --gold-dk:#E0A800;
  --paper:#FFFFFF; --mist:#F4F7FC; --ink:#0A1A33;

  /* ── نصٌّ مشتقّ (مقيسٌ لا مقدَّر) ── */
  --on-navy-1:#FFFFFF;   /* عناوين */
  --on-navy-2:#EAF1FD;   /* نصّ بارز */
  --on-navy-3:#C9D6EE;   /* نصّ عادي */
  --on-navy-4:#B9C7E2;   /* حواشٍ — أخفض المسموح */
  --on-paper-1:#0A1A33;  /* 17.9:1 */
  --on-paper-2:#2A3B57;  /* 10.4:1 — نصّ ثانوي */
  --on-paper-3:#4A5C7A;  /*  6.4:1 — أخفض المسموح على الورق */

  /* ── خطوط شعرية ── */
  --line:rgba(255,255,255,.13);   /* على الكحلي */
  --rule-l:#DDE4F0;               /* على الورق */
  --line-l:#E3E9F3;

  /* ── الشبكة والمسافات (أساس 4px) ── */
  --wrap:1060px;
  --gutter:clamp(16px,4vw,28px);
  --s1:4px;  --s2:8px;  --s3:12px; --s4:16px; --s5:20px;
  --s6:24px; --s7:32px; --s8:40px; --s9:56px; --s10:72px; --s11:96px;
  --pad-sec:56px;        /* الأقسام العادية */
  --pad-sell:96px;       /* القسمان البائعان — الفراغ أقوى أداة هرمية بعد الحجم */

  /* ── أنصاف الأقطار ── */
  --r-xs:8px; --r-sm:12px; --r-md:20px; --r-lg:26px; --r-pill:999px;

  /* ── الظلال (ثابتة أبداً — لا تُحرَّك) ── */
  --sh-1:0 2px 8px rgba(6,16,36,.10);
  --sh-2:0 14px 34px rgba(6,16,36,.14);
  --sh-gold:0 0 12px 2px rgba(255,193,7,.55);

  /* ── المنحنيات (ثلاثة لا أكثر) ── */
  --e-glide:cubic-bezier(.22,.9,.28,1);   /* دخولٌ وظهور — ذيلٌ طويل هادئ */
  --e-tap:cubic-bezier(.34,1.2,.64,1);    /* استجابة اللمس — تجاوزٌ ضئيل */
  --e-morph:cubic-bezier(.65,0,.35,1);    /* تشكّل العتبة — تسارع متماثل */
  /* وكل ما يقوده التمرير: linear حصراً — التمرير هو التوقيت */

  /* ── المدد ── */
  --t-press:140ms; --t-micro:240ms; --t-reveal:520ms;
  --t-morph:420ms; --t-draw:850ms;

  /* ── الاتجاه: متغيّر إشارةٍ واحد يُنهي كل استثناءٍ يدوي ── */
  --rtl:1;
}
:root[dir=ltr]{--rtl:-1}
```

**قاعدة الاتجاه المُلزِمة:** لا `translateX` بقيمةٍ حرفية أبداً. كل إزاحة أفقية تُكتب
`transform:translateX(calc(<قيمة> * var(--rtl)))` حيث `<قيمة>` موجبة تعني «نحو جهة بدء القراءة».
وحيثما أمكن تُحرَّك الخصائص المنطقية (`inline-size`, `inset-inline-start`) بدل `scaleX`/`left` — تنعكس مجّاناً وصحيحاً في اللغات الخمس، وأشرطة التقدّم تمتلئ من اليمين بلا استثناء.

## ٤.٢ قاعدة الذهب (تُنهي المخالفة القائمة ٢٫١٥:١)

> **الذهب نصّاً على الكحلي وحده. على الورق: خطٌّ أو حدٌّ أو نقطةٌ أو أيقونة — عنصرٌ زخرفيّ لا نصّ.**
> والتمييز داخل العناوين الفاتحة **بالوزن والحجم** (Alexandria 900 مقابل 700) لا باللون.

هذا يُنهي `h2 span{color:var(--gold-dk)}` (٢٫١٥:١ — يصيب نصف كل عنوانٍ في الأقسام الفاتحة) و`.pcard li::before{color:var(--gold-dk)}` **بلا مساس بأي قيمة لونية اعتمدها المالك درجةً واحدة**.

```css
/* على الورق: التمييز بالوزن + شريطٌ ذهبيّ زخرفيّ تحت الكلمة */
section.light h2 em{font-style:normal;font-weight:900;color:var(--on-paper-1);
  position:relative;display:inline-block}
section.light h2 em::after{content:'';position:absolute;inset-inline:0;
  bottom:-.1em;block-size:.09em;border-radius:99px;background:var(--gold)}
/* على الكحلي: التدرّج الذهبي مسموح */
section.dark h2 em{font-style:normal;background:linear-gradient(100deg,
  var(--gold-lt),var(--gold) 52%,#FFE9A8);
  -webkit-background-clip:text;background-clip:text;color:transparent}
```

## ٤.٣ التركيز — لا قاعدة واحدة في الصفحة اليوم (مخالفة WCAG 2.4.7)

```css
:focus-visible{outline:3px solid var(--gold-lt);outline-offset:3px;
  border-radius:inherit}
.btn.gold:focus-visible{outline-color:var(--n900)}   /* الأصفر على الأصفر لا يُرى */
section.light :focus-visible,.bill :focus-visible{outline-color:var(--n600)}
.skip{position:absolute;inset-inline-start:-9999px;top:0;z-index:99;
  background:var(--gold);color:var(--n900);padding:12px 18px;
  border-end-end-radius:var(--r-sm)}
.skip:focus{inset-inline-start:0}
```

## ٤.٤ فواصل الأقسام — «الأفق الذهبي» لغةً لا استثناء

**الموتيف الحالي `.tear` يُستعمل مرّةً واحدة، ومعه قاعدة CSS ميتة تماماً** (`section.dark .tear path` ولا `.tear` واحد داخل أي `section.dark`). يُستبدل بـ**الأفق الذهبي**: SVG مضمَّن (≈٦٠٠ بايت) يتكرّر عند **كل** انتقال داكن↔فاتح — خطُّ أفقٍ بسماكة 1px يخفت عند الطرفين، تحته وهجٌ شعاعيّ ذهبيّ، وفي جهة القراءة قوسٌ هلاليّ مشتقٌّ من خطّاف الزاي لا منقولٌ من زخرفةٍ جاهزة.

```html
<!-- يُعرَّف مرّةً واحدة أول <body> -->
<svg width="0" height="0" aria-hidden="true" style="position:absolute" focusable="false">
 <defs>
  <symbol id="horizon" viewBox="0 0 1200 40" preserveAspectRatio="none">
    <ellipse cx="600" cy="20" rx="430" ry="17" fill="currentColor" opacity=".10"/>
    <rect x="60" y="19.5" width="1080" height="1" fill="currentColor" opacity=".55"/>
    <path d="M1112 6a15 15 0 1 0 0 30 12 12 0 1 1 0-30Z" fill="currentColor" opacity=".85"/>
  </symbol>
  <symbol id="zay" viewBox="0 0 40 40">
    <path d="M7 27h19.5L34 14" fill="none" stroke="currentColor" stroke-width="3.4"
          stroke-linecap="square"/>
    <rect x="17.2" y="7.2" width="5.4" height="5.4" fill="currentColor"
          transform="rotate(60 19.9 9.9)"/>
  </symbol>
  <symbol id="globe" viewBox="0 0 24 24"><!-- كرة أرضية بخطّين، fill:none stroke:currentColor -->
    <circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="1.8"/>
    <path d="M3 12h18M12 3c3 3.5 3 14.5 0 18M12 3c-3 3.5-3 14.5 0 18"
          fill="none" stroke="currentColor" stroke-width="1.8"/>
  </symbol>
 </defs>
</svg>

<!-- ويُستدعى عند كل انتقال -->
<svg class="horizon" aria-hidden="true" viewBox="0 0 1200 40" preserveAspectRatio="none">
  <use href="#horizon"/></svg>
```

```css
.horizon{display:block;inline-size:100%;block-size:26px;margin-block-end:-1px}
section.dark + .horizon,.horizon.on-dark{color:var(--gold)}   /* fill:currentColor */
section.light + .horizon,.horizon.on-light{color:var(--gold-dk)}
:root[dir=ltr] .horizon{transform:scaleX(-1)}  /* الهلال يتبع جهة القراءة */
```

**فاصلٌ ثانوي بصفر بايت** (تطعيم ط٩) — خطّ القصّ داخل الأقسام:
```css
.perf{block-size:1px;inline-size:100%;border:0;
  background:repeating-linear-gradient(90deg,
    var(--rule-l) 0 6px, transparent 6px 12px)}
section.dark .perf{background:repeating-linear-gradient(90deg,
    rgba(255,255,255,.34) 0 6px, transparent 6px 12px)}
```

## ٤.٥ الشبكة والفراغ

```css
.wrap{max-inline-size:var(--wrap);margin-inline:auto;padding-inline:var(--gutter)}
section{padding-block:var(--pad-sec)}
#partners,#riders{padding-block:var(--pad-sell)}   /* القسمان البائعان — ضعف الفراغ */
.grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:var(--gutter)}
@media (min-width:760px){ .grid{grid-template-columns:repeat(12,minmax(0,1fr))} }
@supports (grid-template-rows: subgrid){
  .card-3 > *{display:grid;grid-template-rows:subgrid;grid-row:span 3}
}
```
**قاعدة التمايز:** التمايز بين الأقسام يأتي من **الشكل** (صفٌّ مسطَّر / جدول / شبكة صور / قائمة تحريرية) لا من نصٍّ داخل نفس الصندوق الشفاف. الصفحة اليوم تكرّر بطاقةً شفافة بأربع درجات (٥٪، ٦٪، ٧٪، ٩٪) — فرقٌ لا تراه العين، وهو سبب إحساس «الصفحة كتلة واحدة».

## ٤.٦ الانضباط الهندسي — رأس مال يُنقل حرفياً ولا يُعاد اجتهاده

1. **صفر خاصية فيزيائية** في الملف كلّه: لا `left/right/padding-left/margin-right`. كل شيء `inset-inline`/`margin-inline`/`border-inline`/`padding-inline`. (الانضباط الحالي ممتاز والثغرة الوحيدة محرفا `‹ ›` المكتوبان يدوياً — يُستبدلان بـSVG يُقلب بـ`scaleX(var(--rtl))`، و`aria-label` يُترجَم بـ`data-i18n-aria`.)
2. **`overflow-x:clip` لا `hidden`** مع بديل `@supports` — لأن `hidden` يجعل العنصر حاوية تمرير فيفسد مرجع قياس `view()`.
3. **التعليقات تشرح البديل المرفوض وسببه** — وهي التي مكّنت الفحص الذي بُنيت عليه هذه المواصفة.

---

# ٥ — منظومة الطباعة

## ٥.١ الطلب (النسخة المشحونة — بلا استئذان)

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Alexandria:wght@100..900&family=IBM+Plex+Sans+Arabic:wght@400;700&display=swap">
```

**ثلاثة تغييرات في سطر واحد:**

| التغيير | القياس | المكسب |
|---|---|---|
| `Alexandria:wght@500;700;800;900` ← `wght@100..900` | الأوزان الأربعة تشير أصلاً إلى **نفس الملف بنفس الحجم (٣٠ ك.ب)** لأن Alexandria متغيّر، لكن Google تعلن كل وجهٍ عند وزنٍ منفصل فيقفل المتصفّح المحور | **صفر بايت**، ويفتح ٨٠٠ درجة وزنٍ مدفوعة الثمن ومهدرة |
| `IBM Plex Sans Arabic:wght@400;500;600;700` ← `wght@400;700` | العائلة **ثابتة الأوزان** (طلب المدى المتغيّر يردّ 400 Bad Request)، فكل وزنٍ ملفٌّ كامل: أربعة = ١٧٣ ك.ب، اثنان ≈ ٨٥ ك.ب | **−٨٧ ك.ب** |
| حذف `Noto Sans Bengali` و`Noto Nastaliq Urdu` من الرأس | النستعليق وحده ٢٣٣ ك.ب في طلبٍ حاجب لكل زائرٍ عربي؛ ويُحقنان عند اختيار اللغة كما توثّق سياسة `docs/lang.js` نصّاً — **والرئيسية هي الصفحة الوحيدة المخالفة لسياسةٍ كتبها المشروع لنفسه** | **−٢٩٠ ك.ب** للزائر العربي |

**الحصيلة: ١٣ وجهاً ← ٣ ملفات، و≈٣٠٠ ك.ب ← ≈١١٥ ك.ب.**

**قاعدة مُلزِمة بعد التقليص:** لا يحمل أي عنصر بخطّ النصّ (Plex) وزناً غير **400** أو **700**. كل وزنٍ آخر (300، 800، 900) مقصورٌ على عناصر Alexandria. الملف الحالي فيه `font-weight:600` واحد و`800` على `.door em` (وهو بخطّ النصّ) — يُصحَّحان.

## ٥.٢ الصوت الثالث — Reem Kufi (دفعة مشروطة، §٩ دفعة ٦)

**تنبيه بند:** القيود تنصّ على خطّين: «Alexandria للعناوين، IBM Plex Sans Arabic للنصّ». إضافة **Reem Kufi** صوتاً ثالثاً **إضافةٌ لا استبدال** (لا تمسّ خطّ النصّ)، لكنها تغييرٌ في الطباعة يجب إبلاغ المالك به **قبل** التنفيذ (بند ز٢)، مع لقطتين متقابلتين للبطل نفسه.

**لماذا هو جواب شكوى «الخطوط غير منظّمة» من جذرها:** العلّة ليست شكل الخط بل **انعدام التباين الصنفي**. Alexandria وIBM Plex كلاهما ساكنٌ هندسيّ أحاديّ التباين، بنيتهما العربية متقاربة في العرض ودرجة الانفتاح — فالفرق بينهما **وزنٌ لا صوت**، والعين لا تقرأ هرميةً من درجتَي وزن. العلاج إدخال صنفٍ حضاريّ ثالث مختلف بنيوياً (كوفيٌّ هندسيّ مبنيّ على خطّ الجزم)، لا ضبطٌ ثالث للتباعد.

```html
&family=Reem+Kufi:wght@400..700    <!-- ١٢ ك.ب -->
```
```css
.kufi{font-family:'Reem Kufi','Alexandria',serif;font-weight:600;word-spacing:.02em}
/* تغطيته اللاتينية محدودة — يُقصر على العربية والأردية، ويسقط بلا كسر في en/bn/id */
body.lang-en .kufi, body.lang-bn .kufi, body.lang-id .kufi{font-family:'Alexandria',sans-serif}
```
**سقف مُلزِم: ثلاثة عناصر في الصفحة كلّها** (الكلمة الذهبية في `h1`، وكلمتان في عنوانَي القسمين البائعين). وإلا صارت الصفحة معرضاً للخطوط لا موقعاً.

**البديل إن رُفض:** التمييز بالوزن (Alexandria 900) + الشريط الذهبي الزخرفي. لا تسقط لمسةٌ واحدة من §٧ بسقوطه.

## ٥.٣ السلّم — الأرقام الحالية معكوسة (النصّ فضفاض فوق السقف، والعناوين أفدح)

```css
:root{
  --fs-h1:clamp(2.05rem,8.2vw,3.6rem);
  --fs-h2:clamp(1.55rem,5.4vw,2.25rem);
  --fs-h3:clamp(1.05rem,3.6vw,1.2rem);
  --fs-lead:clamp(1rem,3.4vw,1.12rem);
  --fs-body:1rem;
  --fs-meta:.95rem;                    /* ← الأرضية المطلقة */
  --fs-fig:clamp(1.6rem,7vw,2.6rem);   /* مخرَج الحاسبة */
}

body{font-size:16px;line-height:1.75;word-spacing:.045em;letter-spacing:0;
  font-family:'IBM Plex Sans Arabic','Noto Naskh Arabic',Tahoma,sans-serif;
  font-weight:400;-webkit-text-size-adjust:100%}
body.lang-ar{font-size:17px}   /* المحرف العربي يبدو أصغر بالمقاس نفسه */

h1{line-height:1.28;word-spacing:.02em}
h2{line-height:1.34;font-size:var(--fs-h2);font-weight:700}
h3{line-height:1.42;font-size:var(--fs-h3);font-weight:700}
.lead,.honest{line-height:1.85;font-size:var(--fs-lead);max-inline-size:34ch}
p,li{line-height:1.75}
h1,h2,h3{letter-spacing:0;text-wrap:balance}
p,li,figcaption{text-wrap:pretty}
body.lang-ur h1,body.lang-ur h2{line-height:1.9}
body.lang-ur p,body.lang-ur li{line-height:2.3}   /* النستعليق يحتاجها فعلاً */
```

| القيمة | اليوم | الجديد | السبب |
|---|---|---|---|
| `body` line-height | 1.9 | **1.75** | المعيار العربي 1.7–1.85؛ 1.9 فوق السقف |
| `h1` line-height | 1.42 | **1.28** | عند 3.35rem كانت الفجوة ٤٫٧٥rem بين سطرَي العنوان الواحد — فيتفكّك العنوان إلى سطورٍ منفصلة لا كتلةٍ واحدة، **وهذا بالضبط إحساس «غير منظّمة»** |
| `h2` line-height | 1.5 | **1.34** | المعيار 1.3–1.4 |
| `.lead` line-height | 1.95 | **1.85** | |
| `word-spacing` | غائب | **.045em / .02em** | التباعد الحرفي ممنوع في العربية (يكسر الوصل)، **والتباعد بين الكلمات مسموحٌ ومهمَل** — رافعة إيقاعٍ بصفر بايت وصفر مخاطرة |

**لا قيمة `font-size` تحت `.95rem` في الصفحة كلّها** (٠٫٩٥ × ١٧px = ١٦٫١px فعلياً في العربية). الحواشي والتذييل أول المتّهمين وأول ما يُفحص (اليوم `.8rem` = ١٢٫٨px).

## ٥.٤ ممنوعاتٌ عربية مُلزِمة

- لا `letter-spacing` موجب ولا سالب على أي عنصر عربي — يكسر الوصل والليغاتورات.
- لا `text-align:justify` — المتصفّحات لا تدعم الكشيدة (الطلب مفتوح في WebKit منذ ٢٠٠٥) فتمطّ المسافات بين الكلمات فجواتٍ قبيحة على ٣٦٠px. **`text-align:start` دائماً.**
- لا `hyphens:auto` على `:lang(ar)` ولا `:lang(ur)` — لا قاموس فصلٍ عربياً في أي محرّك، والعربية لا تُقطع بشرطة. ونفس القرار للبنغالية.
- لا تشكيل في نصٍّ حيّ بالخطوط الهندسية (جداول GPOS ضعيفة، العلامات تصطدم بالنقاط). وإن أُريدت عبارةٌ مشكَّلة فمساراتُ SVG مضمَّنة في HTML (٣–٦ ك.ب، لا يمسّها `img-src 'self'` لأنها جزء الوثيقة، وتقبل `fill:url(#gold)`).
- **ممنوع منعاً باتّاً تقسيم أي نصٍّ عربي إلى `<span>` لكل محرف، وممنوع أثر الآلة الكاتبة.** كل `<span>` يصير مقطع تشكيلٍ مستقلاً فتظهر الحروف بأشكالها المفردة ثم تتقافز. الوحدة الآمنة هي **الكلمة**، والأداة الآمنة هي `clip-path`.

## ٥.٥ الأرقام وثنائية الاتجاه (تطعيم ط٩)

الأرقام **الغربية (0–9)** هي الصحيحة للسياق الرقمي السعودي — **لا تحويل** إلى ٠١٢٣. والخطر في الاتجاه لا في الشكل: `+966508357833` يُعرض `966508357833+` لأن خوارزمية bidi تنقل علامة الزائد، ومثله `10:30 م` و`3–5 كم`. ولا يوجد في الصفحة اليوم `<bdi>` واحد ولا `unicode-bidi:isolate`.

```css
.fig,output,.bill td,.num{font-variant-numeric:tabular-nums lining-nums;
  unicode-bidi:isolate}
```
- كل رقمٍ ذي علامة أو فاصل يُلفّ في `<bdi>` — عنصر HTML أصيل، صفر CSS، صفر بايت تقريباً.
- كل رقمٍ يتغيّر (مخرَج الحاسبة) يأخذ `tabular-nums` كي لا يرتجف عرضه إطاراً بعد إطار.
- المواضع الحرجة يدوياً: `<span dir="ltr">+966 50 835 7833</span>`.

## ٥.٦ الاحتياط ضدّ CLS

```css
/* احتياطيٌّ محليّ بمقاييس Plex — أخطر مصدر CLS في صفحة عربية */
@font-face{font-family:'Plex Fallback';src:local('Tahoma');
  size-adjust:96%;ascent-override:96%;descent-override:26%;line-gap-override:0%}
body{font-family:'IBM Plex Sans Arabic','Plex Fallback','Noto Naskh Arabic',Tahoma,sans-serif}
```
**ولا `preload` على عنوان gstatic صريح**: العنوان يحمل رقم إصدار تغيّره Google بلا إشعار فيصير تنزيلاً مهدوراً صامتاً. يُكتفى بـ`preconnect` القائم (وهو صحيحٌ مع `crossorigin`).

---

# ٦ — منظومة الحركة

## ٦.١ القاعدة الحاكمة (تُكتب بنداً في `binding-rules.md`)

> **«لا تقنية حديثة تُظهر محتوى — كلّها تُحسّن محتوىً ظاهراً. الحالة النهائية هي الأساس.»**
>
> `@supports` يفحص **النحو لا الواقع**: لا يعرف هل الجدول الزمني نشط، ولا هل للحاوية حجم، ولا هل رُسمت الصفحة خلال ٤ ثوانٍ. وفشل هذه الشروط **صامتٌ تماماً** — لا خطأ في الكونسول، لا تحذير، فقط عنصرٌ مفقود.
>
> عملياً: **`opacity:0` لا يُكتب إلا داخل `@keyframes`**، والخطّ تحت الكلمة أساسه `scaleX(1)` مع `animation-fill-mode:backwards`، والضوء المارّ أساسه مركونٌ خارج الصندوق المقصوص. أي جدولٍ زمني خامل أو عالقٍ عند 0% لا يُخفي شيئاً.

**وتشديدٌ من التطعيم ط٤:** حتى داخل `@keyframes`، **لا يبدأ كشفٌ من `opacity:0` بل من `.35`** — فلو تجمّد الجدول عند 0% (الفخّ الذي أصاب المشروع مرّتين) يبقى النصّ **مقروءاً** لا مفقوداً. تأمينٌ بصفر كلفة.

## ٦.٢ الجرد الكامل — ما يتحرّك، بماذا، ومتى

| # | العنصر | المُشغِّل | الخاصية | المدّة/المدى | المنحنى | متزامن |
|---|---|---|---|---|---|---|
| ١ | `.lamps.far` | `scroll(root)` | `transform` | مدى `0 60vh` | linear | الشاشة ١ |
| ٢ | `.lamps.near` | `scroll(root)` | `transform` | مدى `0 60vh` | linear | الشاشة ١ |
| ٣ | `.gold-word::after` | الزمن، مرّة | `transform:scaleX` | 850ms / تأخير 380ms | `--e-glide` | الشاشة ١ |
| ٤ | `.rail i` (امتلاء) | `scroll(root)` | `transform:scaleY` | كامل المستند | linear | دائم، مجّاني |
| ٥ | `.rail u` (رأس القنديل) | `scroll(root)` | `transform:translateY` | كامل المستند | linear | دائم، مجّاني |
| ٦ | `.reveal` | `view()` | `opacity,transform` | `entry calc(6%+var(--i)*4%) cover 34%` | linear | ≤٢ في الرؤية |
| ٧ | `.sweep::after` | `view()` | `transform` | `entry 26% entry 92%` | linear | ١ في الرؤية |
| ٨ | `.bill-audit` | `view()` | `transform:scaleY` | `entry 20% cover 55%` | linear | ١ في الرؤية |
| ٩ | `.road path` (رسم) | `view()` | `stroke-dashoffset` | `entry 15% cover 85%` | linear | ١ في الرؤية |
| ١٠ | `.courier` (الطرد) | `view()` | `offset-distance` | `entry 15% cover 85%` | linear | ١ في الرؤية |
| ١١ | `.door` (التمدّد) | `:hover/:focus-within/:active` | `grid-template-rows` | 420ms | `--e-morph` | ١، عند اللمس |
| ١٢ | الضغط | `:active` | `transform:scale` | 140ms | `--e-tap` | ميتٌ على اللمس |

**الحدّ الأقصى المتزامن فعلياً = ٧** (والسقف المُلزِم ٨، و٤ في الشاشة الأولى).
كل ما هو مقودٌ بـ`view()` **يتوقّف تلقائياً خارج الرؤية** — فلا دورة معالجٍ على عنصرٍ لا يراه أحد.

**ما لا يتحرّك أبداً — بندٌ مكتوب:**
- لا حركة إلا على `transform` / `opacity` / `clip-path` / `offset-distance` / `stroke-dashoffset` / خصائص `@property` مسجَّلة.
- **ممنوع تحريك `box-shadow`** (يُرسم على المعالج لا كرت الرسوم) و`filter:blur()` و`backdrop-filter` و`background-position`. الظلال ثابتة دائماً؛ إن لزم ظلٌّ متغيّر فطبقة `::after` بظلٍّ ثابت تُحرَّك `opacity` لها.
- **لا `will-change` دائم على أي عنصر.** يُوضع قبل الحركة ويُنزع بعدها، وعلى عنصرين لحظياً كحدٍّ أقصى.
- **`grid-template-rows` استثناءٌ واحد مرخَّص** (العتبة) بشروطٍ صارمة في §٧ لمسة ٢.

## ٦.٣ الكشف بالتمرير (تطعيمان ط٣ + ط١٠)

```css
/* الأساس مرئيٌّ كامل — دائماً */
.reveal{opacity:1;transform:none;--i:0}

@supports (animation-timeline: view()){
  .reveal{animation:rise linear both;animation-timeline:view();
    /* التدرّج الزمني للأشقّاء بإزاحة المدى لا بـanimation-delay:
       التأخير الزمني بلا معنى على مقياس تمرير. */
    animation-range:entry calc(6% + var(--i) * 4%) cover 34%}
  @keyframes rise{
    from{opacity:.35;transform:translate3d(0,18px,0)}   /* لا 0 — تأمين ط٣ */
    to  {opacity:1;transform:none}}
}
```
`--i` يُكتب في وسم `style` على العنصر (`style="--i:2"`) — مسموحٌ بـ`style-src 'unsafe-inline'`.
**المدى يبدأ عند `entry 6%` لا `entry 0%`**: العنصر الموجود أصلاً داخل الشاشة عند التحميل يكون تقدّمه فوق الصفر فيُرسم قرب حالته النهائية — وهذا بالضبط ما يمنع التجمّد على أول إطار.
**ممنوع `view(inline)` إطلاقاً** — المحور الأفقي لا يُستعمل مقياساً أبداً (وقد زال سببه بحذف الصفّ الأفقي).

## ٦.٤ الكشف العربي — مسحٌ لا تقطيع

```css
.wipe{display:inline-block;clip-path:inset(0);       /* الأساس = النهاية */
  padding-block:.14em;margin-block:-.14em}           /* تنفّسٌ لنزول ج ح خ ع غ م ه ي */
@media (prefers-reduced-motion:no-preference){
  @supports (animation-timeline: view()){
    .wipe{animation:wipe linear both;animation-timeline:view();
      animation-range:entry 8% cover 26%}
    @keyframes wipe{
      from{clip-path:inset(0 0 0 100%);opacity:.35}
      to  {clip-path:inset(0);opacity:1}}
    /* الاتجاه: تبديل اسم الحركة لا متغيّرٍ لا تقرؤه الـkeyframes
       (لغمٌ وقع فيه اتجاهان: `:root[dir=ltr] .wipe{--from:…}` متغيّرٌ ميت) */
    :root[dir=ltr] .wipe{animation-name:wipe-ltr}
    @keyframes wipe-ltr{
      from{clip-path:inset(0 100% 0 0);opacity:.35}
      to  {clip-path:inset(0);opacity:1}}
  }
}
```
`padding-block:.14em` مع `margin-block` مقابل هو الشرط الذي يمنع القناع من قطع أذيال الحروف العربية — وهو الخطأ الذي يقع فيه كل من ينقل مؤثّر مسحٍ من قالبٍ لاتيني.

## ٦.٥ تفضيل تقليل الحركة — «القفز إلى النهاية» لا «الإلغاء»

**القاعدة الحالية `*{animation:none!important;transition:none!important}` (السطر ٤٩٩) لغمٌ يجب نزعه قبل إضافة أي حركة، لا بعدها.** هي تفي بالحرف اليوم فقط لأن كل أساساتنا مرئية؛ وأول حركة كشفٍ تُضاف تنكسر **هنا قبل أن تنكسر في أي مكانٍ آخر، ولدى فئة المستخدمين الأحوج**. كما أن `!important` على `*` يُبطل انتقالات `<dialog>`/`popover` فتُغلق النوافذ بلا إشارة بصرية.

```css
@media (prefers-reduced-motion:reduce){
  *,*::before,*::after{
    animation-duration:.01ms!important;
    animation-delay:0ms!important;
    animation-iteration-count:1!important;
    transition-duration:.01ms!important;
    transition-delay:0ms!important}
  html,.track{scroll-behavior:auto!important}
  .lamps{animation:none!important;transform:none!important}  /* المنظور نفسه هو المزعج */
  .threshold{transition:none!important}                      /* التشكّل يقع فوراً والنتيجة صحيحة */
  .courier{display:none}                                     /* طردٌ لا يسير يُخفى */
  .rail u{display:none}                                      /* رأس القنديل حركةٌ لا قراءة */
}
```
**ملاحظة دقيقة ومقصودة:** `.rail i` و`.bill-audit` و`.road` مربوطة بمقياس تمرير لا بالزمن، و`animation-duration` **لا أثر له على الجداول الزمنية للتمرير** — فتبقى صحيحةً عاملةً تحت هذه القاعدة بلا استثناء. وهذا هو الفرق الحاسم عن القاعدة القديمة التي كانت تجمّد `.rail i` على `scaleY(0)` فيظهر خيطٌ ذهبيٌّ **فارغ أبداً** — وهي كذبةٌ بصرية كالخيط الممتلئ أبداً تماماً.

**وفي الجافاسكربت:** `const mq = matchMedia('(prefers-reduced-motion:reduce)')` ثم `el.scrollIntoView({behavior: mq.matches ? 'auto' : 'smooth'})` في كل موضع.

---

# ٧ — اللمسات التوقيعية الخمس

## لمسة ١ — السماء المرسومة (بطلٌ ليليّ ثلاثيّ العمق بصفر بايت)

**ما هي:** أربع طبقات z-index سالبة، ثلاثٌ منها بصفر بايت، والرابعة شريط صورة ٣٤ ك.ب. العمق يأتي من **اختلاف سرعة الطبقتين** بجدولٍ زمنيّ للتمرير.

```css
@supports (animation-timeline: scroll()){
  @media (prefers-reduced-motion:no-preference){
    .lamps{animation:drift-y linear both;
      animation-timeline:scroll(root);animation-range:0 60vh}
    @keyframes drift-y{to{transform:translate3d(0,var(--dy),0)}}
  }
}
```
إطارٌ واحد يخدم الطبقتين، وكل طبقة تحمل `--dy` خاصّاً (`-3%` و`-9%`). كلّه `transform` على المُركِّب، وكلّه يتوقّف تلقائياً حين يخرج البطل من الرؤية.

**بديل التدهور:** بلا دعم `scroll()` (فايرفوكس المستقرّ ما زال خلف علم `layout.css.scroll-driven-animations.enabled`) أو تحت `prefers-reduced-motion`: الطبقتان تبقيان في `translate3d(0,0,0)` — أي **سماءٌ ليلية كاملةٌ ساكنة**، لا فراغ ولا كسر. الأساس هو الحالة النهائية بالتعريف: الطبقات مرئيةٌ بلا حركة أصلاً، والحركة **تُنقص** من المشهد لا تبنيه.

**حارس التشريط (banding) — فحص مُلزِم قبل الدمج:**
حقلا المصابيح نقاطٌ 1px و1.7px على تدرّج كحلي، وعلى شاشة أندرويد متوسط رخيصة (6-bit LCD، تدرّج مضغوط) قد يُقرآن **تشويشاً أو تشريطاً** لا عمقاً. **الفرق بين «فخم» و«معطوب» هنا فرق جهازٍ لا فرق تصميم.**
- **الحارس الأول (مشحون سلفاً):** خفض الكثافة والعتامة تحت 400px — في §٣.٣ أعلاه.
- **الحارس الثاني (إن ظهر التشريط على الجهاز الحقيقي):** ملف `/home/user/zadgo2/docs/images/noise.svg` — لوحة `feTurbulence` بمقاس 120×120 ووزن ≤ ٦٠٠ بايت، تُطبَّق:
```css
.sky::after{content:'';position:absolute;inset:0;opacity:.035;
  background-image:url(images/noise.svg);background-size:120px 120px}
```
**يمرّ من `img-src 'self'` لأنه ملفٌّ محليّ — و`data:` URI ممنوعٌ في هذه السياسة فلا يُستعمل.**

## لمسة ٢ — العتبة المتشكّلة وختم الزاي (تطعيمان ط١ + ط٢)

**ما هي:** الأبواب الثلاثة في مستوى الشارع؛ حين يلمس الزائر باباً **يتمدّد فعلاً** وينكمش أخواه — إحساس تطبيقٍ لا موقع، بصفر مكتبة وتحت CSP خانق. وفي زاوية كل باب **ختم الزاي**: حرف ز مجرَّد إلى بنيته الهندسية (ضلعٌ أفقي + خطّاف بزاوية ٦٠° + معيّن النقطة) — أصلُ هويةٍ نملكه، لا تدرّجٌ يملكه الجميع.

```html
<section class="doors" id="doors" aria-labelledby="h-doors">
  <div class="wrap">
    <h2 id="h-doors">ادخل من <em class="kufi">بابك</em></h2>
    <p class="lead" data-i18n="doors.lead">زادقو منصّةٌ لثلاثة: من يطلب، ومن يطبخ، ومن يوصّل — اختر بابك.</p>

    <div class="threshold">
      <a class="door" href="/partner/" style="--tone:#24407D;--accent:#FFC107">
        <img class="door-bg" src="images/p-partner.avif" alt="" width="480" height="640"
             loading="lazy" decoding="async">
        <svg class="door-k" aria-hidden="true" viewBox="0 0 40 40"><use href="#zay"/></svg>
        <h3 class="door-t" data-i18n="doors.r.t">أنا مطعم</h3>
        <p class="door-d" data-i18n="doors.r.d">قائمتك وطلباتك ومستحقاتك بحسابٍ مكشوف.</p>
        <span class="door-go" data-i18n="doors.go">ادخل</span>
      </a>
      <a class="door" href="/join/" style="--tone:#1A2E5E;--accent:#FFD65A"> … أنا كابتن … </a>
      <a class="door" href="/guide/" style="--tone:#13224A;--accent:#E0A800"> … أنا عميل … </a>
    </div>
  </div>
</section>
<svg class="horizon on-dark" aria-hidden="true" viewBox="0 0 1200 40"
     preserveAspectRatio="none"><use href="#horizon"/></svg>
```

```css
.threshold{display:grid;gap:2px;grid-template-rows:repeat(3,1fr);
  min-block-size:46svh;margin-block-start:var(--s6);
  transition:grid-template-rows var(--t-morph) var(--e-morph)}
.threshold:has(.door:nth-child(1):is(:hover,:focus-within,:active)){
  grid-template-rows:1.62fr .69fr .69fr}
.threshold:has(.door:nth-child(2):is(:hover,:focus-within,:active)){
  grid-template-rows:.69fr 1.62fr .69fr}
.threshold:has(.door:nth-child(3):is(:hover,:focus-within,:active)){
  grid-template-rows:.69fr .69fr 1.62fr}

.door{position:relative;overflow:hidden;display:grid;align-content:end;gap:4px;
  padding:14px 16px 16px;background:var(--tone);color:#fff;
  border:1.5px solid transparent;min-block-size:48px}
.door-bg{position:absolute;inset:0;inline-size:100%;block-size:100%;
  object-fit:cover;opacity:.28;filter:saturate(.8);z-index:0}
.door::after{content:'';position:absolute;inset:0;z-index:1;
  background:linear-gradient(to top,var(--tone) 10%,rgba(11,25,53,.35) 62%,transparent)}
.door > *:not(.door-bg){position:relative;z-index:2}
.door-t{font-family:'Alexandria';font-weight:800;
  font-size:clamp(1.2rem,5.6vw,1.7rem);line-height:1.3}
.door-d{font-size:var(--fs-meta);line-height:1.7;color:rgba(255,255,255,.80);
  max-inline-size:32ch}
.door-go{margin-block-start:4px;font-weight:700;font-size:var(--fs-meta);color:var(--accent)}
.door-go::after{content:'';display:inline-block;inline-size:.7em;block-size:.7em;
  margin-inline-start:6px;background:currentColor;
  clip-path:polygon(100% 50%,35% 0,35% 35%,0 35%,0 65%,35% 65%,35% 100%);
  transform:scaleX(var(--rtl))}
.door-k{position:absolute;inset-block-start:10px;inset-inline-end:10px;
  inline-size:26px;block-size:26px;opacity:.30;fill:var(--accent);z-index:2}

@media (min-width:820px){
  .threshold{grid-template-rows:none;grid-template-columns:repeat(3,1fr);
    min-block-size:52svh;transition:grid-template-columns var(--t-morph) var(--e-morph)}
  .threshold:has(.door:nth-child(1):is(:hover,:focus-within,:active)){
    grid-template-columns:1.62fr .69fr .69fr}
  /* …وهكذا للاثنين الآخرين */
}
```

**قيود مُلزِمة على هذه اللمسة** (لأنها الاستثناء الوحيد المرخَّص لتحريك خاصيةٍ تعيد التخطيط):
1. **المدّة ٤٢٠ms لا ٦٢٠** — نصف الفرق الذي جعل هذه الحركة «أثقل حركة في اللوحة» عند الاتجاه ٤.
2. **الارتفاع ٤٦svh لا ٥٨svh** — مساحة إعادة التخطيط أصغر بـ٢١٪.
3. **صور الأبواب `loading="lazy"` وليست في الشاشة الأولى** — فالتمدّد لا يقع أثناء قياس LCP.
4. **فحص مُلزِم:** تُقاس نسبة الإطارات المسقطة أثناء التمدّد على أندرويد متوسط حقيقي بأداة Performance. إن سقطت تحت 50fps، تُخفَّض النسب إلى `1.34fr .83fr .83fr` (تمدّدٌ أقلّ = إعادة تخطيطٍ أقلّ). **ولا تُحذف اللمسة** — هي علاج أضعف نقطة في الاتجاه الفائز.
5. **الباب لا يخفي جملةً واحدة عند الانكماش**: `.door-d` يبقى مقروءاً، ويُقلَّص بحجم الخطّ عبر استعلام حاوية لا بـ`display:none`. أي `display:none` على نصٍّ داخل باب **مرفوضٌ في المراجعة**.

**بديل التدهور:** بلا دعم `:has()` (فايرفوكس ١٢١ آخر من لحق — أي كل متصفّحاتنا) أو بلا استيفاء `grid-template-rows`: النسب تقفز فوراً بدل أن تنساب، أو تبقى `1fr 1fr 1fr` — **ثلاثة أبواب متساوية كاملة الحيوية وكل المحتوى ظاهر**. النتيجة صحيحة والقراءة سليمة، فقط بلا مورف. **ولا يُخفى شيء في أي حال.**
⚠️ **قاعدة `:has()` تُكتب مستقلّة، لا داخل قائمة محدّدات مع محدّدٍ حرج** — المحدّد غير المفهوم يُبطل القاعدة كاملة.

## لمسة ٣ — الفاتورة المكشوفة وخطّ التدقيق (تطعيم ط٧)

**ما هي:** جدولٌ بعرض أقصى 640px وسط بياضٍ واسع، محاطٌ بحافّتين مسنّنتين فيُقرأ إيصالاً ممزّقاً. كل صفّ: اسم البند، ثم خليّة مطّاطية بخطّ ربطٍ منقّط، ثم `——` بـ`tabular-nums`. وخطٌّ ذهبيٌّ ينزل على حافة الجدول بمقدار تمريرك — يدقّقه أمام عينك.

```html
<div class="bill-wrap">
  <div class="bill-edge top" aria-hidden="true"></div>
  <span class="bill-audit" aria-hidden="true"></span>
  <table class="bill">
    <caption class="sr-only">بنية فاتورتك</caption>
    <tbody>
      <tr><th scope="row">الوجبات</th><td class="dot"></td><td class="amt"><bdi>——</bdi></td></tr>
      <tr><th scope="row">التوصيل</th><td class="dot"></td><td class="amt"><bdi>——</bdi></td></tr>
      <tr><th scope="row">خصم الكوبون</th><td class="dot"></td><td class="amt"><bdi>——</bdi></td></tr>
      <tr class="total"><th scope="row">الإجمالي</th><td class="dot"></td><td class="amt"><bdi>——</bdi></td></tr>
    </tbody>
  </table>
  <div class="bill-edge bottom" aria-hidden="true"></div>
</div>
```

```css
.bill-wrap{position:relative;max-inline-size:640px;margin-inline:auto;
  background:var(--paper);padding:26px 22px;box-shadow:var(--sh-1)}
/* الحافّة المسنّنة بتدرّجٍ خالص — لا SVG ولا صورة، فلا يمسّها img-src */
.bill-edge{position:absolute;inset-inline:0;block-size:10px;background:var(--paper);
  -webkit-mask-image:repeating-conic-gradient(#000 0 25%,transparent 0 50%);
          mask-image:repeating-conic-gradient(#000 0 25%,transparent 0 50%);
  -webkit-mask-size:18px 18px;mask-size:18px 18px}
.bill-edge.top{inset-block-start:-9px}
.bill-edge.bottom{inset-block-end:-9px;transform:rotate(180deg)}

.bill{inline-size:100%;border-collapse:collapse;font-size:1rem}
.bill th{text-align:start;font-weight:400;color:var(--on-paper-1);padding-block:11px;
  white-space:nowrap}
.bill td.dot{inline-size:100%;border-block-end:1px dotted var(--rule-l);
  transform:translateY(-.35em)}
.bill td.amt{text-align:end;padding-inline-start:12px;color:var(--on-paper-2);
  font-variant-numeric:tabular-nums lining-nums;unicode-bidi:isolate;white-space:nowrap}
.bill tr.total th,.bill tr.total td{border-block-start:2px solid var(--ink);
  font-weight:700;padding-block-start:13px;color:var(--on-paper-1)}

/* خطّ التدقيق: يختفي حيث لا يُدعم — خطٌّ ممتلئ أبداً كذبةٌ بصرية */
.bill-audit{display:none}
@supports (animation-timeline: view()){
  .bill-audit{display:block;position:absolute;inset-block:18px;
    inset-inline-start:0;inline-size:2px;background:var(--gold);
    transform:scaleY(0);transform-origin:top;
    animation:audit linear both;animation-timeline:view();
    animation-range:entry 20% cover 55%}
  @keyframes audit{to{transform:scaleY(1)}}
}
```

**قيدٌ مُلزِم:** **صفر نسبة وصفر مبلغ في هذا القسم كلّه.** أي رقمٍ يُعرض — حتى بلا مئوية مكتوبة — يصير **وعداً تعاقدياً**. ولا تُعرض نسبة عمولةٍ إلا بموافقة صريحة من المالك مستندةً إلى `/home/user/zadgo2/dev-docs/launch-financial-study.md` وبند ب١.

**بديل التدهور:** الفاتورة والحافّتان والخطوط المنقّطة **ساكنةٌ ومرئيةٌ كاملةً** بلا أي اعتماد على حركة. بلا دعم `mask-image` تظهر الحافّة مستقيمةً نظيفة — الإيصال يبقى إيصالاً. وخطّ التدقيق `display:none` حيث لا مقياس تمرير.

## لمسة ٤ — نزولٌ إلى الطريق (تطعيم ط١١، بربع الجرعة)

**ما هي:** داخل قسم الليل، طريقٌ ذهبيٌّ يُرسم تحت الإصبع، وطردٌ صغير يسير عليه. **بلا مسرحٍ لاصق وبلا 300svh وبلا 150svh** — الطرد يُقاد بـ`view()` على قسمٍ بارتفاعٍ طبيعي، فنكسب البرهان السردي بصفر تمريرٍ إضافي وصفر لزوجة على سفاري iOS.

```html
<div class="road" aria-hidden="true">
  <svg viewBox="0 0 320 620" preserveAspectRatio="xMidYMid meet">
    <path id="rd" class="road-line" pathLength="1" fill="none"
          stroke="url(#rdg)" stroke-width="2.5" stroke-linecap="round"
          d="M40 12 C 150 90, 70 200, 190 290 S 60 460, 250 604"/>
    <defs><linearGradient id="rdg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFD65A"/><stop offset="1" stop-color="#E0A800"/>
    </linearGradient></defs>
    <g class="courier">
      <circle r="9" fill="#0B1935" stroke="#FFC107" stroke-width="2"/>
      <rect x="-4" y="-4" width="8" height="8" rx="1.5" fill="#FFC107"/>
    </g>
  </svg>
</div>
```

```css
.road svg{inline-size:100%;block-size:auto;max-block-size:62svh}
.road-line{stroke-dasharray:1;stroke-dashoffset:0}   /* الأساس: الطريق مرسومٌ كاملاً */
.courier{display:none}

@supports (animation-timeline: view()) and (offset-path: path("M0 0 L1 1")){
 @media (prefers-reduced-motion:no-preference){
  .road-line{stroke-dashoffset:1;
    animation:drawpath linear both;animation-timeline:view();
    animation-range:entry 15% cover 85%}
  @keyframes drawpath{to{stroke-dashoffset:0}}

  .courier{display:block;
    offset-path:path("M40 12 C 150 90, 70 200, 190 290 S 60 460, 250 604");
    offset-rotate:auto;offset-distance:0%;
    animation:travel linear both;animation-timeline:view();
    animation-range:entry 15% cover 85%}
  @keyframes travel{to{offset-distance:100%}}
 }
}
```

**التصحيح الجوهري على الاتجاه ٣:** الطرد **داخل نفس الـSVG** وبنفس نظام إحداثياته (`viewBox="0 0 320 620"`)، فيتجاوب مع كل عرض مجّاناً. الاتجاه ٣ كان يضع `offset-path` بإحداثيات px مثبَّتة بينما الـSVG مطّاطي — فالطرد يطير خارج الخطّ على 320px وعلى 430px وعلى سطح المكتب. **وهذا العطب لم يكن له حلٌّ في مواصفته؛ حُلّ هنا.**
و`pathLength="1"` **سمة SVG لا خاصية CSS** — كتابتها في CSS خطأٌ صامت.

**الحمل في الإطار:** نقطةٌ واحدة (`offset-distance` يُترجَم إلى `transform`) + `stroke-dashoffset` واحد = عنصران.

**بديل التدهور:** الأساس (خارج `@supports`) طريقٌ **مرسومٌ كاملاً وساكن** والطرد مخفيّ. لا فراغ ولا كسر ولا سطرٌ ضائع من المعلومات — النصّ والبيوت الثلاثة كلّها ظاهرة بترتيبها الطبيعي.

## لمسة ٥ — قنديل القراءة (الخيط الذهبي يكتسب رأساً)

**ما هي:** يُحتفظ بـ`.rail` القائم (مؤشّر تقدّمٍ بلا جافاسكربت ولا إطار أداء) ويُضاف له رأسٌ يهبط معك في الليل — فيُقرأ **قنديلاً ينزل** لا شريط تحميل.

```css
.rail{display:none}
@supports (animation-timeline: scroll()){
  .rail{display:block;position:fixed;inset-block:0;inset-inline-start:0;
    inline-size:3px;z-index:60;background:rgba(255,193,7,.13);pointer-events:none}
  .rail i{display:block;inline-size:100%;block-size:100%;transform-origin:top;
    transform:scaleY(0);
    background:linear-gradient(180deg,var(--gold-lt),var(--gold) 55%,var(--gold-dk));
    animation:railfill linear both;animation-timeline:scroll(root)}
  @keyframes railfill{to{transform:scaleY(1)}}

  .rail u{display:block;position:absolute;inset-inline:-4px;block-size:40px;
    inset-block-start:0;
    background:linear-gradient(180deg,transparent,var(--gold-lt),transparent);
    filter:blur(3px);                       /* ثابتٌ لا متحرّك */
    animation:railhead linear both;animation-timeline:scroll(root)}
  @keyframes railhead{to{transform:translateY(calc(100vh - 40px))}}
}
```

**المبدأ الحاكم:** `.rail{display:none}` هو **الأساس**، ولا يظهر إلا داخل `@supports` — فحيث لا يُدعم لا يوجد أصلاً. **خيطٌ ذهبيّ يظهر ممتلئاً أبداً كذبةٌ بصرية، والخيط الفارغ أبداً كذبةٌ مثلها.**
ويبقى عاملاً تحت `prefers-reduced-motion` لأنه **قراءةُ موضعٍ يتبع الإصبع** لا حركةً بمؤقّت — وهذا يعمل صحيحاً **فقط** بنمط «القفز إلى النهاية» في §٦.٥. أما الرأس (`.rail u`) فيُخفى هناك لأنه حركةٌ لا قراءة.

**ولمسةٌ صغيرة مرافقة (ليست توقيعاً):** «الضوء يمرّ» على الزرّ الذهبي —
```css
.sweep{position:relative;overflow:hidden}
.sweep::after{content:'';position:absolute;inset-block:-50%;inline-size:38%;
  background:linear-gradient(100deg,transparent,rgba(255,255,255,.5),transparent);
  transform:translateX(calc(180% * var(--rtl))) rotate(8deg)}  /* مركونٌ خارج الصندوق */
@supports (animation-timeline: view()){
  .sweep::after{animation:sweep linear both;animation-timeline:view();
    animation-range:entry 26% entry 92%}
  @keyframes sweep{to{transform:translateX(calc(-180% * var(--rtl))) rotate(8deg)}}
}
```
لا مؤقّت ولا تكرار: التمرير هو التوقيت، فالكلفة صفر حين لا تتحرّك. وبلا دعم يبقى الشريط مركوناً خارج الصندوق فلا يُرى شيء — زرٌّ ذهبيٌّ عاديّ سليم.

---

# ٨ — ميزانية الأداء

## ٨.١ البايتات (أول زيارة، جوّال، مضغوطة على السلك)

| البند | السقف | الملاحظة |
|---|---|---|
| المستند HTML بما فيه CSS الحرج | **≤ ٣٤ ك.ب** | CSS الشاشة الأولى مضمَّن ≤ ١٤ ك.ب منها |
| `docs/home.css` (مؤجَّل) | **≤ ١٢ ك.ب** | يُحمَّل بـ`media="print" onload="this.media='all'"` |
| `docs/home.js` + `feedback.js` | **≤ ٣٠ ك.ب** | **صفر جافاسكربت حاجب** |
| الخطوط | **≤ ١٣٠ ك.ب** | Alexandria ٣٠ + Plex ٨٥ (+ Reem Kufi ١٢ مشروط) |
| صورة الأفق (LCP-adjacent) | **≤ ٣٤ ك.ب** | AVIF، 1440×420 |
| ٣ صور المطبخ | **≤ ٢٢ ك.ب** لكلٍّ | من `fateer-*.jpg` الحقيقية، مُعاد ترميزها |
| ٣ صور الأبواب | **≤ ١٢ ك.ب** لكلٍّ | `p-partner/p-captain/p-customer` |
| صورة قسم المطاعم | **≤ ٢٦ ك.ب** | `bg-kitchen` مصغَّرة إلى 720px (اليوم 1920×904 بـ١٣١ ك.ب لخانةٍ عرضها ٣٢٠) |
| الشعار | **≤ ٧ ك.ب** | 192×60 PNG بـ`width`/`height` صريحين (اليوم 600×187 بـ٤٤ ك.ب لعرضٍ فعليّ ٨٣) |
| `noise.svg` (مشروط) | **≤ ١ ك.ب** | لا يُضاف إلا إن ظهر تشريط |
| **المجموع** | **هدف ٤١٠ ك.ب · سقف صارم ٤٥٠ ك.ب** | اليوم **٦٦٤ ك.ب** |
| **الشاشة الأولى وحدها** | **≤ ١٠٥ ك.ب** | |

## ٨.٢ الطلبات والبنية والحركة

| المقياس | السقف | اليوم |
|---|---|---|
| الطلبات كلياً | **≤ ١٦** | ١١ (لكن ٣ منها عبر اتصالين خارجيين) |
| الطلبات قبل أول رسم | **≤ ٤** (HTML + CSS الخطوط + ملفّا خطّ) | ٦ |
| عقد DOM | **≤ ٩٠٠** | ٢٧٦ (فسحة واسعة للتصميم الأغنى) |
| طول الصفحة على 360×740 | **≤ ٦٫٥ شاشة** (هدف ٦٫٣) | ٧٫٢ |
| ملفات الخطّ | **≤ ٣** | ٨ |
| عناصر متحرّكة في الإطار الواحد | **≤ ٨** | ٥١ |
| في الشاشة الأولى | **≤ ٤** | — |
| `will-change` لحظياً | **≤ ٢** | دائم على عنصرين |
| `will-change` دائم | **صفر** | ٢ |
| حركة على غير `transform`/`opacity`/`clip-path`/`offset-distance`/`stroke-dashoffset` | **صفر** (استثناء واحد مرخَّص: `grid-template-rows` في العتبة) | `box-shadow`، `backdrop-filter` |

## ٨.٣ المؤشرات

**معملياً** (Lighthouse جوّال، CPU ×٤، 4G بطيء): FCP ≤ ١٫٢s · **LCP ≤ ١٫٨s** · TBT ≤ ١٥٠ms · CLS ≤ ٠٫٠٥ · Speed Index ≤ ٢٫٢s · النتيجة ≥ ٩٥.
**ميدانياً p75:** LCP ≤ ٢٫٠s · INP ≤ ١٥٠ms · CLS ≤ ٠٫٠٥.
الهدف **أشدّ من عتبة جوجل بهامش** لأن جمهور زادقو (أندرويد متوسط) هو بالضبط ذلك الربع البطيء الذي يقرّر النتيجة.

**قيدٌ خاصّ بـGitHub Pages يجب تذكّره:** الخادم يفرض `Cache-Control: max-age=600` على كل ملف ولا سبيل لتغييره — أي أن **كل زيارة تقريباً زيارةٌ أولى**، فحجم الصفحة الكلي هو المقياس الحاكم لا الزيارة المتكرّرة. (Service Worker هو الحلّ الوحيد لهذا، **وهو مؤجَّل عمداً** إلى ما بعد استقرار التصميم: لا شيء أسوأ من تثبيت نسخةٍ تجريبية عند المستخدمين، ويُعامَل دفعةً معزولة ببند أ٦.)

---

# ٩ — قائمة التنفيذ المرتّبة

> **قاعدة الترتيب: دفعتان تسبقان أي بكسل جديد — لأن الميزانية يجب أن تُحقَّق قبل أن يعتاد المالك على شكلٍ أثقل، ولأن لغم `prefers-reduced-motion` ينفجر مع أول حركة كشفٍ تُضاف.**

## دفعة ٠ — نزع اللغم (شرطٌ مسبق مطلق)

| # | العمل | الملف |
|---|---|---|
| ٠٫١ | استبدال `*{animation:none!important;transition:none!important}` بنمط «القفز إلى النهاية» كاملاً من §٦.٥ | `docs/index.html:499` |
| ٠٫٢ | إضافة `html,.track{scroll-behavior:auto!important}` داخل نفس الاستعلام، وتمرير `behavior: mq.matches?'auto':'smooth'` في كل `scrollBy`/`scrollIntoView` | `docs/index.html` |
| ٠٫٣ | إعادة اختبار كل حركةٍ قائمة للتأكّد أن أياً منها لا يعتمد على تكرارٍ لانهائي لبلوغ حالة | — |
| ٠٫٤ | كتابة البنود الجديدة في الوثيقة المُلزِمة (§١١) | `dev-docs/binding-rules.md` |

**معيار القبول:** فتح الصفحة مع تفعيل «تقليل الحركة» في نظام التشغيل — كل نصٍّ وكل بطاقةٍ مرئية، و`.rail` يمتلئ صحيحاً، ولا عنصر مفقود.

## دفعة ١ — الأداء الساكن (بلا أي تغيير في الشكل)

| # | العمل | المكسب |
|---|---|---|
| ١٫١ | سطر الخطوط الجديد من §٥.١ | **−٣٧٧ ك.ب** |
| ١٫٢ | فحص كل ملفات `docs/` (لا `index.html` وحدها) قبل حذف الوزنين 500/600 — `join/` و`partner/` و`app/` و`contact.html` تتشارك الخطوط | يمنع بديلاً غليظاً صامتاً |
| ١٫٣ | حقن خطّي bn/ur عند تبديل اللغة (كما توثّق سياسة `docs/lang.js`) | −٢٩٠ ك.ب للزائر العربي |
| ١٫٤ | `width`/`height` أو `aspect-ratio` على **كل** `<img>` (٩ من ١٥ فقط تحملها اليوم؛ الشعار وصورة المطبخ أخطرها لأنهما يسبّبان قفزة في الترويسة والقسم) | CLS ≈ 0 |
| ١٫٥ | إعادة ترميز الصور: شريط الأفق، ٣ مطبخ، ٣ أبواب، مطاعم، شعار — إلى AVIF + WebP + JPEG عبر `<picture>` | −٢٠٠+ ك.ب |
| ١٫٦ | إخراج كتلتَي الجافاسكربت المضمَّنتين (٢٣ ألف محرف) إلى `/home/user/zadgo2/docs/home.js` بـ`defer` | −أثقل بند على TBT |
| ١٫٧ | `@font-face` الاحتياطي بـ`size-adjust`/`ascent-override` من §٥.٦ | −أخطر مصدر CLS عربي |
| ١٫٨ | بوّابة ميزانية في CI: `/home/user/zadgo2/test/web_budget_test.dart` يجمع أحجام ملفات الصفحة ويُفشل الاختبار فوق السقف | تمنع الميزانية من أن تصير وثيقة نيّات |

**معيار القبول:** Lighthouse جوّال محلي (خادم `python3 -m http.server` على `docs/`) — الصفحة تحت ٤٥٠ ك.ب وLCP تحت ٢s **قبل أن يُرسم بكسل جديد**.

## دفعة ١-ب — تقسيم القاموس (اختيارية الترتيب، واجبة قبل دفعة ٧)

- تقسيم `docs/lang.js` (٧٤ ك.ب لخمس لغات) إلى `lang-ar.js` … `lang-id.js` تُحقن عند التبديل، مع بقاء العربية في الوسم نفسه فلا تُحمَّل.
- نقل الرئيسية من كائن `I18N` المضمَّن (٢٨٬٣٥٣ بايت = ثلث ملف الـHTML) إلى `lang.js` — **ويُنهي خطر تقادم الترجمة الذي حذّر منه تعليق `lang.js` نفسه**.
- حذف عشرة مفاتيح ميتة (`nav.home`, `nav.why`, `nav.values`, `nav.partners`, `nav.riders`, `footer.launch`, `footer.sub`, `footer.soon`, `footer.soon2`, `nav.terms`) × ٥ لغات = **٥٠ سلسلة ميتة**.
- **اختبار مُلزِم:** `/home/user/zadgo2/test/i18n_parity_test.dart` يتحقّق أن مجموعات المفاتيح **متطابقة** في الملفات الخمسة — مفتاحٌ يُضاف للعربية ويُنسى في الأردية يظهر نصّاً خاماً للمستخدم، والخطأ صامتٌ لا يُكتشف إلا من مستخدم.

## دفعة ٢ — الوصولية والتباين (≈١٥ سطراً، بلا أثر على التخطيط)

| # | العمل |
|---|---|
| ٢٫١ | قاعدة `:focus-visible` كاملة من §٤.٣ + رابط التخطّي |
| ٢٫٢ | قاعدة الذهب من §٤.٢ — تُنهي `--gold-dk` على الأبيض (٢٫١٥:١) في ثلاثة عناوين، و`.pcard li::before` |
| ٢٫٣ | `<main>` حول ما بين الترويسة والتذييل، و`aria-labelledby` يربط كل `<section>` بعنوانه (‏`<section>` بلا اسمٍ متاح **لا يُعرَض معلماً أصلاً**) |
| ٢٫٤ | `<b>` ← `<h3>` في كل بطاقة (مع `h3{font-size:var(--fs-h3)}` فلا يتغيّر الشكل) — الصفحة اليوم فيها **صفر `<h3>`** |
| ٢٫٥ | `aria-hidden="true"` على ١٧ إيموجي، وسحب الإيموجيين المدسوسين داخل القاموس (`partners.app`، `say.open`) من `lang.js` إلى الـHTML |
| ٢٫٦ | استبدال الإيموجي كلّه بمنظومة أيقونات SVG مضمَّنة نرسمها بأيدينا — وهي مسموحة تحت CSP بينما Lottie ليست، وهي بالضبط ما كسب به Wolt |
| ٢٫٧ | `<bdi>` حول كل رقمٍ ذي علامة، و`tabular-nums` على كل رقمٍ يتغيّر |
| ٢٫٨ | استبدال محرفَي `‹ ›` بـSVG يُقلب بـ`scaleX(var(--rtl))`، و`data-i18n-aria` على كل `aria-label` |

## دفعة ٣ — البطل والأبواب

- الترويسة الجديدة (§٣.١) + منفذ اللغة `popover`.
- البطل كاملاً (§٣.٢–٣.٤) بأربع طبقاته وختم الزاي وشبكة الـ٦٠°.
- قسم الأبواب بالعتبة المتشكّلة (§٧ لمسة ٢) + مفتاحا i18n الجديدان لباب العميل.
- حذف `.pill` والشرائح الثلاث وشريط الثقة.
- **فحص مُلزِم على أندرويد متوسط حقيقي:** التشريط في السماء، وإطارات التمدّد.
- **بناء يدوي عبر `workflow_dispatch` ومراقبة النتيجة والإبلاغ بها (بند أ٣).**

## دفعة ٤ — الأقسام الوسطى

- قسم المطبخ (٣ صور من `fateer-*.jpg` الحقيقية) — يحذف شريط الأطباق التسعة وقسمَي الخطوات والقيم.
- قسم الليل والطريق + الطرد (§٧ لمسة ٤).
- قسم الفاتورة المكشوفة (§٧ لمسة ٣) — **بصفر رقم**.
- «الأفق الذهبي» عند كل انتقال + `.perf` فواصل داخلية.

## دفعة ٥ — القسمان البائعان والذيل

- قسم المطاعم بحشو ٩٦px + رابط «تطبيق المطعم» المنقول من الترويسة.
- قسم الكباتن على الورق + الحاسبة (`home.js`) + صفّ اللغات الخمس + حقن الخطّين بـ`IntersectionObserver`.
- دمج الأدلة في التذييل.
- `content-visibility:auto` + `contain-intrinsic-size:auto <ارتفاع مقيس>` على الأقسام دون الطيّة الثالثة **فقط** — لا على البطل ولا على أي قسمٍ له رابطٌ مرسى.

## دفعة ٦ — الصوت الطباعي الثالث (مشروطة بإقرار المالك)

- **قبلها:** ترسل لقطتان متقابلتان للبطل نفسه (بـReem Kufi وبدونه)، مع ذكر بند ز٢ ونصّ القيد الطباعي.
- إن أُقرّ: إضافة `&family=Reem+Kufi:wght@400..700` (١٢ ك.ب) بسقف ثلاثة عناصر.
- **وفي نفس الرسالة، منفصلاً:** يُرفع للمالك مقترح **Readex Pro** المتغيّر بديلاً عن Plex (٢٢ ك.ب بدل ٨٥، أي **−٦٣ ك.ب إضافية**، ومحور HEXP للكشيدة الرقمية) بلقطتين متقابلتين أيضاً — ولا يُنفَّذ إلا بأمره. **ولا تُنفَّذ لمسة الكشيدة على خطٍّ لا يحملها**، وإن نُفِّذت لاحقاً فبقيدٍ صارم: عنصرٌ واحد يتيم، مرّةً واحدة، على سطره الخاص، بمدّة ≤700ms، وبعد قياسٍ فعليّ على WebView أندرويد حقيقي (تحريك محاور الخطّ **يعيد التخطيط كل إطار** لأن عرض المحرف يتغيّر).

## دفعة ٧ — العبور (بعد قياس زمن الرسم)

- `@view-transition{navigation:auto}` في CSS الرئيسية و`/partner/` و`/join/`، مع `::view-transition-old(root),::view-transition-new(root){animation-duration:.32s}`.
- Speculation Rules مضمَّنة (~٣٠٠ بايت، تمرّ من `'unsafe-inline'`): `prefetch` بـ`eagerness:"moderate"` و`where.href_matches` على `/join/*` و`/partner/*` **فقط**. **لا `prerender` أبداً.**
- **شرطان قبل الشحن:** (١) قياس زمن الرسم فعلياً — **مهلة ٤ ثوانٍ**: إن لم تصر الصفحة الجديدة قابلة للرسم خلالها مات الانتقال بلا أثر. (٢) اختبار `/home/user/zadgo2/test/web_home_guard_test.dart` يعدّ `view-transition-name` — **تكرار اسمٍ واحد يُلغي الانتقال كلّه صامتاً**، ولا يُعطى الشعار اسماً لأنه يظهر مرّتين (ترويسة/تذييل).

---

# ١٠ — الفخاخ: ما ينكسر، وكيف يُفحص

| # | الفخّ | كيف ينكسر | الفحص المُلزِم |
|---|---|---|---|
| ١ | **الجدول الزمني الخامل/العالق** | `@supports` يمرّ، ثم لا يجد المتصفّح صندوق تمرير في المحور أو يبقى التقدّم عند 0% فيثبّت `animation-fill-mode:both` إطار `from` إلى الأبد. **لا خطأ في الكونسول، فقط عنصرٌ مفقود.** | افتح بعرض **320px** وتحقّق أن **كل بطاقةٍ ونصّ مرئي قبل أي تمرير**. وابحث في الملف: صفر `opacity:0` خارج `@keyframes` (اختبار آلي، §١٢). |
| ٢ | **التشريط في السماء** | تدرّجٌ كحلي + نقاطٌ 1px على 6-bit LCD = تشويش لا عمق. فرق «فخم/معطوب» فرق جهازٍ لا تصميم. | افتح البطل على **أندرويد متوسط حقيقي في غرفةٍ معتمة**. إن ظهر تشريط: فعّل حارس `noise.svg` (§٧ لمسة ١). |
| ٣ | **تلعثم العتبة** | `grid-template-rows` تعيد التخطيط والرسم لأكبر عنصرٍ على الشاشة طوال مدّة الانتقال. | Performance panel على جهازٍ متوسط أثناء لمس باب: ≥ 50fps. وإلا خُفِّضت النسب إلى `1.34fr .83fr .83fr`. |
| ٤ | **`--from` المتغيّر الميت** | `:root[dir=ltr] .wipe{--from:…}` يعرّف متغيّراً **لا تقرؤه `@keyframes` إطلاقاً**، فمسح العنوان في en/id يبقى معكوس الجهة. (لغمٌ في اتجاهين من الأربعة.) | بدّل اللغة إلى English وراقب اتّجاه المسح. الحلّ المعتمد: **تبديل `animation-name`** لا متغيّر. |
| ٥ | **`offset-path` بإحداثيات ثابتة** | الطرد يطير خارج الطريق على كل عرضٍ غير الذي رُسم عليه. | افتح على 320 / 360 / 430 / 1280 وتحقّق أن الطرد **على الخطّ**. الحلّ المعتمد: الطرد داخل نفس الـSVG. |
| ٦ | **`content-visibility` بلا `contain-intrinsic-size` مقيس** | يظنّ المتصفّح الارتفاع صفراً فيقفز شريط التمرير وتنطّ الصفحة تحت الإصبع — **أسوأ من المشكلة الأصلية**. ويكسر Ctrl+F والروابط المرساة ويخفي المحتوى عن الترجمة الآلية. | **قِس ارتفاع كل قسم فعلياً** ولا تخمّنه. لا يُطبَّق على البطل ولا على أي قسمٍ له `id` مقصودٌ برابط. جرّب Ctrl+F على كلمةٍ في آخر قسم. |
| ٧ | **فيض الترويسة** | `flex-wrap:nowrap` + `white-space:nowrap` + `overflow-x:clip` = **قصٌّ لا التفاف**، والمقصوص هو طرف الزرّ الذهبي (اليوم ≈٣٦٩px داخل ٣٦٠). | جهاز 360×740 **فعليّ** في اللغات الخمس — الحساب لا يكفي، فأعرض نصٍّ ليس العربية بالضرورة. |
| ٨ | **الذهب على الورق** | `#FFC107` على أبيض ≈ ١٫٧:١ و`#E0A800` ≈ ٢٫١٥:١ — **كلاهما ساقط**، ويصيب نصف كل عنوانٍ في الأقسام الفاتحة. | فاحص تباين على كل نصٍّ ذهبي. القاعدة: الذهب نصّاً **على الكحلي وحده**. |
| ٩ | **التباين عند منتصف التدرّج** | القياس عند الطرفين يمرّ ويسقط في الوسط. | قِس النصّ فوق **أفتح نقطة** في التدرّج (`#24407D`) لا فوق `#0B1935` وحدها. ولذلك حُصر `#24407D` في القبّة ولا يمتدّ خلف نصّ. |
| ١٠ | **`popover` على iOS الأقدم** | زرٌّ لا يفعل شيئاً، أو قائمةٌ معلّقة مكسورة وسط الصفحة — **عند الجمهور المذكور صراحةً في القيود** (الكابتن البنغالي والأردي). | الأساس `#langpop{display:none}` + `@supports selector(:popover-open)`. و`popovertarget` لا `command` (لم يصل سفاري إلا 26.2). وبديل الأربعة أسطر يمرّر الضغطة إلى صفّ اللغات. اختبر على iOS 17. |
| ١١ | **`view-transition-name` مكرّر** | يُلغي الانتقال **كلّه صامتاً**. | اختبار آلي يعدّ الأسماء في كل ملف (§١٢). ولا يُعطى الشعار اسماً. |
| ١٢ | **مهلة الأربع ثوانٍ في العبور** | على 4G ضعيفة يموت الانتقال بلا أثر. | يُشحن **بعد** دفعة الأداء لا قبلها، ويُقاس زمن الرسم فعلياً. |
| ١٣ | **`:has()` في قائمة محدّدات** | المحدّد غير المفهوم يُبطل **القاعدة كاملة** — فتسقط معه قواعد حرجة. | كل `:has()` في قاعدةٍ مستقلّة. |
| ١٤ | **`mix-blend-mode`/`backdrop-filter` على طبقةٍ بملء الشاشة** | ينشئان سياق طبقةٍ جديداً فيكسران `position:fixed` للأبناء، وتقطيع تمرير مضمون على iOS. | **لا واحد منهما في هذه المواصفة.** و`.rail` الثابت في جذر `<body>` خارج `.hero` تماماً. |
| ١٥ | **`data:` URI في CSS** | `img-src 'self'` **يمنعه** — فأي نقشٍ بـdata URI يفشل صامتاً. | النقوش **تدرّجاتٌ فقط**، والأختام **SVG مضمَّن في الوثيقة**، والضوضاء **ملفٌّ محليّ**. |
| ١٦ | **إعادة كتابة CSS تُسقط رأس المال الهندسي** | أول ما يسقط في أي إعادة كتابة: صفر خصائص فيزيائية، و`overflow-x:clip`، والتعليقات التي تشرح البديل المرفوض. **المشروع أُصيب بالاختفاء الصامت مرّتين.** | اختبار آلي يبحث عن `left:`/`right:`/`padding-left`/`margin-right` في CSS المضمَّن (§١٢). |
| ١٧ | **الخطوط تكسر صفحاتٍ أخرى** | حذف وزنٍ تستعمله `join/` أو `partner/` يظهر بديلاً غليظاً صامتاً. | `grep` على كل `docs/**/*.html` قبل الحذف + فحصٌ بصريّ لكل شاشة بعده. |
| ١٨ | **الرقم الذي يصير وعداً تعاقدياً** | أي نسبة أو مبلغ في الفاتورة أو الحاسبة يلزمنا به. | **صفر رقم.** ومراجعة بند ج١ وب١ قبل كتابة سطرٍ واحد. والحاسبة بصفر قيمة افتراضية وإفصاحٍ ملاصقٍ للنتيجة. |
| ١٩ | **«ثلاثة أبواب» وبابان** | النصّ يعد بثلاثة والشبكة تعرض اثنين — مخالفة و٣ صريحة. | باب العميل **لا يُحذف**؛ يتغيّر نصّه بمفتاح i18n بديل في كتلة `TRIAL_MODE` (والآلية موجودة وتعمل — نُسي استعمالها هنا). |
| ٢٠ | **الترجمة المتقادمة** | مفتاح يُضاف للعربية ويُنسى في الأردية فيظهر نصّ خام. | اختبار تطابق المفاتيح في الملفات الخمسة (§١٢). |

---

# ١١ — بنود تُضاف إلى الوثيقة المُلزِمة

تُكتب في `/home/user/zadgo2/dev-docs/binding-rules.md` تحت «و — الواجهة والمحتوى»، وسطرٌ لكلٍّ منها في `/home/user/zadgo2/dev-docs/guides/دليل-المبرمج-المبتدئ.md`:

> **و٤.** **الحالة النهائية هي الأساس.** لا تقنية حديثة تُظهر محتوى — كلّها تُحسّن محتوىً ظاهراً. لا `opacity:0` خارج `@keyframes`، ولا كشفٌ يبدأ من `0` (يبدأ من `.35`). و`@supports` يفحص النحو لا الواقع. **فحصٌ في قائمة المراجعة: افتح بعرض 320px وتأكّد أن كل عنصر مرئيّ قبل أي تمرير.**
>
> **و٥.** **عقد الحركة العربي.** ممنوع تقسيم أي نصٍّ عربي إلى محارف، وممنوع أثر الآلة الكاتبة. الوحدة الآمنة هي الكلمة، والأداة الآمنة هي `clip-path` مع `padding-block:.14em`. وممنوع `letter-spacing` و`justify` و`hyphens:auto` على العربية والأردية.
>
> **و٦.** **باب العميل لا يُحذف في وضع التجربة** — يتغيّر نصّه فقط. وأي نصٍّ يعد بعددٍ من المداخل يجب أن يطابق ما يُعرض فعلاً.
>
> **و٧.** **الذهب نصّاً على الكحلي وحده.** على الأرضيات الفاتحة يكون خطّاً أو حدّاً أو نقطة، والتمييز بالوزن لا باللون. والتباين يُقاس **عند كل نقطة من التدرّج** لا عند طرفيه.
>
> **و٨.** **صفر رقم مالي على الصفحة العامة** (نسبة عمولة، مبلغ حافز، قيمة افتراضية في حاسبة) إلا بإقرار مالكٍ صريح مستندٍ إلى `dev-docs/launch-financial-study.md`. وكل حاسبة تحمل إفصاحاً **ملاصقاً للنتيجة** لا في حاشية.
>
> **و٩.** **سقف الحركة: ٨ عناصر في الإطار الواحد، ٤ في الشاشة الأولى، صفر `will-change` دائم، وصفر حركة على `box-shadow`/`blur`/`backdrop-filter`.**

---

# ١٢ — الاختبارات الآلية (تُشغَّل في CI قبل البناء)

## `/home/user/zadgo2/test/web_home_guard_test.dart`

يقرأ `docs/index.html` و`docs/home.css` ويؤكّد:

1. **صفر `opacity:0` خارج `@keyframes`** — يمنع فخّ الظهور الصامت (الفخّ ١).
2. **صفر خاصية فيزيائية**: لا `left:`، `right:`، `padding-left`، `padding-right`، `margin-left`، `margin-right`، `border-left`، `border-right` (الفخّ ١٦).
3. **فرادة كل `view-transition-name`** في كل ملف على حدة (الفخّ ١١).
4. **لا `font-size` أقل من `.95rem`** ولا قيمة `px` أقل من 16.
5. **صفر `will-change` دائم** خارج قاعدةٍ محدَّدة زمنياً.
6. **صفر `backdrop-filter`** وصفر `animation` على `box-shadow`/`filter`/`background-position`.
7. **صفر `text-align:justify`** وصفر `hyphens:auto` وصفر `letter-spacing` بقيمةٍ غير `0`.
8. **صفر `view(inline)`**.
9. **كل `<img>` يحمل `width` و`height`** (أو حاويةٌ بـ`aspect-ratio`).
10. **قاعدة `prefers-reduced-motion` لا تحوي `animation:none`** على `*`.

## `/home/user/zadgo2/test/web_budget_test.dart`

يجمع أحجام `docs/index.html` + `docs/home.css` + `docs/home.js` + `docs/feedback.js` + الصور المشار إليها من الرئيسية، ويُفشل الاختبار فوق **٤٥٠ ك.ب**. (الخطوط خارجية فلا تُقاس هنا — تُثبَّت بسقف الأوزان في الاختبار الأول: لا أكثر من ثلاث عائلات في سطر الطلب.)

## `/home/user/zadgo2/test/i18n_parity_test.dart`

يتحقّق أن مجموعات مفاتيح `ar/en/bn/ur/id` **متطابقة تماماً**، وأن كل `data-i18n` في `docs/index.html` له مفتاحٌ موجود.

---

# ١٣ — مفاتيح i18n الجديدة (تُضاف للّغات الخمس معاً)

| المفتاح | العربية |
|---|---|
| `hero.trial` | نجرّب الخدمة الآن مع أوّل شركائنا |
| `hero.h1` | مطاعمك… <span class="kufi gold-word">أقرب لك</span> |
| `hero.honest` | السعر الذي تراه هو الذي تدفعه. |
| `hero.where` | نبدأ من حيٍّ واحد في المدينة المنورة، ونتوسّع حيّاً حيّاً. |
| `doors.lead` | زادقو منصّةٌ لثلاثة: من يطلب، ومن يطبخ، ومن يوصّل — اختر بابك. |
| `doors.c.d.trial` | نفتح الطلب للجميع قريباً — وسنعلن هنا أولاً. |
| `doors.go.trial` | تعرّف على المنصّة |
| `night.h2` | نعمل حين <em class="kufi">تعمل المدينة</em> |
| `night.body` | أعلى ساعات المطبخ في المدينة ليست الظهر… |
| `night.b1/b2/b3` | قبيل المغرب · بعد العشاء · ١٢ص — ٤ص |
| `bill.h2` | إلى أين يذهب <em>ريالك</em> |
| `bill.items/delivery/coupon/total` | الوجبات · التوصيل · خصم الكوبون · الإجمالي |
| `bill.to.rest/driver/zadgo` | إلى المطعم · إلى الكابتن · إلى زادقو |
| `bill.vat` | الأسعار شاملة ضريبة القيمة المضافة — لا سطر يُضاف عند الدفع. |
| `bill.coupon.note` | الخصم تموّله زادقو وحدها؛ لا يُخصم من المطعم ولا من الكابتن. |
| `bill.refund` | لو أُلغي طلبك، يعود إليك ما دفعته. |
| `calc.h/1..5/out/note` | حقول الحاسبة ومخرَجها وإفصاحها |
| `a11y.skip` | تخطَّ إلى المحتوى |
| `a11y.lang` | اللغة / Language |
| `a11y.prev/next` | السابق · التالي |

---

# ١٤ — تنبيهات البنود قبل الدفع (بند ز٢)

يُبلَّغ المالك بهذه **قبل** التنفيذ، بذكر رقم البند ونصّه:

1. **القيد الطباعي** («Alexandria للعناوين، IBM Plex Sans Arabic للنصّ»): إضافة **Reem Kufi** صوتاً ثالثاً بسقف ثلاثة عناصر — إضافةٌ لا استبدال. ومقترح **Readex Pro** بديلاً عن Plex مرفوعٌ منفصلاً بلقطتين متقابلتين، ولا يُنفَّذ إلا بأمره.
2. **بند ب١** (العمولة ١٥٪): هل يُنشر النصّ «عمولتنا ١٥٪ من مبيعاتك، تُخصم منك، والعميل يدفع سعر وجبتك كما هو» في قسم المطاعم؟ **النسخة المشحونة: لا.**
3. **بند و١/و٣**: حذف ثلاثة أقسام وستّ صور قد يُقرأ «تراجعاً» لا تحريراً. **يُعرض البرهان لا الرأي** — `f1.d` و`f2.t/f2.d` و`f4.d` **نفس مفاتيح i18n** مرسومةً مرّتين، ووعد «السعر الواضح» يُقال ستّ مرّات في سبع شاشات. **وتُعرض المقارنة على جوّالٍ متوسط حقيقي لا على شاشة مطوّر، وإلا رُفض التخفيض لسببٍ غير حقيقي.**
4. **CSP**: استضافة الخطوط ذاتياً تكسب ~١٨٠ مللي في LCP لكنها تحتاج `font-src 'self'` — **والسياسة تُشدّ لا تُرخى** بعدها (يجوز حذف googleapis وgstatic). **لم يُدرَج في هذه المواصفة**؛ الميزانية محقَّقة بدونه.
5. **إزالة صورة المدينة بملء الشاشة**: هي أجمل ما في الصفحة اليوم بشهادة الفحص. **الصورة لا تُحذف** بل تنزل إلى موضعها الصحيح — أفقاً مصوَّراً تحت سماءٍ مرسومة، وهو ما يمنح العمق الثلاثي أصلاً. **مؤشّر الفشل**: إن قال المالك «تبدو تطبيق بنك» فالعلاج **توسيع الجزيرة البيضاء إلى قسمين متتاليين، لا تفتيح الكحلي** — تفتيح الكحلي يُسقط التمايز كلّه.

---

**ملفات هذه المواصفة المرجعية:**
`/home/user/zadgo2/docs/index.html` · `/home/user/zadgo2/docs/home.css` · `/home/user/zadgo2/docs/home.js` · `/home/user/zadgo2/docs/lang.js` · `/home/user/zadgo2/dev-docs/binding-rules.md` · `/home/user/zadgo2/dev-docs/roadmap-ar.md` · `/home/user/zadgo2/dev-docs/pending-steps-ar.md` · `/home/user/zadgo2/dev-docs/guides/دليل-المبرمج-المبتدئ.md` · `/home/user/zadgo2/test/order_money_test.dart` · `/home/user/zadgo2/test/vat_test.dart` · `/home/user/zadgo2/test/delivery_fee_test.dart`