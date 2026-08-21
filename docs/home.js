/* ══════════════ منطق الصفحة الرئيسية ══════════════
 *
 * أُخرج من الوثيقة إلى ملفٍّ مؤجَّل (`defer`) لسببين مقيسين:
 * ١. القاموس وحده كان **ثلث ملف الـHTML** (٢٨ ك.ب من ٨٠)، وهو محتوىً لا
 *    يحتاجه الرسم الأول: الصفحة عربيةٌ في وسمها، والتبديل يقع بعد القراءة.
 * ٢. الشيفرة المضمَّنة تُنفَّذ قبل الرسم فتؤخّره؛ والمؤجَّلة تنتظر الوثيقة.
 *
 * **وتعطيل جافاسكربت لا يُخفي شيئاً**: الصفحة كاملةٌ بالعربية في وسمها،
 * وكل ما هنا تحسينٌ فوقها — لغةٌ أخرى، أو حاسبة، أو نصٌّ بديل لوضع التجربة.
 */
(function () {
  'use strict';

  /* ── الخطوط عند الحاجة ──
   * النستعليق وحده ٢٣٣ ك.ب. تحميله في رأس الصفحة لكل زائرٍ عربي لم يطلب
   * الأردية هدرٌ خالص — وهي السياسة التي كتبها المشروع لنفسه في lang.js
   * وكانت الرئيسية وحدها تخالفها. */
  var FONTS = {
    bn: 'https://fonts.googleapis.com/css2?family=Noto+Sans+Bengali:wght@400;700;800&display=swap',
    ur: 'https://fonts.googleapis.com/css2?family=Noto+Nastaliq+Urdu:wght@400;700&display=swap'
  };
  var loaded = {};
  function ensureFont(l) {
    if (!FONTS[l] || loaded[l]) return;
    loaded[l] = 1;
    var s = document.createElement('link');
    s.rel = 'stylesheet'; s.href = FONTS[l];
    document.head.appendChild(s);
  }

  var RTL = { ar: 1, ur: 1 };
  var NAMES = { ar: ['العربية', ''], en: ['English', ''], bn: ['বাংলা', 'Bangla'],
                ur: ['اردو', 'Urdu'], id: ['Indonesia', ''] };
  var ORDER = ['ar', 'en', 'bn', 'ur', 'id'];

  var I18N = {
  ar: {
    'a11y.skip': 'تخطَّ إلى المحتوى', 'a11y.lang': 'اللغة / Language',
    'nav.partner': 'ضمّ مطعمك', 'nav.app': 'تطبيق المطعم',
    'nav.contact': 'التواصل والدعم', 'nav.privacy': 'سياسة الخصوصية',
    'legal.terms': 'الشروط والأحكام', 'legal.del': 'حذف الحساب',
    'guides.rest': 'دليل المطعم', 'say.open': 'اقترح علينا',
    'hero.note': 'والتطبيق قادم قريباً',
    'hero.h1': 'مطاعمك… <span class="gold-word">أقرب لك</span>',
    'hero.honest': 'السعر الذي تراه هو الذي تدفعه.',
    'hero.where': 'نقطة انطلاقنا من المدينة المنورة إلى باقي المعمورة.',
    'partners.cta': 'ضمّ مطعمك الآن', 'riders.cta': 'انضم كابتناً الآن',
    'doors.h2': 'ادخل من <em>بابك</em>',
    'doors.lead': 'زادقو منصّةٌ لثلاثة: من يطلب، ومن يطبخ، ومن يوصّل — اختر بابك.',
    'taste.h2': 'ما <em>تشتهيه</em> — يصلك',
    'taste.lead': 'تصفّح مطاعم حيّك واطلب، والسعر أمامك قبل أن تضغط: الوجبة والتوصيل، بلا بندٍ يظهر عند الدفع.',
    'doors.r.t': 'أنا مطعم', 'doors.r.d': 'قائمتك الرقمية وطلباتك ومستحقاتك بحساب مكشوف.',
    'doors.d.t': 'أنا كابتن', 'doors.d.d': 'دخلٌ مرن، ونصيبك من كل توصيلة معروف قبل قبولها.',
    'doors.c.t': 'أنا عميل', 'doors.c.d': 'اطلب من مطاعم مدينتك — بلا تطبيق يُحمَّل.',
    'doors.c.d.trial': 'نفتح باب الطلب للجميع قريباً — وسنُعلن هنا أوّلاً.',
    'doors.go': 'ادخل ←', 'doors.go.trial': 'تعرّف على المنصّة ←',
    'kitchen.h2': 'ما تراه <em>هو ما يصلك</em>',
    'kitchen.lead': 'صور الأصناف في التطبيق من مطابخ شركائنا أنفسهم وبأسعارهم هم — ولا سعرٌ يتغيّر عند الدفع.',
    'kitchen.c1': 'فطير بالعسل', 'kitchen.c1d': 'من مطبخ شريكنا فطير ستيشن',
    'kitchen.c2': 'شيدر وعسل', 'kitchen.c2d': 'الصورة من المطعم نفسه وبسعره هو',
    'kitchen.c3': 'حلاوة وقشطة', 'kitchen.c3d': 'ونعرض السعرات لكل صنف قبل أن تطلب',
    'bill.h2': 'إلى أين يذهب <em>ريالك</em>',
    'bill.lead': 'فاتورتك ثلاثة بنودٍ وإجمال — ولا بند رابع يظهر عند الدفع.',
    'bill.you': 'ما تدفعه أنت', 'bill.where': 'وأين يذهب',
    'bill.items': 'الوجبات', 'bill.delivery': 'التوصيل',
    'bill.coupon': 'خصم الكوبون', 'bill.total': 'الإجمالي',
    'bill.w1': 'إلى المطعم', 'bill.w2': 'إلى الكابتن', 'bill.w3': 'إلى زادقو',
    'bill.n1': 'الأسعار شاملة ضريبة القيمة المضافة — لا سطر يُضاف عند الدفع.',
    'bill.n2': 'الخصم تموّله زادقو وحدها؛ لا يُخصم من المطعم ولا من الكابتن.',
    'bill.n3': 'ولو أُلغي طلبك، يعود إليك ما دفعته.',
    'partners.h2': 'لأصحاب المطاعم — <em>كن شريكاً</em>',
    'partners.sub': '<b>عملاء جدد يصلونك من اليوم الأول — بلا أي تكلفة تأسيس.</b> قائمة طعامك الرقمية بصورك وأسعارك، وطلباتك تصل مطبخك لحظة وقوعها، وتقارير تُطلعك على كل ريال.',
    'p1': 'قائمة طعامك الرقمية بصورك وأسعارك',
    'p2': 'طلباتك تصل مطبخك لحظة وقوعها',
    'p3': 'مستحقاتك بحساب مكشوف أمامك سطراً سطراً',
    'p4': 'أي جوال أندرويد عندك يصير شاشة طلباتك',
    'partners.app': 'حمّل تطبيق المطعم',
    'riders.h2': 'للكباتن — <em>دخلٌ مرن بشروط عادلة</em>',
    'r1.t': 'أرباح واضحة', 'r1.d': 'نصيبك من كل توصيلة معروفٌ قبل أن تقبلها — ومحفظةٌ ترصد كل ريال.',
    'r2.t': 'حرية الوقت', 'r2.d': 'اتصل متى شئت، واستلم الطلبات القريبة منك.',
    'r3.t': 'إنصاف التقييم', 'r3.d': 'نظام تقييمٍ شفّاف يحمي المجتهد.',
    'calc.h3': 'احسب صافيك بأرقامك أنت',
    'calc.hours': 'ساعات اليوم', 'calc.trips': 'عدد التوصيلات',
    'calc.avg': 'متوسط ما تقاضيته للتوصيلة', 'calc.fuel': 'وقود اليوم',
    'calc.other': 'مصاريف أخرى', 'calc.net': 'صافي اليوم', 'calc.hour': 'للساعة',
    'calc.note': 'هذا حسابٌ من أرقامك أنت. زادقو لا تَعِد بأي مبلغ، ولا يوجد رقمٌ مبرمَج في هذه الحاسبة.',
    'riders.langs': 'وبوّابتك بلغتك:'
  },
  en: {
    'a11y.skip': 'Skip to content', 'a11y.lang': 'Language',
    'nav.partner': 'List your restaurant', 'nav.app': 'Restaurant app',
    'nav.contact': 'Contact & support', 'nav.privacy': 'Privacy policy',
    'legal.terms': 'Terms & conditions', 'legal.del': 'Delete account',
    'guides.rest': 'Restaurant guide', 'say.open': 'Send us a suggestion',
    'hero.note': 'and the app is coming soon',
    'hero.h1': 'Your restaurants <span class="gold-word">closer to you</span>',
    'hero.honest': 'The price you see is the price you pay.',
    'hero.where': 'Our starting point is Madinah — and from there, the rest of the world.',
    'partners.cta': 'List your restaurant', 'riders.cta': 'Join as a captain',
    'doors.h2': 'Enter through <em>your door</em>',
    'doors.lead': 'ZadGo is a platform for three: whoever orders, whoever cooks, and whoever delivers — pick your door.',
    'taste.h2': 'What you <em>crave</em> — delivered',
    'taste.lead': 'Browse the restaurants in your neighbourhood and order. The price is in front of you before you tap: the meal and the delivery, with no line added at checkout.',
    'doors.r.t': "I'm a restaurant", 'doors.r.d': 'Your digital menu, your orders, and your earnings in the open.',
    'doors.d.t': "I'm a captain", 'doors.d.d': 'Flexible income — your share is known before you accept.',
    'doors.c.t': "I'm a customer", 'doors.c.d': "Order from your city's restaurants — no app to install.",
    'doors.c.d.trial': 'We open ordering to everyone soon — and we will announce it here first.',
    'doors.go': 'Enter →', 'doors.go.trial': 'Learn about the platform →',
    'kitchen.h2': 'What you see <em>is what arrives</em>',
    'kitchen.lead': 'Item photos in the app come from our partners\u2019 own kitchens, at their own prices — and no price that changes at checkout.',
    'kitchen.c1': 'Fateer with honey', 'kitchen.c1d': 'From our partner Fateer Station',
    'kitchen.c2': 'Cheddar & honey', 'kitchen.c2d': 'Photographed at the restaurant, at its own price',
    'kitchen.c3': 'Halawa & cream', 'kitchen.c3d': 'And we show calories per item before you order',
    'bill.h2': 'Where <em>your riyal</em> goes',
    'bill.lead': 'Your bill is three lines and a total — and no fourth line appears at checkout.',
    'bill.you': 'What you pay', 'bill.where': 'And where it goes',
    'bill.items': 'Food', 'bill.delivery': 'Delivery',
    'bill.coupon': 'Coupon discount', 'bill.total': 'Total',
    'bill.w1': 'To the restaurant', 'bill.w2': 'To the captain', 'bill.w3': 'To ZadGo',
    'bill.n1': 'Prices include VAT — no line is added at checkout.',
    'bill.n2': 'The discount is funded by ZadGo alone; it is not deducted from the restaurant or the captain.',
    'bill.n3': 'And if your order is cancelled, what you paid comes back to you.',
    'partners.h2': 'For restaurant owners — <em>become a partner</em>',
    'partners.sub': '<b>New customers from day one — zero setup cost.</b> Your digital menu with your photos and prices, orders reaching your kitchen the moment they are placed, and reports that account for every riyal.',
    'p1': 'Your digital menu with your own photos and prices',
    'p2': 'Orders reach your kitchen the moment they are placed',
    'p3': 'Your earnings itemized, line by line',
    'p4': 'Any Android phone becomes your orders screen',
    'partners.app': 'Get the restaurant app',
    'riders.h2': 'For captains — <em>flexible income, fair terms</em>',
    'r1.t': 'Clear earnings', 'r1.d': 'Your share of every delivery is known before you accept it — and a wallet tracks every riyal.',
    'r2.t': 'Your own hours', 'r2.d': 'Go online whenever you want, and take the orders near you.',
    'r3.t': 'Fair ratings', 'r3.d': 'A transparent rating system that protects the hard worker.',
    'calc.h3': 'Work out your net with your own numbers',
    'calc.hours': 'Hours today', 'calc.trips': 'Deliveries',
    'calc.avg': 'Average earned per delivery', 'calc.fuel': "Today's fuel",
    'calc.other': 'Other costs', 'calc.net': 'Net today', 'calc.hour': 'Per hour',
    'calc.note': 'This is a calculation from your own numbers. ZadGo promises no amount, and there is no preset figure in this calculator.',
    'riders.langs': 'And your portal, in your language:'
  },
  bn: {
    'a11y.skip': 'কনটেন্টে যান', 'a11y.lang': 'ভাষা / Language',
    'nav.partner': 'রেস্টুরেন্ট যুক্ত করুন', 'nav.app': 'রেস্টুরেন্ট অ্যাপ',
    'nav.contact': 'যোগাযোগ ও সাপোর্ট', 'nav.privacy': 'গোপনীয়তা নীতি',
    'legal.terms': 'শর্তাবলী', 'legal.del': 'অ্যাকাউন্ট মুছুন',
    'guides.rest': 'রেস্টুরেন্ট নির্দেশিকা', 'say.open': 'পরামর্শ দিন',
    'hero.note': 'আর অ্যাপ শীঘ্রই আসছে',
    'hero.h1': 'আপনার রেস্টুরেন্ট <span class="gold-word">আরও কাছে</span>',
    'hero.honest': 'যে দাম দেখেন, সেটাই দেন।',
    'hero.where': 'আমাদের যাত্রা শুরু মদিনা থেকে — আর সেখান থেকে গোটা দুনিয়ায়।',
    'partners.cta': 'আপনার রেস্টুরেন্ট যুক্ত করুন', 'riders.cta': 'ক্যাপ্টেন হিসেবে যোগ দিন',
    'doors.h2': 'আপনার <em>দরজা দিয়ে</em> ঢুকুন',
    'doors.lead': 'জাদগো তিনজনের প্ল্যাটফর্ম: যিনি অর্ডার করেন, যিনি রান্না করেন, যিনি পৌঁছে দেন — আপনার দরজা বেছে নিন।',
    'taste.h2': 'যা <em>খেতে ইচ্ছে করে</em> — পৌঁছে যাবে',
    'taste.lead': 'আপনার এলাকার রেস্টুরেন্ট দেখুন আর অর্ডার করুন। ট্যাপ করার আগেই দাম সামনে: খাবার আর ডেলিভারি — পেমেন্টে কোনো বাড়তি লাইন নেই।',
    'doors.r.t': 'আমি রেস্টুরেন্ট', 'doors.r.d': 'আপনার ডিজিটাল মেনু, অর্ডার আর প্রাপ্য — সবই খোলা হিসাবে।',
    'doors.d.t': 'আমি ক্যাপ্টেন', 'doors.d.d': 'নমনীয় আয় — গ্রহণের আগেই আপনার ভাগ জানা।',
    'doors.c.t': 'আমি গ্রাহক', 'doors.c.d': 'আপনার শহরের রেস্টুরেন্ট থেকে অর্ডার করুন — অ্যাপ ইনস্টল ছাড়াই।',
    'doors.c.d.trial': 'শীঘ্রই সবার জন্য অর্ডার খুলছি — আর প্রথম ঘোষণা এখানেই হবে।',
    'doors.go': 'প্রবেশ করুন →', 'doors.go.trial': 'প্ল্যাটফর্ম সম্পর্কে জানুন →',
    'kitchen.h2': 'যা দেখছেন <em>তাই পৌঁছাবে</em>',
    'kitchen.lead': 'অ্যাপে আইটেমের ছবি আমাদের পার্টনারদের নিজের রান্নাঘর থেকে, তাদের নিজের দামে — আর পেমেন্টে দাম বদলায় না।',
    'kitchen.c1': 'মধু দিয়ে ফাতির', 'kitchen.c1d': 'আমাদের পার্টনার ফাতির স্টেশন থেকে',
    'kitchen.c2': 'চেডার ও মধু', 'kitchen.c2d': 'রেস্টুরেন্টেই তোলা, তাদের নিজের দামে',
    'kitchen.c3': 'হালাওয়া ও ক্রিম', 'kitchen.c3d': 'আর অর্ডারের আগেই প্রতিটি আইটেমের ক্যালরি দেখাই',
    'bill.h2': 'আপনার <em>রিয়াল কোথায় যায়</em>',
    'bill.lead': 'আপনার বিল তিন লাইন আর একটি মোট — পেমেন্টে চতুর্থ কোনো লাইন আসে না।',
    'bill.you': 'আপনি যা দেন', 'bill.where': 'আর তা কোথায় যায়',
    'bill.items': 'খাবার', 'bill.delivery': 'ডেলিভারি',
    'bill.coupon': 'কুপন ছাড়', 'bill.total': 'মোট',
    'bill.w1': 'রেস্টুরেন্টে', 'bill.w2': 'ক্যাপ্টেনকে', 'bill.w3': 'জাদগোতে',
    'bill.n1': 'দামে ভ্যাট অন্তর্ভুক্ত — পেমেন্টে কোনো লাইন যোগ হয় না।',
    'bill.n2': 'ছাড়ের খরচ শুধু জাদগো বহন করে; রেস্টুরেন্ট বা ক্যাপ্টেন থেকে কাটা হয় না।',
    'bill.n3': 'আর অর্ডার বাতিল হলে যা দিয়েছেন তা ফেরত আসে।',
    'partners.h2': 'রেস্টুরেন্ট মালিকদের জন্য — <em>পার্টনার হোন</em>',
    'partners.sub': '<b>প্রথম দিন থেকেই নতুন গ্রাহক — কোনো সেটআপ খরচ নেই।</b> আপনার ছবি ও দামে ডিজিটাল মেনু, অর্ডার হওয়া মাত্র রান্নাঘরে, আর প্রতিটি রিয়ালের হিসাবসহ রিপোর্ট।',
    'p1': 'আপনার নিজের ছবি ও দামে ডিজিটাল মেনু',
    'p2': 'অর্ডার সঙ্গে সঙ্গে আপনার রান্নাঘরে পৌঁছায়',
    'p3': 'আপনার প্রাপ্য টাকার হিসাব, লাইন ধরে স্পষ্ট',
    'p4': 'যেকোনো অ্যান্ড্রয়েড ফোনই আপনার অর্ডার স্ক্রিন',
    'partners.app': 'রেস্টুরেন্ট অ্যাপ নিন',
    'riders.h2': 'ক্যাপ্টেনদের জন্য — <em>ন্যায্য শর্তে নমনীয় আয়</em>',
    'r1.t': 'স্পষ্ট আয়', 'r1.d': 'গ্রহণের আগেই প্রতিটি ডেলিভারির ভাগ জানা — ওয়ালেটে প্রতিটি রিয়ালের হিসাব।',
    'r2.t': 'সময়ের স্বাধীনতা', 'r2.d': 'যখন খুশি অনলাইন হন, কাছের অর্ডার নিন।',
    'r3.t': 'ন্যায্য রেটিং', 'r3.d': 'স্বচ্ছ রেটিং ব্যবস্থা পরিশ্রমীকে রক্ষা করে।',
    'calc.h3': 'নিজের সংখ্যা দিয়ে নিট হিসাব করুন',
    'calc.hours': 'আজকের ঘণ্টা', 'calc.trips': 'ডেলিভারি সংখ্যা',
    'calc.avg': 'প্রতি ডেলিভারিতে গড় আয়', 'calc.fuel': 'আজকের জ্বালানি',
    'calc.other': 'অন্যান্য খরচ', 'calc.net': 'আজকের নিট', 'calc.hour': 'ঘণ্টায়',
    'calc.note': 'এটি আপনার নিজের সংখ্যা থেকে হিসাব। জাদগো কোনো অঙ্কের প্রতিশ্রুতি দেয় না, আর এই ক্যালকুলেটরে কোনো নির্ধারিত সংখ্যা নেই।',
    'riders.langs': 'আর আপনার পোর্টাল, আপনার ভাষায়:'
  },
  ur: {
    'a11y.skip': 'مواد پر جائیں', 'a11y.lang': 'زبان / Language',
    'nav.partner': 'اپنا ریستوران شامل کریں', 'nav.app': 'ریستوران ایپ',
    'nav.contact': 'رابطہ اور مدد', 'nav.privacy': 'رازداری کی پالیسی',
    'legal.terms': 'شرائط و ضوابط', 'legal.del': 'اکاؤنٹ حذف کریں',
    'guides.rest': 'ریستوران گائیڈ', 'say.open': 'تجویز بھیجیں',
    'hero.note': 'اور ایپ جلد آ رہی ہے',
    'hero.h1': 'آپ کے ریستوران <span class="gold-word">اور قریب</span>',
    'hero.honest': 'جو قیمت دیکھیں، وہی ادا کریں۔',
    'hero.where': 'ہمارا آغاز مدینہ منورہ سے — اور وہاں سے پوری دنیا تک۔',
    'partners.cta': 'اپنا ریستوران شامل کریں', 'riders.cta': 'بطور کیپٹن شامل ہوں',
    'doors.h2': 'اپنے <em>دروازے</em> سے آئیں',
    'doors.lead': 'زادقو تین کے لیے ہے: جو آرڈر کرے، جو پکائے، اور جو پہنچائے — اپنا دروازہ چنیں۔',
    'taste.h2': 'جو <em>دل چاہے</em> — آپ تک',
    'taste.lead': 'اپنے محلے کے ریستوران دیکھیں اور آرڈر کریں۔ دبانے سے پہلے قیمت سامنے ہے: کھانا اور ڈیلیوری — ادائیگی پر کوئی اضافی لائن نہیں۔',
    'doors.r.t': 'میں ریستوران ہوں', 'doors.r.d': 'آپ کا ڈیجیٹل مینیو، آرڈرز اور رقم — سب کھلے حساب میں۔',
    'doors.d.t': 'میں کیپٹن ہوں', 'doors.d.d': 'لچکدار آمدنی — قبول کرنے سے پہلے آپ کا حصہ معلوم۔',
    'doors.c.t': 'میں گاہک ہوں', 'doors.c.d': 'اپنے شہر کے ریستورانوں سے آرڈر کریں — کوئی ایپ انسٹال کیے بغیر۔',
    'doors.c.d.trial': 'ہم جلد سب کے لیے آرڈر کھول رہے ہیں — اور اعلان سب سے پہلے یہیں ہوگا۔',
    'doors.go': 'داخل ہوں ←', 'doors.go.trial': 'پلیٹ فارم کے بارے میں جانیں ←',
    'kitchen.h2': 'جو دیکھیں <em>وہی پہنچے گا</em>',
    'kitchen.lead': 'ایپ میں آئٹمز کی تصاویر ہمارے شراکت داروں کے اپنے کچن سے ہیں، انہی کی قیمتوں پر — اور ادائیگی پر قیمت نہیں بدلتی۔',
    'kitchen.c1': 'شہد کے ساتھ فطیر', 'kitchen.c1d': 'ہمارے شراکت دار فطیر اسٹیشن سے',
    'kitchen.c2': 'چیڈر اور شہد', 'kitchen.c2d': 'ریستوران ہی میں لی گئی، اسی کی قیمت پر',
    'kitchen.c3': 'حلاوہ اور بالائی', 'kitchen.c3d': 'اور ہم آرڈر سے پہلے ہر آئٹم کی کیلوریز دکھاتے ہیں',
    'bill.h2': 'آپ کا <em>ریال کہاں جاتا ہے</em>',
    'bill.lead': 'آپ کا بل تین سطریں اور ایک میزان — ادائیگی پر چوتھی سطر نہیں آتی۔',
    'bill.you': 'آپ کیا ادا کرتے ہیں', 'bill.where': 'اور یہ کہاں جاتا ہے',
    'bill.items': 'کھانا', 'bill.delivery': 'ڈیلیوری',
    'bill.coupon': 'کوپن رعایت', 'bill.total': 'میزان',
    'bill.w1': 'ریستوران کو', 'bill.w2': 'کیپٹن کو', 'bill.w3': 'زادقو کو',
    'bill.n1': 'قیمتوں میں ویٹ شامل ہے — ادائیگی پر کوئی سطر نہیں بڑھتی۔',
    'bill.n2': 'رعایت کا خرچ صرف زادقو اٹھاتی ہے؛ ریستوران یا کیپٹن سے نہیں کٹتا۔',
    'bill.n3': 'اور اگر آرڈر منسوخ ہو تو جو ادا کیا وہ واپس آتا ہے۔',
    'partners.h2': 'ریستوران مالکان کے لیے — <em>شراکت دار بنیں</em>',
    'partners.sub': '<b>پہلے دن سے نئے گاہک — کوئی سیٹ اپ خرچ نہیں۔</b> آپ کی تصاویر اور قیمتوں کے ساتھ ڈیجیٹل مینیو، آرڈر ہوتے ہی کچن میں، اور ہر ریال کے حساب کے ساتھ رپورٹس۔',
    'p1': 'آپ کی اپنی تصاویر اور قیمتوں کے ساتھ ڈیجیٹل مینیو',
    'p2': 'آرڈر فوراً آپ کے کچن میں پہنچتا ہے',
    'p3': 'آپ کی رقم کا حساب، سطر بہ سطر واضح',
    'p4': 'کوئی بھی اینڈرائیڈ فون آپ کی آرڈر اسکرین بن جائے',
    'partners.app': 'ریستوران ایپ حاصل کریں',
    'riders.h2': 'کیپٹنوں کے لیے — <em>منصفانہ شرائط پر لچکدار آمدنی</em>',
    'r1.t': 'واضح کمائی', 'r1.d': 'قبول کرنے سے پہلے ہر ڈیلیوری کا حصہ معلوم — اور والٹ ہر ریال کا حساب رکھتا ہے۔',
    'r2.t': 'وقت کی آزادی', 'r2.d': 'جب چاہیں آن لائن ہوں، اور اپنے قریب کے آرڈر لیں۔',
    'r3.t': 'منصفانہ ریٹنگ', 'r3.d': 'شفاف ریٹنگ نظام محنتی کی حفاظت کرتا ہے۔',
    'calc.h3': 'اپنے اعداد سے اپنا خالص حساب لگائیں',
    'calc.hours': 'آج کے گھنٹے', 'calc.trips': 'ڈیلیوریوں کی تعداد',
    'calc.avg': 'فی ڈیلیوری اوسط کمائی', 'calc.fuel': 'آج کا ایندھن',
    'calc.other': 'دیگر اخراجات', 'calc.net': 'آج کا خالص', 'calc.hour': 'فی گھنٹہ',
    'calc.note': 'یہ آپ کے اپنے اعداد سے حساب ہے۔ زادقو کسی رقم کا وعدہ نہیں کرتی، اور اس کیلکولیٹر میں کوئی طے شدہ عدد نہیں۔',
    'riders.langs': 'اور آپ کا پورٹل، آپ کی زبان میں:'
  },
  id: {
    'a11y.skip': 'Lompat ke konten', 'a11y.lang': 'Bahasa / Language',
    'nav.partner': 'Daftarkan restoranmu', 'nav.app': 'Aplikasi restoran',
    'nav.contact': 'Kontak & dukungan', 'nav.privacy': 'Kebijakan privasi',
    'legal.terms': 'Syarat & ketentuan', 'legal.del': 'Hapus akun',
    'guides.rest': 'Panduan restoran', 'say.open': 'Kirim saran',
    'hero.note': 'dan aplikasinya segera hadir',
    'hero.h1': 'Restoranmu <span class="gold-word">lebih dekat</span>',
    'hero.honest': 'Harga yang kamu lihat, itu yang kamu bayar.',
    'hero.where': 'Titik awal kami dari Madinah — dan dari sana ke seluruh dunia.',
    'partners.cta': 'Daftarkan restoranmu', 'riders.cta': 'Gabung sebagai kurir',
    'doors.h2': 'Masuk lewat <em>pintumu</em>',
    'doors.lead': 'ZadGo adalah platform untuk tiga pihak: yang memesan, yang memasak, dan yang mengantar — pilih pintumu.',
    'taste.h2': 'Yang kamu <em>idamkan</em> — sampai',
    'taste.lead': 'Telusuri restoran di sekitarmu lalu pesan. Harganya di depanmu sebelum kamu menekan: makanan dan pengantaran, tanpa baris tambahan saat bayar.',
    'doors.r.t': 'Saya restoran', 'doors.r.d': 'Menu digital, pesanan, dan pendapatanmu terbuka jelas.',
    'doors.d.t': 'Saya kurir', 'doors.d.d': 'Penghasilan fleksibel — bagianmu diketahui sebelum menerima.',
    'doors.c.t': 'Saya pelanggan', 'doors.c.d': 'Pesan dari restoran di kotamu — tanpa unduh aplikasi.',
    'doors.c.d.trial': 'Kami segera membuka pemesanan untuk semua — dan akan kami umumkan di sini lebih dulu.',
    'doors.go': 'Masuk →', 'doors.go.trial': 'Kenali platformnya →',
    'kitchen.h2': 'Yang kamu lihat <em>itu yang tiba</em>',
    'kitchen.lead': 'Foto item di aplikasi berasal dari dapur mitra kami sendiri, dengan harga mereka sendiri — dan harga tidak berubah saat bayar.',
    'kitchen.c1': 'Fateer madu', 'kitchen.c1d': 'Dari mitra kami Fateer Station',
    'kitchen.c2': 'Cheddar & madu', 'kitchen.c2d': 'Difoto di restorannya, dengan harganya sendiri',
    'kitchen.c3': 'Halawa & krim', 'kitchen.c3d': 'Dan kami tampilkan kalori tiap item sebelum kamu memesan',
    'bill.h2': 'Ke mana <em>riyalmu</em> pergi',
    'bill.lead': 'Tagihanmu tiga baris dan satu total — tidak ada baris keempat saat bayar.',
    'bill.you': 'Yang kamu bayar', 'bill.where': 'Dan ke mana perginya',
    'bill.items': 'Makanan', 'bill.delivery': 'Pengiriman',
    'bill.coupon': 'Diskon kupon', 'bill.total': 'Total',
    'bill.w1': 'Ke restoran', 'bill.w2': 'Ke kurir', 'bill.w3': 'Ke ZadGo',
    'bill.n1': 'Harga sudah termasuk PPN — tidak ada baris yang ditambahkan saat bayar.',
    'bill.n2': 'Diskon dibiayai ZadGo sendiri; tidak dipotong dari restoran maupun kurir.',
    'bill.n3': 'Dan jika pesananmu dibatalkan, yang kamu bayar kembali kepadamu.',
    'partners.h2': 'Untuk pemilik restoran — <em>jadilah mitra</em>',
    'partners.sub': '<b>Pelanggan baru sejak hari pertama — tanpa biaya pendirian.</b> Menu digital dengan foto dan hargamu, pesanan masuk ke dapur seketika, dan laporan yang mencatat setiap riyal.',
    'p1': 'Menu digital dengan foto dan hargamu sendiri',
    'p2': 'Pesanan masuk ke dapurmu seketika',
    'p3': 'Pendapatanmu dirinci baris per baris',
    'p4': 'Ponsel Android apa pun jadi layar pesananmu',
    'partners.app': 'Unduh aplikasi restoran',
    'riders.h2': 'Untuk kurir — <em>penghasilan fleksibel, syarat adil</em>',
    'r1.t': 'Penghasilan jelas', 'r1.d': 'Bagianmu dari tiap antaran diketahui sebelum kamu menerimanya — dan dompet mencatat setiap riyal.',
    'r2.t': 'Waktu bebas', 'r2.d': 'Online kapan saja, dan ambil pesanan di dekatmu.',
    'r3.t': 'Rating adil', 'r3.d': 'Sistem rating transparan yang melindungi pekerja keras.',
    'calc.h3': 'Hitung bersihmu dengan angkamu sendiri',
    'calc.hours': 'Jam hari ini', 'calc.trips': 'Jumlah antaran',
    'calc.avg': 'Rata-rata per antaran', 'calc.fuel': 'Bahan bakar hari ini',
    'calc.other': 'Biaya lain', 'calc.net': 'Bersih hari ini', 'calc.hour': 'Per jam',
    'calc.note': 'Ini hitungan dari angkamu sendiri. ZadGo tidak menjanjikan jumlah apa pun, dan tidak ada angka bawaan di kalkulator ini.',
    'riders.langs': 'Dan portalmu, dalam bahasamu:'
  }
  };

  /* ── وضع التجربة ──
   * المنصّة في تجربة محدودة: مطعمٌ واحد وكابتنٌ واحد. ودعوة الجمهور في هذه
   * الحال مخاطرةٌ من نوعٍ واحد لكنه الأسوأ: عميلٌ يطلب في وقتٍ لا مطعمَ
   * مفتوحاً فيه، فينتظر ما لن يأتي ويحكم على المنصّة من تجربةٍ واحدة.
   *
   * **وباب العميل لا يُحذف** — يتغيّر نصّه فقط. النصّ فوقه يعد بثلاثة أبواب،
   * وعرضُ بابين تكذيبٌ للنصّ في السطر نفسه.
   *
   * للفتح للجمهور: بدّل السطر إلى false. لا شيء غيره.
   */
  var TRIAL_MODE = true;

  var cur = 'ar';
  function t(k) { return (I18N[cur] || I18N.ar)[k]; }

  function apply() {
    var d = I18N[cur] || I18N.ar;
    document.querySelectorAll('[data-i18n]').forEach(function (el) {
      var v = d[el.dataset.i18n];
      // النصوص ثوابت من المستودع لا إدخال مستخدم، فـinnerHTML آمنٌ هنا
      // ولازم: بعضها يحمل <em> و<b> و<bdi> وهي جزء من المعنى لا زينة.
      if (v != null) el.innerHTML = v;
    });
    document.querySelectorAll('[data-i18n-aria]').forEach(function (el) {
      var v = d[el.dataset.i18nAria];
      if (v != null) el.setAttribute('aria-label', v);
    });
    document.documentElement.lang = cur;
    document.documentElement.dir = RTL[cur] ? 'rtl' : 'ltr';
    document.body.className = 'lang-' + cur;
    document.querySelectorAll('#langrow button').forEach(function (b) {
      b.setAttribute('aria-current', b.dataset.lang === cur ? 'true' : 'false');
    });
  }

  function setLang(l) {
    if (!I18N[l]) return;
    cur = l;
    ensureFont(l);
    apply();
    trial();                       // النصوص البديلة تُعاد بعد كل تبديل
    try { localStorage.setItem('zadgo-lang', l); } catch (e) {}
  }

  function trial() {
    if (!TRIAL_MODE) return;
    /* الحاجب لا يُبدَّل: «والتطبيق قادم قريباً» كافٍ وصادق. وكان يُبدَّل
     * بسطرٍ يصف حالتنا الداخلية — حُذف بأمر المالك (2026-08-20): الحال
     * الداخلي وثيقةٌ داخلية، لا سطرٌ في واجهة البيع. */
    var door = document.getElementById('door-c');
    if (door) {
      var p = door.querySelector('p');
      var go = door.querySelector('.go');
      if (p) p.innerHTML = t('doors.c.d.trial') || p.innerHTML;
      if (go) go.innerHTML = t('doors.go.trial') || go.innerHTML;
    }
  }

  /* ── صفّ اللغات في قسم الكباتن ──
   * منفذٌ ثانٍ للّغة **عند من يحتاجه**: الكابتن البنغالي أو الأردي يقرأ هذا
   * القسم، ولا يبحث عن زرٍّ في ترويسةٍ بحرفٍ لا يعرفه. وهو أيضاً بديل
   * `popover` حيث لا يُدعم. والحروف الأصلية مع مكافئها اللاتيني أصغر —
   * فيبقى الزرّ مفهوماً حتى قبل وصول خطّه. */
  var row = document.getElementById('langrow');
  if (row) {
    ORDER.forEach(function (l) {
      var b = document.createElement('button');
      b.type = 'button'; b.dataset.lang = l;
      b.dir = RTL[l] ? 'rtl' : 'ltr';
      b.innerHTML = NAMES[l][1]
        ? NAMES[l][0] + '<small>' + NAMES[l][1] + '</small>'
        : NAMES[l][0];
      b.addEventListener('click', function () { setLang(l); });
      row.appendChild(b);
    });
  }

  document.querySelectorAll('#langpop button[data-lang]').forEach(function (b) {
    b.addEventListener('click', function () {
      setLang(b.dataset.lang);
      var pop = document.getElementById('langpop');
      if (pop && pop.hidePopover) { try { pop.hidePopover(); } catch (e) {} }
    });
  });

  /* بديل زرّ اللغة حيث لا `popover`: الضغطة تنقل إلى صفّ اللغات.
   * أسوأ حالة: المفتاح ينقلك إلى منفذٍ يعمل — إخفاءٌ لا كسر. */
  var btn = document.getElementById('langbtn');
  if (btn && !('showPopover' in HTMLElement.prototype)) {
    btn.addEventListener('click', function (e) {
      e.preventDefault();
      var mq = matchMedia('(prefers-reduced-motion:reduce)');
      if (row) row.scrollIntoView({ block: 'center', behavior: mq.matches ? 'auto' : 'smooth' });
    });
  }

  /* ── حاسبة الكابتن ──
   * **صفر قيمةٍ افتراضية وصفر رقمٍ مبرمَج** (بند ج١): الحساب من أرقام
   * الكابتن وحدها، والإفصاح ملاصقٌ للنتيجة لا في حاشيةٍ تحت الطيّ. */
  var ids = ['c-h', 'c-t', 'c-a', 'c-f', 'c-o'];
  var net = document.getElementById('c-net');
  var hr = document.getElementById('c-hr');
  function num(id) {
    var el = document.getElementById(id);
    var v = el ? parseFloat(el.value) : NaN;
    return isFinite(v) && v >= 0 ? v : null;
  }
  function money(v) {
    return v.toLocaleString('en-US', { maximumFractionDigits: 1 }) + ' ر.س';
  }
  function calc() {
    if (!net) return;
    var trips = num('c-t'), avg = num('c-a'), hours = num('c-h');
    var fuel = num('c-f') || 0, other = num('c-o') || 0;
    if (trips == null || avg == null) { net.textContent = '—'; hr.textContent = '—'; return; }
    var n = trips * avg - fuel - other;
    net.textContent = money(n);
    hr.textContent = (hours && hours > 0) ? money(n / hours) : '—';
  }
  ids.forEach(function (id) {
    var el = document.getElementById(id);
    if (el) el.addEventListener('input', calc);
  });

  /* ── الإقلاع ── */
  var saved = null;
  try { saved = localStorage.getItem('zadgo-lang'); } catch (e) {}
  if (saved && I18N[saved] && saved !== 'ar') { setLang(saved); }
  else { apply(); trial(); }
})();
