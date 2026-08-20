/* ════════════════ صندوق «قل لنا» — نصائح الزائر واقتراحاته ════════════════
 *
 * صندوقٌ حواريّ يُفتح من أي صفحة، يكتب فيه الزائر ملاحظته على التطبيق أو
 * الخدمة، ويعرض معلوماته **اختياراً لا شرطاً**: من هو، وكيف نصله إن أردنا
 * أن نسأله. والاختيارية مقصودة — أكثر الملاحظات الصادقة تأتي ممن لا يريد
 * أن يُعرَّف، واشتراط الاسم يقتل نصفها قبل أن تُكتب.
 *
 * ── لماذا REST لا حزمة Firebase؟ ─────────────────────────────────────
 * الحزمة تحتاج `script-src https://www.gstatic.com` في كل صفحة يظهر فيها
 * الصندوق — أي فتحُ مصدر سكربتٍ خارجي على الصفحة الرئيسية والقانونية،
 * وهي صفحاتٌ لا تشغّل شيئاً خارجياً اليوم. وبضع عشرات من الأسطر بـfetch
 * تؤدي العمل نفسه، فلا يتغيّر من سياسة المحتوى إلا `connect-src`: عنوانان
 * محدَّدان بدل `'none'`. والحزمة فوق ذلك مئات الكيلوبايتات على صفحةٍ لا
 * تحتاجها إلا لحظة الإرسال.
 *
 * ── والدخول مجهول ─────────────────────────────────────────────────────
 * القاعدة تشترط `isSignedIn()` كسائر مجموعات الكتابة العامة (طلب الانضمام،
 * طلب مطعم)، فتُنشأ هوية مجهولة **لحظة الإرسال لا عند فتح الصفحة**: زائرٌ
 * يقرأ ولا يكتب لا يُنشأ له حساب، ولا يُستهلك حصةُ مصادقةٍ بلا سبب.
 *
 * ── وقتُ الإنشاء من ساعة الزائر ────────────────────────────────────────
 * REST لا يكتب `serverTimestamp` في إنشاءٍ واحد (يحتاج `:commit` بتحويل
 * حقلٍ منفصل، وتقييم القواعد عليه ملتبس). وساعةٌ منحرفة هنا تُخرج اقتراحاً
 * عن ترتيبه في القائمة ولا تمسّ ريالاً — بخلاف الطلبات والحوافز حيث
 * يُشترط ختم الخادم. ولهذا يُكتب `clientTime: true` صراحةً مع المستند،
 * فتعرف اللوحة أن الوقت من جهاز الزائر لا من الخادم.
 */
(function () {
  'use strict';

  var PROJECT = 'restaurant-app-ed699';
  var KEY = 'AIzaSyBoAvj7C2vJyzERVnK26Oa-dJZ1mV0vO6g';
  var IDP = 'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=' + KEY;
  var FS = 'https://firestore.googleapis.com/v1/projects/' + PROJECT +
           '/databases/(default)/documents/suggestions';

  var MAX = 2000;   // نفس سقف القاعدة — الحدّ هنا للراحة، وهناك للحماية
  var MIN = 5;
  var COOL = 60000; // ثانية واحدة لا تكفي لمنع ضغطتين متتاليتين بالخطأ

  /* ── الترجمة ── */
  var T = {
    ar: { open: '💡 اقترح علينا', title: 'قل لنا رأيك',
      lede: 'نصيحتك أو ملاحظتك على التطبيق أو الخدمة — نقرأها كلها، ونعمل بأكثرها.',
      ph: 'اكتب هنا… ما الذي أعجبك؟ وما الذي أزعجك؟ وما الذي تتمنّى أن نضيفه؟',
      who: 'من أنت؟ (اختياري)', w0: 'أفضّل ألا أقول', w1: 'عميل', w2: 'صاحب مطعم',
      w3: 'كابتن', w4: 'مهتمّ بالفكرة',
      opt: 'معلوماتك — اختيارية كلها', optd: 'اتركها فارغة إن شئت. نطلبها لأمرٍ واحد: أن نعود إليك إن احتجنا تفصيلاً، أو نبشّرك حين نُنفّذ اقتراحك.',
      name: 'اسمك', namep: 'كما تحبّ أن نناديك',
      contact: 'جوّال أو بريد', contactp: '05… أو name@example.com',
      send: 'أرسل', sending: 'جارٍ الإرسال…', cancel: 'إغلاق',
      ok: 'وصلَتنا — شكراً لك 🌟', okd: 'نقرأ كل ما يصلنا بأنفسنا. وإن تركت وسيلة تواصل فقد نعود إليك.',
      eShort: 'اكتب سطراً على الأقل قبل الإرسال.',
      eLong: 'النصّ أطول من المسموح — اختصره قليلاً.',
      eCool: 'وصلَتنا ملاحظتك قبل قليل. أرسل التالية بعد دقيقة.',
      eNet: 'تعذّر الإرسال. تحقّق من الإنترنت وحاول مرّة أخرى.',
      eOff: 'باب الملاحظات يُفتح قريباً — وحتى ذلك الحين تواصل معنا مباشرة.',
      priv: 'لا نطلب شيئاً غير ما تكتبه هنا، ولا نستعمله في إعلان.' },
    en: { open: '💡 Send us a suggestion', title: 'Tell us what you think',
      lede: 'Your advice or note about the app or the service — we read every one.',
      ph: 'Write here… what worked? what annoyed you? what would you like us to add?',
      who: 'Who are you? (optional)', w0: 'Rather not say', w1: 'A customer',
      w2: 'A restaurant owner', w3: 'A captain', w4: 'Just interested',
      opt: 'Your details — all optional',
      optd: 'Leave them empty if you like. We ask for one reason only: to come back to you if we need a detail, or to tell you when we build what you suggested.',
      name: 'Your name', namep: 'Whatever you like to be called',
      contact: 'Phone or email', contactp: '05… or name@example.com',
      send: 'Send', sending: 'Sending…', cancel: 'Close',
      ok: 'Received — thank you 🌟', okd: 'We read everything ourselves. If you left a contact we may get back to you.',
      eShort: 'Write at least a line before sending.',
      eLong: 'That is longer than allowed — please shorten it a little.',
      eCool: 'We just received your note. Send the next one in a minute.',
      eNet: 'Could not send. Check your connection and try again.',
      eOff: 'The suggestions box opens soon — until then, contact us directly.',
      priv: 'We ask for nothing beyond what you write here, and we do not use it in advertising.' },
    bn: { open: '💡 পরামর্শ দিন', title: 'আপনার মতামত জানান',
      lede: 'অ্যাপ বা সেবা নিয়ে আপনার পরামর্শ — আমরা সবই পড়ি।',
      ph: 'এখানে লিখুন… কী ভালো লেগেছে? কী বিরক্ত করেছে? কী যোগ করতে চান?',
      who: 'আপনি কে? (ঐচ্ছিক)', w0: 'বলতে চাই না', w1: 'গ্রাহক',
      w2: 'রেস্টুরেন্ট মালিক', w3: 'ক্যাপ্টেন', w4: 'শুধু আগ্রহী',
      opt: 'আপনার তথ্য — সবই ঐচ্ছিক',
      optd: 'ইচ্ছে হলে খালি রাখুন। একটাই কারণে চাই: বিস্তারিত জানার দরকার হলে বা আপনার পরামর্শ বাস্তবায়ন হলে জানাতে।',
      name: 'আপনার নাম', namep: 'যে নামে ডাকলে ভালো লাগে',
      contact: 'ফোন বা ইমেইল', contactp: '05… বা name@example.com',
      send: 'পাঠান', sending: 'পাঠানো হচ্ছে…', cancel: 'বন্ধ করুন',
      ok: 'পেয়েছি — ধন্যবাদ 🌟', okd: 'আমরা নিজেরাই সব পড়ি। যোগাযোগ দিলে ফিরে আসতে পারি।',
      eShort: 'পাঠানোর আগে অন্তত এক লাইন লিখুন।',
      eLong: 'অনুমোদিত সীমার চেয়ে বড় — একটু ছোট করুন।',
      eCool: 'একটু আগেই আপনার মতামত পেয়েছি। পরেরটি এক মিনিট পরে পাঠান।',
      eNet: 'পাঠানো যায়নি। সংযোগ দেখে আবার চেষ্টা করুন।',
      eOff: 'মতামতের বাক্স শীঘ্রই খুলছে — ততক্ষণ সরাসরি যোগাযোগ করুন।',
      priv: 'আপনি যা লেখেন তার বাইরে কিছু চাই না, আর বিজ্ঞাপনে ব্যবহার করি না।' },
    ur: { open: '💡 تجویز بھیجیں', title: 'اپنی رائے بتائیں',
      lede: 'ایپ یا سروس پر آپ کا مشورہ — ہم سب پڑھتے ہیں۔',
      ph: 'یہاں لکھیں… کیا اچھا لگا؟ کیا برا لگا؟ ہم کیا شامل کریں؟',
      who: 'آپ کون ہیں؟ (اختیاری)', w0: 'نہیں بتانا چاہتا', w1: 'گاہک',
      w2: 'ریستوران مالک', w3: 'کیپٹن', w4: 'صرف دلچسپی ہے',
      opt: 'آپ کی معلومات — سب اختیاری',
      optd: 'چاہیں تو خالی چھوڑ دیں۔ صرف ایک وجہ سے مانگتے ہیں: تفصیل درکار ہو تو رابطہ کریں، یا آپ کی تجویز پر عمل ہو تو خوشخبری دیں۔',
      name: 'آپ کا نام', namep: 'جس نام سے پکارنا پسند ہو',
      contact: 'فون یا ای میل', contactp: '05… یا name@example.com',
      send: 'بھیجیں', sending: 'بھیجا جا رہا ہے…', cancel: 'بند کریں',
      ok: 'موصول ہوئی — شکریہ 🌟', okd: 'ہم خود سب پڑھتے ہیں۔ رابطہ چھوڑا ہو تو واپس آ سکتے ہیں۔',
      eShort: 'بھیجنے سے پہلے کم از کم ایک سطر لکھیں۔',
      eLong: 'یہ اجازت سے زیادہ لمبا ہے — تھوڑا مختصر کریں۔',
      eCool: 'ابھی ابھی آپ کی رائے ملی ہے۔ اگلی ایک منٹ بعد بھیجیں۔',
      eNet: 'بھیجا نہ جا سکا۔ انٹرنیٹ دیکھ کر دوبارہ کوشش کریں۔',
      eOff: 'رائے کا خانہ جلد کھلے گا — تب تک ہم سے براہِ راست رابطہ کریں۔',
      priv: 'آپ جو لکھیں اس کے سوا کچھ نہیں مانگتے، اور اشتہار میں استعمال نہیں کرتے۔' },
    id: { open: '💡 Kirim saran', title: 'Sampaikan pendapatmu',
      lede: 'Saran atau catatanmu tentang aplikasi atau layanan — semuanya kami baca.',
      ph: 'Tulis di sini… apa yang kamu suka? apa yang mengganggu? apa yang ingin kami tambahkan?',
      who: 'Kamu siapa? (opsional)', w0: 'Lebih baik tidak bilang', w1: 'Pelanggan',
      w2: 'Pemilik restoran', w3: 'Kurir', w4: 'Sekadar tertarik',
      opt: 'Data kamu — semuanya opsional',
      optd: 'Boleh dikosongkan. Kami minta untuk satu alasan: menghubungimu bila perlu detail, atau mengabari saat saranmu kami wujudkan.',
      name: 'Namamu', namep: 'Sebutan yang kamu suka',
      contact: 'Telepon atau email', contactp: '05… atau name@example.com',
      send: 'Kirim', sending: 'Mengirim…', cancel: 'Tutup',
      ok: 'Sudah kami terima — terima kasih 🌟', okd: 'Kami membaca semuanya sendiri. Kalau kamu tinggalkan kontak, kami mungkin menghubungimu.',
      eShort: 'Tulis minimal satu baris sebelum mengirim.',
      eLong: 'Terlalu panjang — mohon dipersingkat sedikit.',
      eCool: 'Barusan kami menerima catatanmu. Kirim berikutnya semenit lagi.',
      eNet: 'Gagal mengirim. Periksa koneksi lalu coba lagi.',
      eOff: 'Kotak saran segera dibuka — sementara itu hubungi kami langsung.',
      priv: 'Kami tidak meminta apa pun selain yang kamu tulis, dan tidak memakainya untuk iklan.' },
  };

  function lang() {
    var l = document.documentElement.lang || 'ar';
    return T[l] ? l : 'ar';
  }
  function t(k) { return T[lang()][k] || T.ar[k] || ''; }

  /* ── الأنماط: تُحقن مرّةً واحدة، وبمتغيّرات الصفحة لا بألوانٍ مكرّرة ──
   * الصندوق يظهر فوق صفحاتٍ كحلية وأخرى بيضاء، فيقرأ ألوانه من متغيّرات
   * الهوية إن وُجدت ويسقط على قيم زادقو الثابتة إن غابت. */
  var CSS =
    '.zfb-btn{font:inherit;font-weight:800;cursor:pointer;border-radius:999px;' +
      'padding:11px 20px;border:1px solid rgba(255,255,255,.16);' +
      'background:rgba(255,255,255,.07);color:inherit}' +
    'dialog.zfb{border:0;padding:0;background:transparent;max-width:min(560px,92vw);width:100%;max-height:92dvh;margin:auto}' +
    'dialog.zfb::backdrop{background:rgba(6,14,32,.72);backdrop-filter:blur(3px)}' +
    '.zfb-box{background:#13224A;color:#E7EEFA;border:1px solid rgba(255,255,255,.13);' +
      'border-radius:22px;padding:22px;font-family:inherit;line-height:1.85;' +
      'max-height:92dvh;overflow:auto;-webkit-overflow-scrolling:touch}' +
    '.zfb-box h2{font-size:1.25rem;font-weight:800;margin:0 0 6px;color:#fff}' +
    '.zfb-lede{color:#9DAEC9;font-size:.92rem;margin-bottom:14px}' +
    '.zfb-box label{display:block;font-weight:700;font-size:.88rem;margin:12px 0 6px;color:#fff}' +
    '.zfb-box textarea,.zfb-box input,.zfb-box select{width:100%;box-sizing:border-box;' +
      'font:inherit;font-size:.95rem;border-radius:14px;padding:12px 14px;' +
      'background:rgba(255,255,255,.06);color:#E7EEFA;' +
      'border:1px solid rgba(255,255,255,.16)}' +
    '.zfb-box textarea{min-height:140px;resize:vertical;line-height:1.8}' +
    '.zfb-box textarea:focus,.zfb-box input:focus,.zfb-box select:focus{' +
      'outline:2px solid #FFC107;outline-offset:1px}' +
    '.zfb-box select option{background:#13224A;color:#fff}' +
    '.zfb-count{text-align:end;font-size:.76rem;color:#9DAEC9;margin-top:5px}' +
    '.zfb-count b{font-weight:inherit;direction:ltr;unicode-bidi:isolate;display:inline-block}' +
    '.zfb-count.over{color:#FFB4A2}' +
    '.zfb-opt{margin-top:16px;border:1px solid rgba(255,255,255,.13);border-radius:16px;' +
      'padding:12px 14px;background:rgba(255,255,255,.03)}' +
    '.zfb-opt>summary{cursor:pointer;font-weight:800;font-size:.9rem;color:#FFD65A}' +
    '.zfb-optd{color:#9DAEC9;font-size:.84rem;margin-top:8px}' +
    '.zfb-row{display:flex;gap:9px;margin-top:18px}' +
    '.zfb-row button{flex:1;font:inherit;font-weight:800;font-size:1rem;cursor:pointer;' +
      'border:0;border-radius:14px;padding:14px}' +
    '.zfb-send{background:linear-gradient(160deg,#FFD65A,#FFC107);color:#0B1935}' +
    '.zfb-send[disabled]{opacity:.55;cursor:default}' +
    '.zfb-close{background:rgba(255,255,255,.07);color:#E7EEFA;' +
      'border:1px solid rgba(255,255,255,.16)!important}' +
    '.zfb-msg{margin-top:12px;border-radius:12px;padding:11px 13px;font-size:.9rem;display:none}' +
    '.zfb-msg.err{display:block;background:rgba(255,120,100,.13);border:1px solid rgba(255,120,100,.4)}' +
    '.zfb-priv{color:#7E90AC;font-size:.78rem;margin-top:12px;text-align:center}' +
    '.zfb-done{text-align:center;padding:14px 4px}' +
    '.zfb-done .zfb-tick{font-size:2.6rem;line-height:1}' +
    '.zfb-done h2{margin-top:10px}';

  var dlg = null;

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function build() {
    var st = document.createElement('style');
    st.textContent = CSS;
    document.head.appendChild(st);

    dlg = document.createElement('dialog');
    dlg.className = 'zfb';
    dlg.setAttribute('aria-label', t('title'));
    document.body.appendChild(dlg);
    // الإغلاق بالنقر خارج الصندوق: `dialog` نفسه يملأ الشاشة، فما وقع على
    // عنصره لا على ابنه هو نقرٌ على الفراغ.
    dlg.addEventListener('click', function (e) { if (e.target === dlg) dlg.close(); });
    return dlg;
  }

  /* ── الرسم ── */
  function paintForm() {
    dlg.innerHTML =
      '<div class="zfb-box">' +
        '<h2>' + esc(t('title')) + '</h2>' +
        '<p class="zfb-lede">' + esc(t('lede')) + '</p>' +
        '<textarea id="zfbText" maxlength="' + MAX + '" placeholder="' + esc(t('ph')) + '"></textarea>' +
        '<div class="zfb-count" id="zfbCount"><b>0 / ' + MAX + '</b></div>' +
        '<label for="zfbWho">' + esc(t('who')) + '</label>' +
        '<select id="zfbWho">' +
          '<option value="">' + esc(t('w0')) + '</option>' +
          '<option value="customer">' + esc(t('w1')) + '</option>' +
          '<option value="restaurant">' + esc(t('w2')) + '</option>' +
          '<option value="driver">' + esc(t('w3')) + '</option>' +
          '<option value="visitor">' + esc(t('w4')) + '</option>' +
        '</select>' +
        '<details class="zfb-opt">' +
          '<summary>' + esc(t('opt')) + '</summary>' +
          '<p class="zfb-optd">' + esc(t('optd')) + '</p>' +
          '<label for="zfbName">' + esc(t('name')) + '</label>' +
          '<input id="zfbName" maxlength="60" autocomplete="name" placeholder="' + esc(t('namep')) + '">' +
          '<label for="zfbContact">' + esc(t('contact')) + '</label>' +
          '<input id="zfbContact" maxlength="80" placeholder="' + esc(t('contactp')) + '">' +
        '</details>' +
        '<div class="zfb-msg" id="zfbMsg"></div>' +
        '<div class="zfb-row">' +
          '<button type="button" class="zfb-send" id="zfbSend">' + esc(t('send')) + '</button>' +
          '<button type="button" class="zfb-close" id="zfbCancel">' + esc(t('cancel')) + '</button>' +
        '</div>' +
        '<p class="zfb-priv">' + esc(t('priv')) + '</p>' +
      '</div>';

    var ta = dlg.querySelector('#zfbText');
    var cnt = dlg.querySelector('#zfbCount');
    ta.addEventListener('input', function () {
      cnt.innerHTML = '<b>' + ta.value.length + ' / ' + MAX + '</b>';
      cnt.classList.toggle('over', ta.value.length > MAX - 100);
    });
    dlg.querySelector('#zfbCancel').addEventListener('click', function () { dlg.close(); });
    dlg.querySelector('#zfbSend').addEventListener('click', send);
    setTimeout(function () { ta.focus(); }, 40);
  }

  function paintDone() {
    dlg.innerHTML =
      '<div class="zfb-box zfb-done">' +
        '<div class="zfb-tick">🌟</div>' +
        '<h2>' + esc(t('ok')) + '</h2>' +
        '<p class="zfb-lede">' + esc(t('okd')) + '</p>' +
        '<div class="zfb-row"><button type="button" class="zfb-close" id="zfbDone">' +
          esc(t('cancel')) + '</button></div>' +
      '</div>';
    dlg.querySelector('#zfbDone').addEventListener('click', function () { dlg.close(); });
  }

  function err(k) {
    var m = dlg.querySelector('#zfbMsg');
    if (!m) return;
    m.textContent = t(k);
    m.className = 'zfb-msg err';
  }

  /* ── الإرسال ── */
  function sv(v) { return { stringValue: String(v) }; }

  async function send() {
    var btn = dlg.querySelector('#zfbSend');
    var text = dlg.querySelector('#zfbText').value.trim();
    if (text.length < MIN) return err('eShort');
    if (text.length > MAX) return err('eLong');

    var last = 0;
    try { last = Number(localStorage.getItem('zadgo-fb-at')) || 0; } catch (e) { last = 0; }
    if (Date.now() - last < COOL) return err('eCool');

    btn.disabled = true;
    btn.textContent = t('sending');
    dlg.querySelector('#zfbMsg').className = 'zfb-msg';

    try {
      var a = await fetch(IDP, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ returnSecureToken: true }),
      });
      var auth = await a.json();
      if (!a.ok || !auth.idToken) {
        // الدخول المجهول معطَّل في فايربيز = الباب مغلق لا عطلٌ عندنا،
        // فيُقال ذلك صراحةً بدل رسالة شبكةٍ تُقرأ خطأً في جهاز الزائر.
        var code = (auth.error && auth.error.message) || '';
        throw new Error(/ADMIN_ONLY|OPERATION_NOT_ALLOWED/.test(code) ? 'OFF' : 'NET');
      }

      var fields = {
        text: sv(text),
        role: sv(dlg.querySelector('#zfbWho').value || ''),
        name: sv(dlg.querySelector('#zfbName').value.trim().slice(0, 60)),
        contact: sv(dlg.querySelector('#zfbContact').value.trim().slice(0, 80)),
        page: sv(location.pathname.slice(0, 60)),
        lang: sv(lang()),
        uid: sv(auth.localId),
        status: sv('new'),
        createdAt: { timestampValue: new Date().toISOString() },
        clientTime: { booleanValue: true },
      };
      var r = await fetch(FS, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + auth.idToken },
        body: JSON.stringify({ fields: fields }),
      });
      if (!r.ok) throw new Error('NET');

      try { localStorage.setItem('zadgo-fb-at', String(Date.now())); } catch (e) { /* وضع التصفّح الخاص */ }
      paintDone();
    } catch (e) {
      btn.disabled = false;
      btn.textContent = t('send');
      err(e && e.message === 'OFF' ? 'eOff' : 'eNet');
    }
  }

  function open() {
    if (!dlg) build();
    paintForm();
    if (typeof dlg.showModal === 'function') dlg.showModal();
    else dlg.setAttribute('open', '');
  }

  /* ── الربط: أي عنصر يحمل `data-feedback` يفتح الصندوق ──
   * بالتفويض لا بربطٍ مباشر، فتعمل الأزرار التي تُرسم بعد تحميل الصفحة
   * (شريط اللغة يعيد بناء أجزاء منها). */
  document.addEventListener('click', function (e) {
    var b = e.target.closest && e.target.closest('[data-feedback]');
    if (!b) return;
    e.preventDefault();
    open();
  });

  // إعادة الرسم مع تبديل اللغة كي تُترجم الحقول المفتوحة لا العنوان وحده.
  document.addEventListener('zadgo:lang', function () {
    if (dlg && dlg.open && dlg.querySelector('#zfbText')) {
      var keep = dlg.querySelector('#zfbText').value;
      paintForm();
      dlg.querySelector('#zfbText').value = keep;
      dlg.querySelector('#zfbText').dispatchEvent(new Event('input'));
    }
  });

  window.ZadFeedback = { open: open, label: function () { return t('open'); } };
})();
