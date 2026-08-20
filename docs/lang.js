/* محرّك اللغة المشترك لصفحات الموقع — عدا الصفحة الرئيسية.
 *
 * **المشكلة التي حلّها** (بلاغ المالك 2026-08-20): مبدّل اللغة كان في
 * الرئيسية وحدها، فمن اختار الإنجليزية ثم ضغط «انضم كابتناً» وجد صفحةً
 * عربية بالكامل. واللغات الخمس عندنا ليست زينة: البنغالية والأردية
 * والإندونيسية هي لغات الكباتن، وصفحة الانضمام هي أوّل ما يفتحونه.
 *
 * **لماذا ملفٌّ واحد لا نسخةٌ في كل صفحة؟** لأن الترجمة تتقادم: سطرٌ
 * يُعدَّل في صفحة ويُنسى في أخرى. المعاجم كلها هنا، وكل صفحة تعلن اسمها
 * في `<html data-i18n-page="join">` فتأخذ معجمها ومعجمَ المشترك.
 *
 * **والخطوط تُحمَّل عند الحاجة فقط**: خطّا البنغالية والأردية ثقيلان
 * (النستعليق خاصةً)، وتحميلهما لكل زائرٍ عربي هدرٌ خالص — فيُطلبان لحظة
 * اختيار لغتهما لا قبلها.
 *
 * المفتاح في التخزين `zadgo-lang` هو نفسه الذي تستعمله الرئيسية، فاختيارُ
 * الزائر يتبعه بين الصفحات بلا معامل في الرابط.
 */
(function () {
  'use strict';

  var RTL   = { ar: 1, ur: 1 };
  var NAMES = { ar: 'العربية', en: 'English', bn: 'বাংলা', ur: 'اردو', id: 'Indonesia' };
  var ORDER = ['ar', 'en', 'bn', 'ur', 'id'];

  /* ── المشترك: الترويسة والتذييل والروابط القانونية ── */
  var COMMON = {
    ar: { 'nav.home': 'الرئيسية', 'nav.contact': 'التواصل والدعم',
          'nav.privacy': 'سياسة الخصوصية', 'nav.terms': 'الشروط والأحكام',
          'nav.delete': 'حذف الحساب', 'foot.rights': 'جميع الحقوق محفوظة',
          'say.open': '💡 اقترح علينا' },
    en: { 'nav.home': 'Home', 'nav.contact': 'Contact & support',
          'nav.privacy': 'Privacy policy', 'nav.terms': 'Terms & conditions',
          'nav.delete': 'Delete account', 'foot.rights': 'All rights reserved',
          'say.open': '💡 Send us a suggestion' },
    bn: { 'nav.home': 'হোম', 'nav.contact': 'যোগাযোগ ও সাপোর্ট',
          'nav.privacy': 'গোপনীয়তা নীতি', 'nav.terms': 'শর্তাবলী',
          'nav.delete': 'অ্যাকাউন্ট মুছুন', 'foot.rights': 'সর্বস্বত্ব সংরক্ষিত',
          'say.open': '💡 পরামর্শ দিন' },
    ur: { 'nav.home': 'ہوم', 'nav.contact': 'رابطہ اور مدد',
          'nav.privacy': 'رازداری کی پالیسی', 'nav.terms': 'شرائط و ضوابط',
          'nav.delete': 'اکاؤنٹ حذف کریں', 'foot.rights': 'جملہ حقوق محفوظ ہیں',
          'say.open': '💡 تجویز بھیجیں' },
    id: { 'nav.home': 'Beranda', 'nav.contact': 'Kontak & dukungan',
          'nav.privacy': 'Kebijakan privasi', 'nav.terms': 'Syarat & ketentuan',
          'nav.delete': 'Hapus akun', 'foot.rights': 'Hak cipta dilindungi',
          'say.open': '💡 Kirim saran' }
  };

  var PAGES = {};

  /* ── صفحة انضمام الكباتن ── */
  PAGES.join = {
    ar: {
      'j.pill': '✦ نراجع طلبك خلال ٢٤ ساعة',
      'j.h1': 'انضم إلينا <span>كابتناً</span>',
      'j.lede': 'عبّئ بياناتك وارفع مستنداتك، وسنراجع طلبك ونتواصل معك.<br>الرفع يتم من جوالك مباشرة — لا حاجة لحاسوب.',
      'j.p1t': 'أرباح واضحة', 'j.p1d': 'نصيبك من كل توصيلة معروف قبل قبولها — ومحفظة ترصد كل ريال',
      'j.p2t': 'حرية الوقت', 'j.p2d': 'اتصل متى شئت، واستلم الطلبات القريبة منك',
      'j.p3t': 'إنصاف التقييم', 'j.p3d': 'نظام شفاف يحمي المجتهد',
      'j.sec1': 'بياناتك', 'j.hint1': 'اكتبها كما في الهوية أو الإقامة تماماً.',
      'j.name': 'الاسم الكامل', 'j.e.name': 'اكتب اسمك الثلاثي',
      'j.phone': 'رقم الجوال', 'j.e.phone': 'رقم سعودي يبدأ بـ05 ويتكون من ١٠ أرقام',
      'j.nid': 'رقم الهوية / الإقامة', 'j.e.nid': '١٠ أرقام',
      'j.email': 'البريد الإلكتروني', 'j.e.email': 'بريد صحيح — يصير اسم دخولك للتطبيق لاحقاً',
      'j.vtype': 'نوع المركبة', 'j.choose': 'اختر…', 'j.moto': 'دراجة نارية', 'j.car': 'سيارة',
      'j.e.vtype': 'اختر نوع مركبتك',
      'j.plate': 'رقم اللوحة', 'j.e.plate': 'اكتب رقم اللوحة',
      'j.ref': 'كود من دعاك (اختياري)',
      'j.sec2': 'المستندات',
      'j.hint2': 'صوّرها بجوالك في ضوء واضح، وتأكد أن الأرقام والتواريخ مقروءة. الصور تُصغَّر تلقائياً قبل الرفع فلا تستهلك باقتك.',
      'j.sec3': 'صور المركبة',
      'j.hint3': 'أربع جهات: أمام، خلف، يمين، يسار — واللوحة ظاهرة في صورة الأمام أو الخلف.',
      'j.submit': 'إرسال الطلب',
      'j.note': 'بإرسالك الطلب توافق على <a href="/terms.html">الشروط والأحكام</a> و<a href="/privacy-policy.html">سياسة الخصوصية</a>. مستنداتك لا يطّلع عليها إلا الإدارة.',
      'j.doneh': 'وصلنا طلبك',
      'j.donenote': 'احتفظ برقم جوالك متاحاً — سنتواصل معك عليه.',
      'j.back': 'العودة للصفحة الرئيسية',
      'j.d.id': 'الهوية الوطنية أو الإقامة', 'j.d.idsub': 'صورة واضحة للوجه الأمامي',
      'j.d.idBack': 'ظهر الهوية أو الإقامة', 'j.d.idBacksub': 'الوجه الخلفي',
      'j.d.license': 'رخصة القيادة', 'j.d.licensesub': 'سارية المفعول',
      'j.d.reg': 'الاستمارة (رخصة السير)', 'j.d.regsub': 'سارية المفعول',
      'j.d.ins': 'وثيقة التأمين', 'j.d.inssub': 'سارية المفعول',
      'j.d.free': 'وثيقة العمل الحر', 'j.d.freesub': 'للسعوديين — بمسمى «مندوب توصيل طلبات»',
      'j.d.crim': 'شهادة خلو من السوابق', 'j.d.crimsub': 'إن توفرت',
      'j.d.auth': 'تفويض قيادة', 'j.d.authsub': 'إن كانت المركبة ليست باسمك',
      'j.ph.front': 'صورة المركبة من الأمام', 'j.ph.back': 'صورة المركبة من الخلف',
      'j.ph.right': 'صورة المركبة من اليمين', 'j.ph.left': 'صورة المركبة من اليسار',
      'j.pick': 'اختر صورة'
    },
    en: {
      'j.pill': '✦ We review your application within 24 hours',
      'j.h1': 'Join us as a <span>captain</span>',
      'j.lede': 'Fill in your details and upload your documents; we will review and contact you.<br>Upload straight from your phone — no computer needed.',
      'j.p1t': 'Clear earnings', 'j.p1d': 'Your share of every delivery is known before you accept — and a wallet tracks every riyal',
      'j.p2t': 'Your own hours', 'j.p2d': 'Go online whenever you want and take orders near you',
      'j.p3t': 'Fair ratings', 'j.p3d': 'A transparent system that protects hard workers',
      'j.sec1': 'Your details', 'j.hint1': 'Write them exactly as on your ID or iqama.',
      'j.name': 'Full name', 'j.e.name': 'Enter your full name',
      'j.phone': 'Mobile number', 'j.e.phone': 'A Saudi number starting with 05, 10 digits',
      'j.nid': 'ID / Iqama number', 'j.e.nid': '10 digits',
      'j.email': 'Email', 'j.e.email': 'A valid email — it becomes your app login later',
      'j.vtype': 'Vehicle type', 'j.choose': 'Choose…', 'j.moto': 'Motorcycle', 'j.car': 'Car',
      'j.e.vtype': 'Choose your vehicle type',
      'j.plate': 'Plate number', 'j.e.plate': 'Enter the plate number',
      'j.ref': 'Referral code (optional)',
      'j.sec2': 'Documents',
      'j.hint2': 'Photograph them with your phone in good light, and make sure numbers and dates are readable. Images are compressed before upload so they do not eat your data.',
      'j.sec3': 'Vehicle photos',
      'j.hint3': 'Four sides: front, back, right, left — with the plate visible in the front or back photo.',
      'j.submit': 'Send application',
      'j.note': 'By sending, you agree to the <a href="/terms.html">Terms</a> and <a href="/privacy-policy.html">Privacy policy</a>. Only the administration can see your documents.',
      'j.doneh': 'We received your application',
      'j.donenote': 'Keep your phone reachable — we will contact you on it.',
      'j.back': 'Back to the home page',
      'j.d.id': 'National ID or iqama', 'j.d.idsub': 'A clear photo of the front',
      'j.d.idBack': 'Back of the ID or iqama', 'j.d.idBacksub': 'The back side',
      'j.d.license': 'Driving licence', 'j.d.licensesub': 'Must be valid',
      'j.d.reg': 'Vehicle registration (istimara)', 'j.d.regsub': 'Must be valid',
      'j.d.ins': 'Insurance document', 'j.d.inssub': 'Must be valid',
      'j.d.free': 'Freelance permit', 'j.d.freesub': 'For Saudis — titled “delivery courier”',
      'j.d.crim': 'Criminal record clearance', 'j.d.crimsub': 'If available',
      'j.d.auth': 'Driving authorisation', 'j.d.authsub': 'If the vehicle is not in your name',
      'j.ph.front': 'Vehicle photo — front', 'j.ph.back': 'Vehicle photo — back',
      'j.ph.right': 'Vehicle photo — right', 'j.ph.left': 'Vehicle photo — left',
      'j.pick': 'Choose photo'
    },
    bn: {
      'j.pill': '✦ ২৪ ঘণ্টার মধ্যে আপনার আবেদন দেখা হবে',
      'j.h1': '<span>ক্যাপ্টেন</span> হিসেবে যোগ দিন',
      'j.lede': 'আপনার তথ্য দিন ও কাগজপত্র আপলোড করুন; আমরা দেখে আপনার সঙ্গে যোগাযোগ করব।<br>ফোন থেকেই আপলোড — কম্পিউটার লাগবে না।',
      'j.p1t': 'স্পষ্ট আয়', 'j.p1d': 'গ্রহণের আগেই প্রতিটি ডেলিভারির ভাগ জানা — ওয়ালেটে প্রতিটি রিয়ালের হিসাব',
      'j.p2t': 'সময়ের স্বাধীনতা', 'j.p2d': 'যখন খুশি অনলাইন হন, কাছের অর্ডার নিন',
      'j.p3t': 'ন্যায্য রেটিং', 'j.p3d': 'স্বচ্ছ ব্যবস্থা পরিশ্রমীকে রক্ষা করে',
      'j.sec1': 'আপনার তথ্য', 'j.hint1': 'আইডি বা ইকামায় যেভাবে আছে ঠিক সেভাবে লিখুন।',
      'j.name': 'পুরো নাম', 'j.e.name': 'আপনার পুরো নাম লিখুন',
      'j.phone': 'মোবাইল নম্বর', 'j.e.phone': '০৫ দিয়ে শুরু সৌদি নম্বর, ১০ সংখ্যা',
      'j.nid': 'আইডি / ইকামা নম্বর', 'j.e.nid': '১০ সংখ্যা',
      'j.email': 'ইমেইল', 'j.e.email': 'সঠিক ইমেইল — পরে এটিই অ্যাপের লগইন হবে',
      'j.vtype': 'যানবাহনের ধরন', 'j.choose': 'বেছে নিন…', 'j.moto': 'মোটরসাইকেল', 'j.car': 'গাড়ি',
      'j.e.vtype': 'যানবাহনের ধরন বেছে নিন',
      'j.plate': 'প্লেট নম্বর', 'j.e.plate': 'প্লেট নম্বর লিখুন',
      'j.ref': 'রেফারেল কোড (ঐচ্ছিক)',
      'j.sec2': 'কাগজপত্র',
      'j.hint2': 'ভালো আলোয় ফোন দিয়ে ছবি তুলুন, নম্বর ও তারিখ যেন পড়া যায়। আপলোডের আগে ছবি ছোট করা হয়, তাই ডেটা বেশি খরচ হয় না।',
      'j.sec3': 'গাড়ির ছবি',
      'j.hint3': 'চার দিক: সামনে, পেছনে, ডানে, বামে — সামনে বা পেছনের ছবিতে প্লেট দেখা যেতে হবে।',
      'j.submit': 'আবেদন পাঠান',
      'j.note': 'পাঠানোর মানে আপনি <a href="/terms.html">শর্তাবলী</a> ও <a href="/privacy-policy.html">গোপনীয়তা নীতি</a> মানছেন। আপনার কাগজপত্র শুধু প্রশাসন দেখতে পায়।',
      'j.doneh': 'আপনার আবেদন পৌঁছেছে',
      'j.donenote': 'ফোন খোলা রাখুন — আমরা সেখানেই যোগাযোগ করব।',
      'j.back': 'হোম পেজে ফিরুন',
      'j.d.id': 'জাতীয় পরিচয়পত্র বা ইকামা', 'j.d.idsub': 'সামনের দিকের স্পষ্ট ছবি',
      'j.d.idBack': 'আইডি বা ইকামার পেছন', 'j.d.idBacksub': 'পেছনের দিক',
      'j.d.license': 'ড্রাইভিং লাইসেন্স', 'j.d.licensesub': 'মেয়াদ থাকতে হবে',
      'j.d.reg': 'গাড়ির রেজিস্ট্রেশন (ইস্তিমারা)', 'j.d.regsub': 'মেয়াদ থাকতে হবে',
      'j.d.ins': 'বিমার কাগজ', 'j.d.inssub': 'মেয়াদ থাকতে হবে',
      'j.d.free': 'ফ্রিল্যান্স অনুমতিপত্র', 'j.d.freesub': 'সৌদিদের জন্য — “ডেলিভারি কুরিয়ার” নামে',
      'j.d.crim': 'পুলিশ ক্লিয়ারেন্স', 'j.d.crimsub': 'থাকলে',
      'j.d.auth': 'ড্রাইভিং অনুমতি', 'j.d.authsub': 'গাড়ি আপনার নামে না হলে',
      'j.ph.front': 'গাড়ির ছবি — সামনে', 'j.ph.back': 'গাড়ির ছবি — পেছনে',
      'j.ph.right': 'গাড়ির ছবি — ডানে', 'j.ph.left': 'গাড়ির ছবি — বামে',
      'j.pick': 'ছবি বেছে নিন'
    },
    ur: {
      'j.pill': '✦ ہم ۲۴ گھنٹے میں آپ کی درخواست دیکھتے ہیں',
      'j.h1': 'ہمارے ساتھ <span>کیپٹن</span> بنیں',
      'j.lede': 'اپنی تفصیلات بھریں اور دستاویزات اپ لوڈ کریں؛ ہم جائزہ لے کر آپ سے رابطہ کریں گے۔<br>اپ لوڈ موبائل ہی سے — کمپیوٹر کی ضرورت نہیں۔',
      'j.p1t': 'واضح کمائی', 'j.p1d': 'قبول کرنے سے پہلے ہر ڈیلیوری کا حصہ معلوم — والٹ میں ہر ریال کا حساب',
      'j.p2t': 'وقت کی آزادی', 'j.p2d': 'جب چاہیں آن لائن ہوں اور قریبی آرڈر لیں',
      'j.p3t': 'منصفانہ ریٹنگ', 'j.p3d': 'شفاف نظام محنتی کی حفاظت کرتا ہے',
      'j.sec1': 'آپ کی تفصیلات', 'j.hint1': 'جیسا شناختی کارڈ یا اقامہ میں ہے بالکل ویسا لکھیں۔',
      'j.name': 'پورا نام', 'j.e.name': 'اپنا پورا نام لکھیں',
      'j.phone': 'موبائل نمبر', 'j.e.phone': '۰۵ سے شروع سعودی نمبر، ۱۰ ہندسے',
      'j.nid': 'شناختی / اقامہ نمبر', 'j.e.nid': '۱۰ ہندسے',
      'j.email': 'ای میل', 'j.e.email': 'درست ای میل — بعد میں یہی ایپ کا لاگ اِن بنے گا',
      'j.vtype': 'گاڑی کی قسم', 'j.choose': 'منتخب کریں…', 'j.moto': 'موٹر سائیکل', 'j.car': 'کار',
      'j.e.vtype': 'اپنی گاڑی کی قسم منتخب کریں',
      'j.plate': 'پلیٹ نمبر', 'j.e.plate': 'پلیٹ نمبر لکھیں',
      'j.ref': 'ریفرل کوڈ (اختیاری)',
      'j.sec2': 'دستاویزات',
      'j.hint2': 'اچھی روشنی میں موبائل سے تصویر لیں، نمبر اور تاریخیں پڑھی جا سکیں۔ اپ لوڈ سے پہلے تصویریں چھوٹی کر دی جاتی ہیں، سو ڈیٹا زیادہ خرچ نہیں ہوتا۔',
      'j.sec3': 'گاڑی کی تصاویر',
      'j.hint3': 'چار رخ: آگے، پیچھے، دائیں، بائیں — آگے یا پیچھے کی تصویر میں پلیٹ نظر آئے۔',
      'j.submit': 'درخواست بھیجیں',
      'j.note': 'بھیجنے کا مطلب ہے آپ <a href="/terms.html">شرائط</a> اور <a href="/privacy-policy.html">رازداری کی پالیسی</a> سے متفق ہیں۔ آپ کی دستاویزات صرف انتظامیہ دیکھتی ہے۔',
      'j.doneh': 'آپ کی درخواست موصول ہو گئی',
      'j.donenote': 'اپنا فون کھلا رکھیں — ہم اسی پر رابطہ کریں گے۔',
      'j.back': 'ہوم پیج پر واپس',
      'j.d.id': 'قومی شناختی کارڈ یا اقامہ', 'j.d.idsub': 'سامنے کی واضح تصویر',
      'j.d.idBack': 'شناختی کارڈ یا اقامہ کی پشت', 'j.d.idBacksub': 'پچھلا رخ',
      'j.d.license': 'ڈرائیونگ لائسنس', 'j.d.licensesub': 'کارآمد ہونا چاہیے',
      'j.d.reg': 'گاڑی کی رجسٹریشن (استمارہ)', 'j.d.regsub': 'کارآمد ہونا چاہیے',
      'j.d.ins': 'انشورنس دستاویز', 'j.d.inssub': 'کارآمد ہونا چاہیے',
      'j.d.free': 'فری لانس اجازت نامہ', 'j.d.freesub': 'سعودیوں کے لیے — «ڈیلیوری کیپٹن» کے عنوان سے',
      'j.d.crim': 'کریمنل ریکارڈ سرٹیفکیٹ', 'j.d.crimsub': 'اگر دستیاب ہو',
      'j.d.auth': 'ڈرائیونگ اجازت نامہ', 'j.d.authsub': 'اگر گاڑی آپ کے نام نہ ہو',
      'j.ph.front': 'گاڑی کی تصویر — سامنے', 'j.ph.back': 'گاڑی کی تصویر — پیچھے',
      'j.ph.right': 'گاڑی کی تصویر — دائیں', 'j.ph.left': 'گاڑی کی تصویر — بائیں',
      'j.pick': 'تصویر منتخب کریں'
    },
    id: {
      'j.pill': '✦ Kami tinjau lamaranmu dalam 24 jam',
      'j.h1': 'Gabung sebagai <span>kurir</span>',
      'j.lede': 'Isi datamu dan unggah dokumen; kami tinjau lalu menghubungimu.<br>Unggah langsung dari ponsel — tanpa komputer.',
      'j.p1t': 'Penghasilan jelas', 'j.p1d': 'Bagianmu dari tiap antaran diketahui sebelum kamu terima — dan dompet mencatat setiap riyal',
      'j.p2t': 'Waktu bebas', 'j.p2d': 'Online kapan saja dan ambil pesanan terdekat',
      'j.p3t': 'Rating adil', 'j.p3d': 'Sistem transparan yang melindungi pekerja keras',
      'j.sec1': 'Data kamu', 'j.hint1': 'Tulis persis seperti di KTP atau iqama.',
      'j.name': 'Nama lengkap', 'j.e.name': 'Tulis nama lengkapmu',
      'j.phone': 'Nomor ponsel', 'j.e.phone': 'Nomor Saudi diawali 05, 10 digit',
      'j.nid': 'Nomor ID / Iqama', 'j.e.nid': '10 digit',
      'j.email': 'Email', 'j.e.email': 'Email yang valid — nanti jadi login aplikasimu',
      'j.vtype': 'Jenis kendaraan', 'j.choose': 'Pilih…', 'j.moto': 'Sepeda motor', 'j.car': 'Mobil',
      'j.e.vtype': 'Pilih jenis kendaraanmu',
      'j.plate': 'Nomor pelat', 'j.e.plate': 'Tulis nomor pelat',
      'j.ref': 'Kode undangan (opsional)',
      'j.sec2': 'Dokumen',
      'j.hint2': 'Foto dengan ponsel di cahaya terang, pastikan angka dan tanggal terbaca. Gambar dikecilkan sebelum diunggah agar hemat kuota.',
      'j.sec3': 'Foto kendaraan',
      'j.hint3': 'Empat sisi: depan, belakang, kanan, kiri — pelat terlihat di foto depan atau belakang.',
      'j.submit': 'Kirim lamaran',
      'j.note': 'Dengan mengirim, kamu setuju pada <a href="/terms.html">Syarat</a> dan <a href="/privacy-policy.html">Kebijakan privasi</a>. Dokumenmu hanya dilihat administrasi.',
      'j.doneh': 'Lamaranmu sudah kami terima',
      'j.donenote': 'Pastikan ponselmu aktif — kami akan menghubungimu di sana.',
      'j.back': 'Kembali ke beranda',
      'j.d.id': 'KTP atau iqama', 'j.d.idsub': 'Foto jelas sisi depan',
      'j.d.idBack': 'Bagian belakang ID atau iqama', 'j.d.idBacksub': 'Sisi belakang',
      'j.d.license': 'SIM', 'j.d.licensesub': 'Harus masih berlaku',
      'j.d.reg': 'STNK (istimara)', 'j.d.regsub': 'Harus masih berlaku',
      'j.d.ins': 'Dokumen asuransi', 'j.d.inssub': 'Harus masih berlaku',
      'j.d.free': 'Izin freelance', 'j.d.freesub': 'Untuk warga Saudi — bertajuk “kurir pengantaran”',
      'j.d.crim': 'Surat keterangan catatan kepolisian', 'j.d.crimsub': 'Bila ada',
      'j.d.auth': 'Surat kuasa mengemudi', 'j.d.authsub': 'Bila kendaraan bukan atas namamu',
      'j.ph.front': 'Foto kendaraan — depan', 'j.ph.back': 'Foto kendaraan — belakang',
      'j.ph.right': 'Foto kendaraan — kanan', 'j.ph.left': 'Foto kendaraan — kiri',
      'j.pick': 'Pilih foto'
    }
  };


  /* ── صفحة ضمّ المطاعم ── */
  PAGES.partner = {
    ar: {
      'p.pill': '✦ بلا أي تكلفة تأسيس',
      'p.h1': 'مطعمك في جيب<br><span>كل ساكن بالمدينة</span>',
      'p.lede': '<b>عملاء جدد يصلونك من اليوم الأول.</b> قائمة طعامك الرقمية بصورك وأسعارك، وطلباتك تصل مطبخك لحظة وقوعها، ومستحقاتك بحساب مكشوف أمامك.',
      'p.sec1': 'ماذا تحصل <span>عليه</span>', 'p.sec1lead': 'لا وعوداً عامة — هذه أدواتٌ تعمل اليوم.',
      'p.f1t': 'تطبيق للمطعم', 'p.f1d': 'الطلب يصل شاشتك فتقبله أو تعتذر، وتنقله بين «قيد التحضير» و«جاهز» بضغطة.',
      'p.f2t': 'قائمة طعام بصورك وأسعارك', 'p.f2d': 'تعدّل السعر أو توقف صنفاً نفد بضغطة — يظهر للعملاء في اللحظة نفسها.',
      'p.f3t': 'كباتننا يوصّلون', 'p.f3d': 'لا تحتاج مندوبين ولا دراجات — نحن نتكفّل بالتوصيل من بابك إلى العميل.',
      'p.f4t': 'حساب مكشوف', 'p.f4d': 'تقرير بكل طلب ومبلغه، ومستحقاتك مبيّنة سطراً سطراً بلا اجتهاد.',
      'p.f5t': 'تقييمات حقيقية', 'p.f5d': 'من عملاء طلبوا فعلاً — لا مجاملات ولا تقييمات مشتراة.',
      'p.f6t': 'أنت تقرّر متى تفتح', 'p.f6d': 'تضع حالتك «مغلق» فيتوقّف استقبال الطلبات فوراً — ولا يصلك طلبٌ وأنت مقفل.',
      'p.guide': '📖 تريد أن ترى كيف تعمل قبل أن تقرّر؟', 'p.guidelink': 'اقرأ دليل المطعم',
      'p.guidetail': '— دورة الطلب، وكيف تُحسب مستحقّاتك، وإدارة قائمة طعامك.',
      'p.form': 'أرسل بيانات <span>مطعمك</span>', 'p.formlead': 'املأ ما تعرفه ونتواصل معك. لا يستغرق دقيقة.',
      'p.rest': 'اسم المطعم', 'p.branch': 'الحي أو الفرع', 'p.opt': '(اختياري)',
      'p.mgr': 'اسم المسؤول', 'p.phone': 'رقم الجوال',
      'p.kitchen': 'نوع المطبخ', 'p.choose': 'اختر…',
      'p.k1': 'مأكولات شعبية', 'p.k2': 'مشاوي ولحوم', 'p.k3': 'فطائر ومعجّنات',
      'p.k4': 'وجبات سريعة وبرغر', 'p.k5': 'دجاج وبروست', 'p.k6': 'مأكولات بحرية',
      'p.k7': 'حلويات ومخبوزات', 'p.k8': 'قهوة ومشروبات', 'p.k9': 'مطبخ آسيوي', 'p.k10': 'أخرى',
      'p.items': 'عدد الأصناف تقريباً', 'p.i1': 'أقل من ١٠', 'p.i2': '١٠ – ٣٠', 'p.i3': '٣٠ – ٦٠', 'p.i4': 'أكثر من ٦٠',
      'p.note': 'ملاحظة', 'p.send': 'أرسل عبر واتساب', 'p.mail': 'أو أرسل بالبريد إلى info@zadgo.co',
      'p.faq': 'أسئلة <span>يسألها الجميع</span>',
      'p.q1': 'هل عليّ رسوم اشتراك أو تأسيس؟',
      'p.a1': 'لا. لا رسوم تأسيس ولا اشتراك شهري. نتقاسم من الطلب المنفَّذ فقط — وتُشرح لك التفاصيل كاملةً قبل أن توقّع شيئاً.',
      'p.q2': 'من يوصّل الطلبات؟',
      'p.a2': 'كباتننا. لا تحتاج مندوبين ولا دراجات ولا تأميناً عليهم — يصل الكابتن إلى بابك فيستلم ويوصّل.',
      'p.q3': 'كيف تصلني الطلبات؟',
      'p.a3': 'على تطبيق المطعم. يظهر الطلب على شاشتك بأصنافه ومبلغه، فتقبله أو تعتذر بسببٍ يراه العميل.',
      'p.q4': 'وإن أردت الإغلاق يوماً أو ساعة؟',
      'p.a4': 'تضع حالتك «مغلق» من التطبيق فيتوقف استقبال الطلبات فوراً — ولا يستطيع أحد الطلب منك وأنت مقفل، لا من التطبيق ولا من الموقع.',
      'p.q5': 'ومتى أستلم مستحقاتي؟',
      'p.a5': 'تُحصر مستحقاتك في تسوية دورية مبيّنة سطراً سطراً: قيمة طلباتك، وما خُصم، والصافي. ويُتفق على الدورة معك.'
    },
    en: {
      'p.pill': '✦ No setup cost at all',
      'p.h1': 'Your restaurant in the pocket of<br><span>everyone in the city</span>',
      'p.lede': '<b>New customers from day one.</b> Your digital menu with your own photos and prices, orders reaching your kitchen the moment they are placed, and your earnings itemized in the open.',
      'p.sec1': 'What you <span>get</span>', 'p.sec1lead': 'No vague promises — these are tools that work today.',
      'p.f1t': 'A restaurant app', 'p.f1d': 'Orders arrive on your screen; accept or decline, and move them between “preparing” and “ready” with one tap.',
      'p.f2t': 'A menu with your photos and prices', 'p.f2d': 'Change a price or pause a sold-out item with one tap — customers see it the same second.',
      'p.f3t': 'Our captains deliver', 'p.f3d': 'No couriers or bikes of your own — we handle delivery from your door to the customer.',
      'p.f4t': 'An open ledger', 'p.f4d': 'A report of every order and its amount, and your dues itemized line by line.',
      'p.f5t': 'Real ratings', 'p.f5d': 'From customers who actually ordered — no favours, no bought reviews.',
      'p.f6t': 'You decide when to open', 'p.f6d': 'Set your status to “closed” and orders stop immediately — nothing reaches you while you are shut.',
      'p.guide': '📖 Want to see how it works before deciding?', 'p.guidelink': 'Read the restaurant guide',
      'p.guidetail': '— the order cycle, how your dues are calculated, and menu management.',
      'p.form': 'Send your <span>restaurant details</span>', 'p.formlead': 'Fill in what you know and we will contact you. It takes under a minute.',
      'p.rest': 'Restaurant name', 'p.branch': 'District or branch', 'p.opt': '(optional)',
      'p.mgr': 'Contact person', 'p.phone': 'Mobile number',
      'p.kitchen': 'Cuisine', 'p.choose': 'Choose…',
      'p.k1': 'Traditional Saudi', 'p.k2': 'Grills & meat', 'p.k3': 'Pastries & fateer',
      'p.k4': 'Fast food & burgers', 'p.k5': 'Chicken & broast', 'p.k6': 'Seafood',
      'p.k7': 'Desserts & bakery', 'p.k8': 'Coffee & drinks', 'p.k9': 'Asian', 'p.k10': 'Other',
      'p.items': 'Approximate number of items', 'p.i1': 'Under 10', 'p.i2': '10 – 30', 'p.i3': '30 – 60', 'p.i4': 'Over 60',
      'p.note': 'Note', 'p.send': 'Send via WhatsApp', 'p.mail': 'or email us at info@zadgo.co',
      'p.faq': 'Questions <span>everyone asks</span>',
      'p.q1': 'Are there subscription or setup fees?',
      'p.a1': 'No. No setup fee and no monthly subscription. We share only from completed orders — and the full details are explained before you sign anything.',
      'p.q2': 'Who delivers the orders?',
      'p.a2': 'Our captains. You need no couriers, no bikes and no insurance for them — the captain comes to your door, collects and delivers.',
      'p.q3': 'How do orders reach me?',
      'p.a3': 'On the restaurant app. The order appears on your screen with its items and amount; you accept it or decline with a reason the customer sees.',
      'p.q4': 'What if I want to close for a day or an hour?',
      'p.a4': 'Set your status to “closed” in the app and orders stop immediately — nobody can order from you while you are shut, from the app or the website.',
      'p.q5': 'When do I receive my dues?',
      'p.a5': 'Your dues are settled on a regular cycle, itemized line by line: the value of your orders, what was deducted, and the net. The cycle is agreed with you.'
    },
    bn: {
      'p.pill': '✦ কোনো সেটআপ খরচ নেই',
      'p.h1': 'আপনার রেস্টুরেন্ট<br><span>শহরের সবার পকেটে</span>',
      'p.lede': '<b>প্রথম দিন থেকেই নতুন গ্রাহক।</b> আপনার নিজের ছবি ও দামে ডিজিটাল মেনু, অর্ডার সঙ্গে সঙ্গে রান্নাঘরে, আর আপনার প্রাপ্য খোলা হিসাবে।',
      'p.sec1': 'আপনি যা <span>পাবেন</span>', 'p.sec1lead': 'অস্পষ্ট প্রতিশ্রুতি নয় — এগুলো আজই কাজ করছে।',
      'p.f1t': 'রেস্টুরেন্ট অ্যাপ', 'p.f1d': 'অর্ডার আপনার স্ক্রিনে আসে; গ্রহণ বা প্রত্যাখ্যান করুন, আর এক চাপে “তৈরি হচ্ছে” ও “প্রস্তুত”-এ নিন।',
      'p.f2t': 'নিজের ছবি ও দামে মেনু', 'p.f2d': 'এক চাপে দাম বদলান বা শেষ হওয়া আইটেম বন্ধ করুন — গ্রাহক তখনই দেখে।',
      'p.f3t': 'আমাদের ক্যাপ্টেনরা পৌঁছে দেয়', 'p.f3d': 'নিজের কুরিয়ার বা বাইক লাগে না — আপনার দরজা থেকে গ্রাহক পর্যন্ত আমরা দেখি।',
      'p.f4t': 'খোলা হিসাব', 'p.f4d': 'প্রতিটি অর্ডার ও তার অঙ্কের রিপোর্ট, আর আপনার প্রাপ্য লাইন ধরে স্পষ্ট।',
      'p.f5t': 'আসল রেটিং', 'p.f5d': 'যারা সত্যিই অর্ডার করেছেন তাদের কাছ থেকে — কেনা রিভিউ নয়।',
      'p.f6t': 'কখন খুলবেন আপনি ঠিক করেন', 'p.f6d': '“বন্ধ” করে দিলে অর্ডার আসা সঙ্গে সঙ্গে থেমে যায় — বন্ধ থাকা অবস্থায় কিছুই আসে না।',
      'p.guide': '📖 সিদ্ধান্তের আগে কীভাবে কাজ করে দেখতে চান?', 'p.guidelink': 'রেস্টুরেন্ট নির্দেশিকা পড়ুন',
      'p.guidetail': '— অর্ডারের চক্র, প্রাপ্য কীভাবে হিসাব হয়, আর মেনু পরিচালনা।',
      'p.form': 'আপনার <span>রেস্টুরেন্টের তথ্য</span> পাঠান', 'p.formlead': 'যা জানেন লিখুন, আমরা যোগাযোগ করব। এক মিনিটও লাগে না।',
      'p.rest': 'রেস্টুরেন্টের নাম', 'p.branch': 'এলাকা বা শাখা', 'p.opt': '(ঐচ্ছিক)',
      'p.mgr': 'দায়িত্বপ্রাপ্ত ব্যক্তির নাম', 'p.phone': 'মোবাইল নম্বর',
      'p.kitchen': 'রান্নার ধরন', 'p.choose': 'বেছে নিন…',
      'p.k1': 'ঐতিহ্যবাহী সৌদি', 'p.k2': 'গ্রিল ও মাংস', 'p.k3': 'পেস্ট্রি ও ফাতির',
      'p.k4': 'ফাস্ট ফুড ও বার্গার', 'p.k5': 'চিকেন ও ব্রোস্ট', 'p.k6': 'সামুদ্রিক খাবার',
      'p.k7': 'মিষ্টি ও বেকারি', 'p.k8': 'কফি ও পানীয়', 'p.k9': 'এশিয়ান', 'p.k10': 'অন্যান্য',
      'p.items': 'আনুমানিক আইটেম সংখ্যা', 'p.i1': '১০-এর কম', 'p.i2': '১০ – ৩০', 'p.i3': '৩০ – ৬০', 'p.i4': '৬০-এর বেশি',
      'p.note': 'মন্তব্য', 'p.send': 'হোয়াটসঅ্যাপে পাঠান', 'p.mail': 'অথবা ইমেইল করুন info@zadgo.co',
      'p.faq': 'সবাই যে <span>প্রশ্ন করে</span>',
      'p.q1': 'সাবস্ক্রিপশন বা সেটআপ ফি আছে?',
      'p.a1': 'না। সেটআপ ফি নেই, মাসিক সাবস্ক্রিপশনও নেই। শুধু সম্পন্ন অর্ডার থেকেই ভাগ — এবং কিছু সই করার আগে সব বিস্তারিত বোঝানো হয়।',
      'p.q2': 'অর্ডার কে পৌঁছে দেয়?',
      'p.a2': 'আমাদের ক্যাপ্টেনরা। নিজের কুরিয়ার, বাইক বা তাদের বিমা কিছুই লাগে না — ক্যাপ্টেন আপনার দরজায় এসে নিয়ে পৌঁছে দেয়।',
      'p.q3': 'অর্ডার আমার কাছে কীভাবে আসে?',
      'p.a3': 'রেস্টুরেন্ট অ্যাপে। অর্ডার আইটেম ও অঙ্কসহ স্ক্রিনে আসে; আপনি গ্রহণ করেন বা কারণসহ প্রত্যাখ্যান করেন যা গ্রাহক দেখে।',
      'p.q4': 'একদিন বা এক ঘণ্টার জন্য বন্ধ রাখতে চাইলে?',
      'p.a4': 'অ্যাপে “বন্ধ” করে দিন, অর্ডার আসা তখনই থামে — বন্ধ থাকা অবস্থায় অ্যাপ বা ওয়েবসাইট কোথাও থেকেই কেউ অর্ডার করতে পারে না।',
      'p.q5': 'আমার টাকা কখন পাব?',
      'p.a5': 'নিয়মিত চক্রে হিসাব মিটিয়ে দেওয়া হয়, লাইন ধরে স্পষ্ট: অর্ডারের মূল্য, কী কাটা হলো, আর নিট। চক্রটি আপনার সঙ্গে ঠিক করা হয়।'
    },
    ur: {
      'p.pill': '✦ کوئی سیٹ اپ خرچ نہیں',
      'p.h1': 'آپ کا ریستوران<br><span>شہر کے ہر فرد کی جیب میں</span>',
      'p.lede': '<b>پہلے دن سے نئے گاہک۔</b> آپ کی اپنی تصاویر اور قیمتوں کے ساتھ ڈیجیٹل مینیو، آرڈر فوراً آپ کے کچن میں، اور آپ کی رقم کھلے حساب میں۔',
      'p.sec1': 'آپ کو <span>کیا ملتا ہے</span>', 'p.sec1lead': 'مبہم وعدے نہیں — یہ آج کام کرنے والے اوزار ہیں۔',
      'p.f1t': 'ریستوران ایپ', 'p.f1d': 'آرڈر آپ کی سکرین پر آتا ہے؛ قبول کریں یا معذرت، اور ایک ٹیپ سے «تیاری میں» اور «تیار» کے درمیان لے جائیں۔',
      'p.f2t': 'اپنی تصاویر اور قیمتوں کا مینیو', 'p.f2d': 'ایک ٹیپ سے قیمت بدلیں یا ختم شدہ آئٹم روکیں — گاہک اُسی لمحے دیکھتا ہے۔',
      'p.f3t': 'ہمارے کیپٹن پہنچاتے ہیں', 'p.f3d': 'اپنے کوریئر یا موٹرسائیکل کی ضرورت نہیں — آپ کے دروازے سے گاہک تک ہم دیکھتے ہیں۔',
      'p.f4t': 'کھلا حساب', 'p.f4d': 'ہر آرڈر اور اس کی رقم کی رپورٹ، اور آپ کی واجب رقم سطر بہ سطر واضح۔',
      'p.f5t': 'حقیقی ریٹنگ', 'p.f5d': 'صرف اُن گاہکوں سے جنہوں نے واقعی آرڈر کیا — خریدے ہوئے ریویو نہیں۔',
      'p.f6t': 'کھلنے کا وقت آپ طے کریں', 'p.f6d': 'حالت «بند» کر دیں تو آرڈر آنا فوراً رک جاتا ہے — بند ہونے کی صورت میں کچھ نہیں آتا۔',
      'p.guide': '📖 فیصلے سے پہلے دیکھنا چاہتے ہیں یہ کیسے چلتا ہے؟', 'p.guidelink': 'ریستوران گائیڈ پڑھیں',
      'p.guidetail': '— آرڈر کا چکر، آپ کی رقم کیسے شمار ہوتی ہے، اور مینیو کی دیکھ بھال۔',
      'p.form': 'اپنے <span>ریستوران کی تفصیل</span> بھیجیں', 'p.formlead': 'جو معلوم ہے لکھیں، ہم رابطہ کریں گے۔ ایک منٹ بھی نہیں لگتا۔',
      'p.rest': 'ریستوران کا نام', 'p.branch': 'علاقہ یا برانچ', 'p.opt': '(اختیاری)',
      'p.mgr': 'ذمہ دار کا نام', 'p.phone': 'موبائل نمبر',
      'p.kitchen': 'کھانے کی قسم', 'p.choose': 'منتخب کریں…',
      'p.k1': 'روایتی سعودی', 'p.k2': 'گرل اور گوشت', 'p.k3': 'پیسٹری اور فطیر',
      'p.k4': 'فاسٹ فوڈ اور برگر', 'p.k5': 'چکن اور بروسٹ', 'p.k6': 'سمندری غذا',
      'p.k7': 'میٹھا اور بیکری', 'p.k8': 'کافی اور مشروبات', 'p.k9': 'ایشیائی', 'p.k10': 'دیگر',
      'p.items': 'آئٹمز کی تقریبی تعداد', 'p.i1': '۱۰ سے کم', 'p.i2': '۱۰ – ۳۰', 'p.i3': '۳۰ – ۶۰', 'p.i4': '۶۰ سے زیادہ',
      'p.note': 'نوٹ', 'p.send': 'واٹس ایپ پر بھیجیں', 'p.mail': 'یا ای میل کریں info@zadgo.co',
      'p.faq': 'وہ سوال <span>جو سب پوچھتے ہیں</span>',
      'p.q1': 'کیا سبسکرپشن یا سیٹ اپ فیس ہے؟',
      'p.a1': 'نہیں۔ نہ سیٹ اپ فیس نہ ماہانہ سبسکرپشن۔ حصہ صرف مکمل ہونے والے آرڈر سے — اور کچھ دستخط کرنے سے پہلے پوری تفصیل سمجھائی جاتی ہے۔',
      'p.q2': 'آرڈر کون پہنچاتا ہے؟',
      'p.a2': 'ہمارے کیپٹن۔ آپ کو اپنے کوریئر، موٹرسائیکل یا اُن کے انشورنس کی ضرورت نہیں — کیپٹن آپ کے دروازے آ کر لے جاتا اور پہنچاتا ہے۔',
      'p.q3': 'آرڈر مجھ تک کیسے پہنچتا ہے؟',
      'p.a3': 'ریستوران ایپ پر۔ آرڈر اپنی اشیاء اور رقم کے ساتھ سکرین پر آتا ہے؛ آپ قبول کریں یا ایسی وجہ کے ساتھ معذرت کریں جو گاہک دیکھتا ہے۔',
      'p.q4': 'اگر ایک دن یا ایک گھنٹے کے لیے بند کرنا ہو؟',
      'p.a4': 'ایپ سے حالت «بند» کر دیں، آرڈر آنا فوراً رک جاتا ہے — بند ہونے پر نہ ایپ سے نہ ویب سائٹ سے کوئی آرڈر کر سکتا ہے۔',
      'p.q5': 'میری رقم کب ملتی ہے؟',
      'p.a5': 'آپ کی رقم باقاعدہ دورانیے میں سطر بہ سطر واضح کر کے ادا کی جاتی ہے: آرڈرز کی مالیت، کیا کٹا، اور خالص۔ دورانیہ آپ سے طے ہوتا ہے۔'
    },
    id: {
      'p.pill': '✦ Tanpa biaya pendirian sama sekali',
      'p.h1': 'Restoranmu di saku<br><span>setiap warga kota</span>',
      'p.lede': '<b>Pelanggan baru sejak hari pertama.</b> Menu digital dengan foto dan hargamu sendiri, pesanan masuk ke dapurmu seketika, dan pendapatanmu dirinci terbuka.',
      'p.sec1': 'Apa yang kamu <span>dapatkan</span>', 'p.sec1lead': 'Bukan janji kosong — ini alat yang sudah berjalan hari ini.',
      'p.f1t': 'Aplikasi restoran', 'p.f1d': 'Pesanan muncul di layarmu; terima atau tolak, dan pindahkan antara “disiapkan” dan “siap” dengan satu ketukan.',
      'p.f2t': 'Menu dengan foto dan hargamu', 'p.f2d': 'Ubah harga atau hentikan item yang habis dengan satu ketukan — pelanggan melihatnya saat itu juga.',
      'p.f3t': 'Kurir kami yang mengantar', 'p.f3d': 'Tak perlu kurir atau motor sendiri — kami tangani pengiriman dari pintumu ke pelanggan.',
      'p.f4t': 'Pembukuan terbuka', 'p.f4d': 'Laporan tiap pesanan dan nilainya, serta hakmu dirinci baris per baris.',
      'p.f5t': 'Rating asli', 'p.f5d': 'Dari pelanggan yang benar-benar memesan — bukan ulasan yang dibeli.',
      'p.f6t': 'Kamu yang menentukan jam buka', 'p.f6d': 'Setel status “tutup” dan pesanan langsung berhenti — tak ada yang masuk saat kamu tutup.',
      'p.guide': '📖 Ingin lihat cara kerjanya sebelum memutuskan?', 'p.guidelink': 'Baca panduan restoran',
      'p.guidetail': '— siklus pesanan, cara hakmu dihitung, dan pengelolaan menu.',
      'p.form': 'Kirim <span>data restoranmu</span>', 'p.formlead': 'Isi yang kamu tahu dan kami akan menghubungimu. Kurang dari semenit.',
      'p.rest': 'Nama restoran', 'p.branch': 'Distrik atau cabang', 'p.opt': '(opsional)',
      'p.mgr': 'Nama penanggung jawab', 'p.phone': 'Nomor ponsel',
      'p.kitchen': 'Jenis masakan', 'p.choose': 'Pilih…',
      'p.k1': 'Masakan Saudi', 'p.k2': 'Panggangan & daging', 'p.k3': 'Pastri & fateer',
      'p.k4': 'Cepat saji & burger', 'p.k5': 'Ayam & broast', 'p.k6': 'Makanan laut',
      'p.k7': 'Manisan & roti', 'p.k8': 'Kopi & minuman', 'p.k9': 'Asia', 'p.k10': 'Lainnya',
      'p.items': 'Perkiraan jumlah item', 'p.i1': 'Di bawah 10', 'p.i2': '10 – 30', 'p.i3': '30 – 60', 'p.i4': 'Lebih dari 60',
      'p.note': 'Catatan', 'p.send': 'Kirim lewat WhatsApp', 'p.mail': 'atau email ke info@zadgo.co',
      'p.faq': 'Pertanyaan <span>yang sering diajukan</span>',
      'p.q1': 'Apakah ada biaya langganan atau pendirian?',
      'p.a1': 'Tidak. Tanpa biaya pendirian dan tanpa langganan bulanan. Kami hanya berbagi dari pesanan yang selesai — dan semua rinciannya dijelaskan sebelum kamu menandatangani apa pun.',
      'p.q2': 'Siapa yang mengantar pesanan?',
      'p.a2': 'Kurir kami. Kamu tak perlu kurir, motor, atau asuransi mereka — kurir datang ke pintumu, mengambil, dan mengantar.',
      'p.q3': 'Bagaimana pesanan sampai ke saya?',
      'p.a3': 'Lewat aplikasi restoran. Pesanan muncul di layarmu lengkap dengan item dan nilainya; kamu terima atau tolak dengan alasan yang dilihat pelanggan.',
      'p.q4': 'Bagaimana kalau saya ingin tutup sehari atau sejam?',
      'p.a4': 'Setel status “tutup” di aplikasi dan pesanan langsung berhenti — tak ada yang bisa memesan darimu saat tutup, baik dari aplikasi maupun situs.',
      'p.q5': 'Kapan saya menerima hak saya?',
      'p.a5': 'Hakmu diselesaikan dalam siklus berkala, dirinci baris per baris: nilai pesananmu, apa yang dipotong, dan bersihnya. Siklusnya disepakati bersamamu.'
    }
  };


  /* ── صفحة تحميل التطبيق ── */
  PAGES.app = {
    ar: { 'a.h1': 'حمّل تطبيق <span>المطعم</span>',
          'a.lede': 'شاشة طلباتك: الطلب يصل مطبخك لحظة وقوعه، تقبله وتحضّره وتسلّمه للكابتن — ومستحقاتك بحساب مكشوف أمامك سطراً سطراً.',
          'a.dl': '⬇️ تحميل للأندرويد', 'a.size': 'ملف APK — لأي جوّال أندرويد',
          'a.soon': 'التطبيق قريباً — تواصل معنا', 'a.soond': 'نُعلن هنا فور جاهزيته للتنزيل.',
          'a.how': 'كيف تثبّته؟',
          'a.s1': 'اضغط زرّ التحميل أعلاه، وانتظر انتهاء التنزيل.',
          'a.s2': 'افتح الملف من إشعار التنزيل أو من مجلّد «التنزيلات».',
          'a.s3': 'سيسألك جوّالك السماح بالتثبيت من هذا المصدر — اسمح له مرّةً واحدة.',
          'a.s4': 'أكمل التثبيت، ثم ادخل بحساب مطعمك الذي زوّدناك به.',
          'a.warn': '<b>ثلاثة أمور نصارحك بها:</b> التطبيق لا يُحدَّث نفسه تلقائياً بعد — سنخبرك حين تصدر نسخة جديدة. وقد يعرض جوّالك تحذيراً لأن الملف من خارج المتجر، وهو تحذيرٌ عام لا يخصّنا. ولا تُنزّله من أي مكانٍ غير هذه الصفحة.',
          'a.new': 'لم تنضمّ بعد؟', 'a.newd': 'التطبيق لا يفتح إلا بحساب مطعمٍ مقبول. سجّل مطعمك أولاً، ونرسل لك بيانات دخولك.',
          'a.newcta': 'ضمّ مطعمك الآن ←',
          'a.ios': 'آيفون؟', 'a.iosd': 'نعمل على نسخة الآيفون. وحتى تصدر، أي جوّال أندرويد أو تابلت أندرويد عندك — ولو قديماً — يصلح شاشةَ طلبات، وهذا ما يستعمله شركاؤنا اليوم.',
          'a.other': 'أنت كابتن أو عميل؟', 'a.otherd': 'للكابتن تطبيقه، ويصلك مع بيانات دخولك بعد قبول طلب انضمامك — <a href="/join/">ابدأ من هنا</a>. وللعميل لا تطبيق يُحمَّل: يطلب من متصفّح جوّاله مباشرة.',
          'say.h2': 'عندك ملاحظة على التطبيق؟', 'say.d': 'قُلها لنا بصراحة — ما ينقصه، وما يزعجك فيه، وما تتمنّى أن نضيفه. نقرأ كل ما يصلنا، وبياناتك اختيارية كلها.',
          'say.open': '💡 اكتب ملاحظتك ←' },
    en: { 'a.h1': 'Download the <span>restaurant</span> app',
          'a.lede': 'Your orders screen: every order reaches your kitchen the moment it is placed \u2014 you accept it, prepare it, hand it to the captain, and your earnings stay itemized line by line.',
          'a.dl': '⬇️ Download for Android', 'a.size': 'APK file \u2014 for any Android phone',
          'a.soon': 'App coming soon \u2014 contact us', 'a.soond': 'We will announce it here the moment it is ready.',
          'a.how': 'How to install it',
          'a.s1': 'Tap the download button above and wait for it to finish.',
          'a.s2': 'Open the file from the download notification or your \u201cDownloads\u201d folder.',
          'a.s3': 'Your phone will ask permission to install from this source \u2014 allow it once.',
          'a.s4': 'Finish the installation, then sign in with the restaurant account we gave you.',
          'a.warn': '<b>Three things we will be honest about:</b> the app does not update itself yet \u2014 we will tell you when a new version is out. Your phone may show a warning because the file is from outside the store; that warning is generic, not about us. And do not download it from anywhere but this page.',
          'a.new': 'Not a partner yet?', 'a.newd': 'The app only opens with an approved restaurant account. List your restaurant first and we will send you your sign-in details.',
          'a.newcta': 'List your restaurant \u2192',
          'a.ios': 'On iPhone?', 'a.iosd': 'We are working on the iPhone version. Until it is out, any Android phone or tablet you already own \u2014 even an old one \u2014 works as an orders screen, and that is what our partners use today.',
          'a.other': 'Are you a captain or a customer?', 'a.otherd': 'Captains have their own app; it reaches you with your sign-in details once your application is approved \u2014 <a href="/join/">start here</a>. Customers install nothing: they order straight from their phone browser.',
          'say.h2': 'Have a note about the app?', 'say.d': 'Tell us plainly — what is missing, what annoys you, what you wish we would add. We read everything, and your details are entirely optional.',
          'say.open': '💡 Write your note →' },
    bn: { 'a.h1': '<span>রেস্টুরেন্ট</span> অ্যাপ ডাউনলোড করুন',
          'a.lede': 'আপনার অর্ডার স্ক্রিন: অর্ডার হওয়া মাত্র রান্নাঘরে পৌঁছায় — আপনি গ্রহণ করেন, প্রস্তুত করেন, ক্যাপ্টেনকে দেন, আর আপনার প্রাপ্য লাইন ধরে স্পষ্ট থাকে।',
          'a.dl': '⬇️ অ্যান্ড্রয়েডের জন্য ডাউনলোড', 'a.size': 'APK ফাইল — যেকোনো অ্যান্ড্রয়েড ফোনে',
          'a.soon': 'অ্যাপ শীঘ্রই — যোগাযোগ করুন', 'a.soond': 'প্রস্তুত হওয়া মাত্র এখানেই জানাব।',
          'a.how': 'কীভাবে ইনস্টল করবেন',
          'a.s1': 'উপরের ডাউনলোড বোতামে চাপুন এবং শেষ হওয়া পর্যন্ত অপেক্ষা করুন।',
          'a.s2': 'ডাউনলোড নোটিফিকেশন বা “Downloads” ফোল্ডার থেকে ফাইলটি খুলুন।',
          'a.s3': 'ফোন এই উৎস থেকে ইনস্টলের অনুমতি চাইবে — একবার অনুমতি দিন।',
          'a.s4': 'ইনস্টল শেষ করুন, তারপর আমাদের দেওয়া রেস্টুরেন্ট অ্যাকাউন্ট দিয়ে সাইন ইন করুন।',
          'a.warn': '<b>তিনটি কথা খোলাখুলি:</b> অ্যাপ এখনো নিজে নিজে আপডেট হয় না — নতুন সংস্করণ এলে আমরা জানাব। ফাইলটি স্টোরের বাইরের বলে ফোন একটি সতর্কবার্তা দেখাতে পারে; সেটি সাধারণ বার্তা, আমাদের নিয়ে নয়। আর এই পেজ ছাড়া অন্য কোথাও থেকে ডাউনলোড করবেন না।',
          'a.new': 'এখনো যুক্ত হননি?', 'a.newd': 'অনুমোদিত রেস্টুরেন্ট অ্যাকাউন্ট ছাড়া অ্যাপ খোলে না। আগে আপনার রেস্টুরেন্ট যুক্ত করুন, আমরা লগইন তথ্য পাঠিয়ে দেব।',
          'a.newcta': 'আপনার রেস্টুরেন্ট যুক্ত করুন →',
          'a.ios': 'আইফোনে?', 'a.iosd': 'আইফোন সংস্করণে কাজ চলছে। ততক্ষণ আপনার যেকোনো অ্যান্ড্রয়েড ফোন বা ট্যাবলেট — পুরোনো হলেও — অর্ডার স্ক্রিন হিসেবে চলে, আমাদের পার্টনাররা আজ সেটিই ব্যবহার করেন।',
          'a.other': 'আপনি ক্যাপ্টেন না গ্রাহক?', 'a.otherd': 'ক্যাপ্টেনের নিজের অ্যাপ আছে; আবেদন অনুমোদিত হলে লগইন তথ্যসহ পৌঁছে যাবে — <a href="/join/">এখান থেকে শুরু করুন</a>। গ্রাহকের কিছু ইনস্টল করার দরকার নেই: ফোনের ব্রাউজার থেকেই অর্ডার করেন।',
          'say.h2': 'অ্যাপ নিয়ে কিছু বলার আছে?', 'say.d': 'খোলাখুলি বলুন — কী নেই, কী বিরক্ত করে, কী যোগ করতে চান। আমরা সব পড়ি, আর আপনার তথ্য পুরোপুরি ঐচ্ছিক।',
          'say.open': '💡 আপনার মতামত লিখুন →' },
    ur: { 'a.h1': '<span>ریستوران</span> ایپ ڈاؤن لوڈ کریں',
          'a.lede': 'آپ کی آرڈر اسکرین: آرڈر ہوتے ہی آپ کے کچن پہنچتا ہے — آپ قبول کرتے ہیں، تیار کرتے ہیں، کیپٹن کے حوالے کرتے ہیں، اور آپ کی رقم سطر بہ سطر واضح رہتی ہے۔',
          'a.dl': '⬇️ اینڈرائیڈ کے لیے ڈاؤن لوڈ', 'a.size': 'APK فائل — کسی بھی اینڈرائیڈ فون کے لیے',
          'a.soon': 'ایپ جلد آ رہی ہے — ہم سے رابطہ کریں', 'a.soond': 'تیار ہوتے ہی یہیں اعلان کریں گے۔',
          'a.how': 'انسٹال کیسے کریں',
          'a.s1': 'اوپر ڈاؤن لوڈ کے بٹن پر دبائیں اور مکمل ہونے کا انتظار کریں۔',
          'a.s2': 'ڈاؤن لوڈ نوٹیفکیشن یا «Downloads» فولڈر سے فائل کھولیں۔',
          'a.s3': 'فون اس ذریعے سے انسٹال کی اجازت مانگے گا — ایک بار اجازت دے دیں۔',
          'a.s4': 'انسٹال مکمل کریں، پھر ہمارے دیے ہوئے ریستوران اکاؤنٹ سے سائن اِن کریں۔',
          'a.warn': '<b>تین باتیں صاف صاف:</b> ایپ ابھی خود بخود اپ ڈیٹ نہیں ہوتی — نئی نسخہ آنے پر ہم بتا دیں گے۔ فائل سٹور سے باہر کی ہونے کی وجہ سے فون ایک انتباہ دکھا سکتا ہے؛ یہ عام انتباہ ہے، ہمارے بارے میں نہیں۔ اور اس صفحے کے سوا کہیں سے ڈاؤن لوڈ نہ کریں۔',
          'a.new': 'ابھی شامل نہیں ہوئے؟', 'a.newd': 'ایپ صرف منظور شدہ ریستوران اکاؤنٹ سے کھلتی ہے۔ پہلے اپنا ریستوران رجسٹر کریں، ہم آپ کو لاگ اِن تفصیلات بھیج دیں گے۔',
          'a.newcta': 'اپنا ریستوران شامل کریں ←',
          'a.ios': 'آئی فون پر؟', 'a.iosd': 'آئی فون نسخے پر کام جاری ہے۔ تب تک آپ کا کوئی بھی اینڈرائیڈ فون یا ٹیبلٹ — پرانا ہی سہی — آرڈر اسکرین کے طور پر چلتا ہے، اور آج ہمارے شراکت دار یہی استعمال کرتے ہیں۔',
          'a.other': 'آپ کیپٹن ہیں یا گاہک؟', 'a.otherd': 'کیپٹن کی اپنی ایپ ہے؛ درخواست منظور ہوتے ہی لاگ اِن تفصیلات کے ساتھ آپ تک پہنچ جاتی ہے — <a href="/join/">یہاں سے شروع کریں</a>۔ گاہک کو کچھ انسٹال کرنے کی ضرورت نہیں: وہ اپنے فون کے براؤزر سے آرڈر کرتے ہیں۔',
          'say.h2': 'ایپ پر کوئی رائے ہے؟', 'say.d': 'صاف صاف بتائیں — کیا کمی ہے، کیا کھلتا ہے، اور کیا شامل کرنا چاہیں گے۔ ہم سب پڑھتے ہیں، اور آپ کی معلومات مکمل طور پر اختیاری ہیں۔',
          'say.open': '💡 اپنی رائے لکھیں ←' },
    id: { 'a.h1': 'Unduh aplikasi <span>restoran</span>',
          'a.lede': 'Layar pesananmu: pesanan masuk ke dapur seketika \u2014 kamu terima, siapkan, serahkan ke kurir, dan pendapatanmu tetap dirinci baris per baris.',
          'a.dl': '⬇️ Unduh untuk Android', 'a.size': 'Berkas APK \u2014 untuk ponsel Android apa pun',
          'a.soon': 'Aplikasi segera hadir \u2014 hubungi kami', 'a.soond': 'Kami umumkan di sini begitu siap.',
          'a.how': 'Cara memasangnya',
          'a.s1': 'Ketuk tombol unduh di atas dan tunggu sampai selesai.',
          'a.s2': 'Buka berkasnya dari notifikasi unduhan atau folder \u201cDownloads\u201d.',
          'a.s3': 'Ponselmu akan meminta izin memasang dari sumber ini \u2014 izinkan sekali.',
          'a.s4': 'Selesaikan pemasangan, lalu masuk dengan akun restoran yang kami berikan.',
          'a.warn': '<b>Tiga hal yang kami sampaikan terus terang:</b> aplikasi belum memperbarui dirinya sendiri \u2014 kami akan memberi tahu saat ada versi baru. Ponselmu mungkin menampilkan peringatan karena berkas berasal dari luar toko; itu peringatan umum, bukan tentang kami. Dan jangan mengunduhnya dari tempat lain selain halaman ini.',
          'a.new': 'Belum jadi mitra?', 'a.newd': 'Aplikasi hanya terbuka dengan akun restoran yang disetujui. Daftarkan restoranmu dulu, lalu kami kirimkan data masukmu.',
          'a.newcta': 'Daftarkan restoranmu \u2192',
          'a.ios': 'Pakai iPhone?', 'a.iosd': 'Versi iPhone sedang kami kerjakan. Sementara itu, ponsel atau tablet Android apa pun yang kamu punya \u2014 bahkan yang lama \u2014 bisa jadi layar pesanan, dan itulah yang dipakai mitra kami hari ini.',
          'a.other': 'Kamu kurir atau pelanggan?', 'a.otherd': 'Kurir punya aplikasi sendiri; dikirim beserta data masukmu setelah lamaranmu disetujui \u2014 <a href="/join/">mulai dari sini</a>. Pelanggan tidak memasang apa pun: mereka memesan langsung dari peramban ponsel.',
          'say.h2': 'Punya catatan soal aplikasinya?', 'say.d': 'Katakan terus terang — apa yang kurang, apa yang mengganggu, apa yang ingin kamu tambahkan. Kami baca semuanya, dan datamu sepenuhnya opsional.',
          'say.open': '💡 Tulis catatanmu →' }
  };

  /* ── صفحة 404 ── */
  PAGES.e404 = {
    ar: { 'e.h1': 'الصفحة غير موجودة', 'e.p': 'الرابط الذي فتحته غير صحيح أو حُذف.', 'e.back': '← العودة للصفحة الرئيسية' },
    en: { 'e.h1': 'Page not found', 'e.p': 'The link you opened is wrong or was removed.', 'e.back': '← Back to the home page' },
    bn: { 'e.h1': 'পেজ পাওয়া যায়নি', 'e.p': 'আপনি যে লিংক খুলেছেন তা ভুল বা মুছে ফেলা হয়েছে।', 'e.back': '← হোম পেজে ফিরুন' },
    ur: { 'e.h1': 'صفحہ نہیں ملا', 'e.p': 'آپ نے جو لنک کھولا وہ غلط ہے یا حذف ہو چکا۔', 'e.back': '← ہوم پیج پر واپس' },
    id: { 'e.h1': 'Halaman tidak ditemukan', 'e.p': 'Tautan yang kamu buka salah atau sudah dihapus.', 'e.back': '← Kembali ke beranda' }
  };

  /* ── التواصل والدعم ── */
  PAGES.contact = {
    ar: { 'c.h1': 'التواصل والدعم',
          'c.lead': 'فريق زادقو (ZadGo) جاهز لمساعدتك. لأي استفسار أو مشكلة تقنية أو طلب دعم، تواصل معنا عبر الجوال أو البريد الإلكتروني ونردّ عليك في أقرب وقت.',
          'c.box': 'معلومات التواصل', 'c.phone': 'الجوال', 'c.wa': 'واتساب', 'c.email': 'البريد الإلكتروني',
          'c.site': 'الموقع', 'c.op': 'الجهة المشغّلة', 'c.opv': 'المملكة العربية السعودية',
          'c.h2': 'ما الذي نساعدك فيه؟',
          'c.l1': 'الاستفسار عن حالة طلب أو مشكلة في التوصيل.',
          'c.l2': 'مشكلات الحساب والدخول.',
          'c.l3': 'طلبات حذف الحساب والاطلاع على بياناتك.',
          'c.l4': 'انضمام المطاعم إلى المنصة، أو تسجيل الكباتن.',
          'c.l5': 'الشكاوى والملاحظات.',
          'c.l6': 'الكباتن المسجّلون: متابعة الأرباح والدفتر وطلب السحب من بوّابة الكابتن.',
          'c.tip': '<b>لتسريع الرد:</b> اذكر في رسالتك رقم الطلب إن وُجد، والبريد الإلكتروني أو رقم الجوال المسجَّل في حسابك، ووصفاً مختصراً للمشكلة.',
          'c.app': 'وللعملاء المسجّلين: تتوفر داخل التطبيق صفحة <b>«شكاواي»</b> لفتح شكوى مرتبطة بطلب معيّن ومتابعة الرد عليها مباشرة.' },
    en: { 'c.h1': 'Contact & support',
          'c.lead': 'The ZadGo team is here to help. For any question, technical problem or support request, reach us by phone or email and we will reply as soon as we can.',
          'c.box': 'Contact details', 'c.phone': 'Mobile', 'c.wa': 'WhatsApp', 'c.email': 'Email',
          'c.site': 'Website', 'c.op': 'Operated by', 'c.opv': 'Saudi Arabia',
          'c.h2': 'What we can help with',
          'c.l1': 'Questions about an order or a delivery problem.',
          'c.l2': 'Account and sign-in problems.',
          'c.l3': 'Account deletion requests and access to your data.',
          'c.l4': 'Restaurants joining the platform, or captain registration.',
          'c.l5': 'Complaints and feedback.',
          'c.l6': 'Registered captains: earnings, ledger and payout requests from the captain portal.',
          'c.tip': '<b>To get a faster reply:</b> include the order number if any, the email or mobile registered on your account, and a short description of the problem.',
          'c.app': 'For registered customers: the app has a <b>“My complaints”</b> page to open a complaint tied to a specific order and follow the reply directly.' },
    bn: { 'c.h1': 'যোগাযোগ ও সাপোর্ট',
          'c.lead': 'ZadGo টিম আপনাকে সাহায্য করতে প্রস্তুত। যেকোনো প্রশ্ন, কারিগরি সমস্যা বা সহায়তার জন্য ফোন বা ইমেইলে যোগাযোগ করুন, আমরা দ্রুত উত্তর দেব।',
          'c.box': 'যোগাযোগের তথ্য', 'c.phone': 'মোবাইল', 'c.wa': 'হোয়াটসঅ্যাপ', 'c.email': 'ইমেইল',
          'c.site': 'ওয়েবসাইট', 'c.op': 'পরিচালনায়', 'c.opv': 'সৌদি আরব',
          'c.h2': 'আমরা কী সাহায্য করতে পারি',
          'c.l1': 'অর্ডারের অবস্থা বা ডেলিভারির সমস্যা।',
          'c.l2': 'অ্যাকাউন্ট ও লগইনের সমস্যা।',
          'c.l3': 'অ্যাকাউন্ট মোছার অনুরোধ ও নিজের তথ্য দেখা।',
          'c.l4': 'রেস্টুরেন্ট যুক্ত হওয়া, বা ক্যাপ্টেন নিবন্ধন।',
          'c.l5': 'অভিযোগ ও মতামত।',
          'c.l6': 'নিবন্ধিত ক্যাপ্টেন: ক্যাপ্টেন পোর্টাল থেকে আয়, হিসাব ও টাকা তোলার অনুরোধ।',
          'c.tip': '<b>দ্রুত উত্তরের জন্য:</b> অর্ডার নম্বর (থাকলে), অ্যাকাউন্টে নিবন্ধিত ইমেইল বা মোবাইল, এবং সমস্যার সংক্ষিপ্ত বর্ণনা লিখুন।',
          'c.app': 'নিবন্ধিত গ্রাহকদের জন্য: অ্যাপে <b>“আমার অভিযোগ”</b> পেজ আছে — নির্দিষ্ট অর্ডারের সঙ্গে অভিযোগ খুলে সরাসরি উত্তর দেখা যায়।' },
    ur: { 'c.h1': 'رابطہ اور مدد',
          'c.lead': 'ZadGo کی ٹیم آپ کی مدد کے لیے حاضر ہے۔ کسی بھی سوال، تکنیکی مسئلے یا مدد کے لیے فون یا ای میل پر رابطہ کریں، ہم جلد جواب دیں گے۔',
          'c.box': 'رابطے کی تفصیل', 'c.phone': 'موبائل', 'c.wa': 'واٹس ایپ', 'c.email': 'ای میل',
          'c.site': 'ویب سائٹ', 'c.op': 'چلانے والا ادارہ', 'c.opv': 'سعودی عرب',
          'c.h2': 'ہم کن کاموں میں مدد کرتے ہیں',
          'c.l1': 'آرڈر کی حالت یا ڈیلیوری کا مسئلہ۔',
          'c.l2': 'اکاؤنٹ اور لاگ اِن کے مسائل۔',
          'c.l3': 'اکاؤنٹ حذف کرنے کی درخواست اور اپنا ڈیٹا دیکھنا۔',
          'c.l4': 'ریستورانوں کا شامل ہونا، یا کیپٹن کی رجسٹریشن۔',
          'c.l5': 'شکایات اور آرا۔',
          'c.l6': 'رجسٹرڈ کیپٹن: کیپٹن پورٹل سے کمائی، کھاتہ اور رقم نکالنے کی درخواست۔',
          'c.tip': '<b>جلد جواب کے لیے:</b> آرڈر نمبر (اگر ہو)، اکاؤنٹ پر رجسٹرڈ ای میل یا موبائل، اور مسئلے کی مختصر تفصیل لکھیں۔',
          'c.app': 'رجسٹرڈ گاہکوں کے لیے: ایپ میں <b>«میری شکایات»</b> صفحہ ہے — کسی مخصوص آرڈر سے شکایت کھول کر جواب براہِ راست دیکھیں۔' },
    id: { 'c.h1': 'Kontak & dukungan',
          'c.lead': 'Tim ZadGo siap membantu. Untuk pertanyaan, masalah teknis, atau permintaan bantuan, hubungi kami lewat telepon atau email dan kami balas secepatnya.',
          'c.box': 'Info kontak', 'c.phone': 'Ponsel', 'c.wa': 'WhatsApp', 'c.email': 'Email',
          'c.site': 'Situs', 'c.op': 'Dioperasikan oleh', 'c.opv': 'Arab Saudi',
          'c.h2': 'Yang bisa kami bantu',
          'c.l1': 'Pertanyaan soal status pesanan atau masalah pengiriman.',
          'c.l2': 'Masalah akun dan masuk.',
          'c.l3': 'Permintaan hapus akun dan melihat datamu.',
          'c.l4': 'Restoran bergabung ke platform, atau pendaftaran kurir.',
          'c.l5': 'Keluhan dan masukan.',
          'c.l6': 'Kurir terdaftar: penghasilan, buku catatan, dan penarikan lewat portal kurir.',
          'c.tip': '<b>Agar cepat dibalas:</b> sebutkan nomor pesanan (bila ada), email atau ponsel yang terdaftar di akunmu, dan penjelasan singkat masalahnya.',
          'c.app': 'Untuk pelanggan terdaftar: di aplikasi ada halaman <b>“Keluhan saya”</b> untuk membuka keluhan terkait pesanan tertentu dan melihat balasannya langsung.' }
  };

  /* ── الصفحات القانونية: تنبيهٌ بلغة الزائر، والنصّ يبقى عربياً ──
     ترجمةُ نصٍّ قانوني تُنشئ نسختين قد تفترقان، والمحتجُّ بها عند نزاعٍ
     واحدة. فالأصحّ إخبار الزائر بلغته أن العربية هي المعتمدة، ودلالته
     على الدعم إن احتاج شرحاً — لا ترجمةٌ تبدو ملزِمة وليست كذلك. */
  PAGES.legal = {
    ar: { 'g.notice': 'هذه الصفحة بالعربية، وهي النسخة المعتمدة. لأي استفسار <a href="/contact.html">تواصل معنا</a>.' },
    en: { 'g.notice': 'This page is in Arabic, which is the binding version. For any question, <a href="/contact.html">contact us</a> and we will explain it in English.' },
    bn: { 'g.notice': 'এই পেজটি আরবিতে, এবং আরবি সংস্করণই কার্যকর। কোনো প্রশ্ন থাকলে <a href="/contact.html">যোগাযোগ করুন</a>, আমরা বুঝিয়ে দেব।' },
    ur: { 'g.notice': 'یہ صفحہ عربی میں ہے، اور عربی نسخہ ہی معتبر ہے۔ کسی سوال کے لیے <a href="/contact.html">ہم سے رابطہ کریں</a>، ہم وضاحت کر دیں گے۔' },
    id: { 'g.notice': 'Halaman ini berbahasa Arab, dan versi Arab yang mengikat. Ada pertanyaan? <a href="/contact.html">Hubungi kami</a> dan kami jelaskan.' }
  };

  /* ═══ المحرّك ═══ */
  var page = document.documentElement.getAttribute('data-i18n-page') || '';
  var loaded = {};

  function needFont(l) {
    if (loaded[l]) return;
    var url = l === 'bn' ? 'https://fonts.googleapis.com/css2?family=Noto+Sans+Bengali:wght@400;700;800&display=swap'
            : l === 'ur' ? 'https://fonts.googleapis.com/css2?family=Noto+Nastaliq+Urdu:wght@400;700&display=swap'
            : null;
    if (!url) return;
    var lk = document.createElement('link');
    lk.rel = 'stylesheet'; lk.href = url;
    document.head.appendChild(lk);
    loaded[l] = 1;
  }

  // قواعد الخطّ لكل لغة تُحقن مرّةً واحدة — أخفّ من تكرارها في كل صفحة.
  var st = document.createElement('style');
  st.textContent =
    "body.lang-bn,body.lang-bn button,body.lang-bn select,body.lang-bn input," +
    "body.lang-bn h1,body.lang-bn h2,body.lang-bn h3" +
    "{font-family:'Noto Sans Bengali','IBM Plex Sans Arabic',sans-serif}" +
    "body.lang-ur,body.lang-ur button,body.lang-ur select,body.lang-ur input," +
    "body.lang-ur h1,body.lang-ur h2,body.lang-ur h3" +
    "{font-family:'Noto Nastaliq Urdu','IBM Plex Sans Arabic',sans-serif}" +
    "body.lang-ur{line-height:2.2}body.lang-ur h1,body.lang-ur h2{line-height:1.9}" +
    "#langSel{font:inherit;font-size:.8rem;font-weight:700;cursor:pointer;" +
    "border-radius:999px;padding:7px 12px;background:rgba(255,255,255,.08);" +
    "color:#fff;border:1px solid rgba(255,255,255,.2)}" +
    "#langSel option{color:#111;background:#fff}";
  document.head.appendChild(st);

  function dict(l) {
    var out = {}, k;
    var a = COMMON[l] || {}, b = (PAGES[page] || {})[l] || {};
    for (k in a) out[k] = a[k];
    for (k in b) out[k] = b[k];
    return out;
  }

  function apply(l) {
    if (!NAMES[l]) l = 'ar';
    needFont(l);
    var d = dict(l);
    document.querySelectorAll('[data-i18n]').forEach(function (el) {
      var v = d[el.getAttribute('data-i18n')];
      if (v != null) el.innerHTML = v;
    });
    document.querySelectorAll('[data-i18n-ph]').forEach(function (el) {
      var v = d[el.getAttribute('data-i18n-ph')];
      if (v != null) el.setAttribute('placeholder', v);
    });
    document.documentElement.lang = l;
    document.documentElement.dir = RTL[l] ? 'rtl' : 'ltr';
    document.body.className = document.body.className
      .replace(/\blang-\w+\b/g, '').trim() + ' lang-' + l;
    var sel = document.getElementById('langSel');
    if (sel) sel.value = l;
    try { localStorage.setItem('zadgo-lang', l); } catch (e) {}
    // تُبلَّغ الصفحة كي تعيد رسم ما بناه سكربتها (المستندات، الصور…)
    document.dispatchEvent(new CustomEvent('zadgo:lang', { detail: { lang: l, t: d } }));
  }

  function build() {
    var slot = document.querySelector('[data-langslot]');
    var sel = document.getElementById('langSel');
    if (!sel && slot) {
      sel = document.createElement('select');
      sel.id = 'langSel';
      sel.setAttribute('aria-label', 'Language');
      // هدف لمسٍ ٤٤px: المنتقى يُبنى هنا بلا أنماط في صفحاتٍ لا CSS
      // فيها له، فيرث ارتفاع المتصفّح الافتراضي (٣٣px) ويسقط تحت الحدّ.
      sel.style.minHeight = '44px';
      sel.style.padding = '0 10px';
      ORDER.forEach(function (l) {
        var o = document.createElement('option');
        o.value = l; o.textContent = NAMES[l];
        sel.appendChild(o);
      });
      slot.appendChild(sel);
    }
    if (sel) sel.addEventListener('change', function () { apply(sel.value); });
    var saved = 'ar';
    try { saved = localStorage.getItem('zadgo-lang') || 'ar'; } catch (e) {}
    apply(saved);
  }

  // يُنادى بعد بناء الصفحة كي يجد عناصرها موجودة.
  if (document.readyState === 'loading')
    document.addEventListener('DOMContentLoaded', build);
  else build();

  window.ZadLang = { t: function (k) { var d = dict(document.documentElement.lang || 'ar'); return d[k]; } };
})();
