// functions/index.js — دوال زاد جو السحابية (الجيل الثاني، Node 20).
//
// تحلّ محل `server/api/*.php` بلا خادم ولا استضافة ولا مفتاح حساب خدمة:
// الدوال تعمل **داخل** المشروع بصلاحياته، فلا مفتاح يُنزَّل ولا يُحمَل
// على جهاز أحد. (قرار المالك ٢٠٢٦-٠٨-١٢ بعد سقوط طريقَي الاستضافة
// وCloudflare — التفاصيل في dev-docs/notifications-setup.md.)
//
// ما فيها اليوم:
//   ١) onOrderWrite  — مُطلَق من Firestore، يرسل إشعارات دورة الطلب.
//   ٢) api           — نقطة HTTP واحدة تخدم /verify.php (وتبتلع
//                      /notify.php بردٍّ فارغ توافقاً مع الحزم القديمة).
//
// النشر: انظر functions/README.md.

const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');

initializeApp();
const db = getFirestore();

// منطقة النشر — يجب أن تطابق منطقة Firestore وإلا عبر كل نداء قارّةً
// فبطؤ وكلّف. `us-central1` هو الافتراضي لمشروعٍ لم تُختَر له منطقة،
// وهو افتراضنا حتى يصل تأكيد المالك؛ تغييره هنا وحده يكفي.
const REGION = 'us-central1';

// سقف النُسخ — **المكبح الحقيقي للفاتورة**، لا تنبيه الميزانية.
// تنبيه الميزانية يُعلمك **بعد** أن تتوالد الدالة؛ هذا يمنع التوالد.
// وقصص فواتير Blaze الضخمة سببها واحد: دالةٌ تكتب في المجموعة التي
// تراقبها فتستدعي نفسها. بعشر نسخ يصير أسوأ سيناريو محدوداً رياضياً.
const MAX_INSTANCES = 10;

const MOYASAR_SECRET = defineSecret('MOYASAR_SECRET_KEY');

// ───────────────────────────────────────────────────────────────────────
// نصوص الإشعارات — منقولة حرفاً بحرف من server/api/notify.php حتى لا
// يختلف ما يقرؤه المستخدم باختلاف الطريق الذي أرسل الإشعار.
// ───────────────────────────────────────────────────────────────────────
const STATUS_LABELS = {
  restaurantAccepted: 'المطعم استلم طلبك وأكّده ✅',
  preparing: 'مطعمك بدأ تحضير طلبك 👨‍🍳',
  onTheWay: 'السائق في الطريق إليك 🛵',
  delivered: 'تم توصيل طلبك، بالهناء والشفاء 🎉',
  cancelled: 'أُلغي طلبك — راجع التطبيق للتفاصيل',
  restaurantRejected: 'اعتذر المطعم عن طلبك — راجع التطبيق',
  refunded: 'تم استرداد مبلغ طلبك إلى محفظتك 💰',
};

/// يرسل لمجموعة توكنات ويُنظّف الميت منها.
///
/// التنظيف ليس ترفاً: توكن جهازٍ حُذف منه التطبيق يبقى في مستند المستخدم
/// إلى الأبد، فكل إشعار لاحق يهدر نداءً على عنوان ميت. FCM يردّ
/// `registration-token-not-registered` فنمحوه عندها من مستنده.
async function sendTo(recipients, title, body, data) {
  const alive = recipients.filter((r) => r.token);
  if (alive.length === 0) return 0;

  const results = await Promise.all(
    alive.map(async (r) => {
      try {
        await getMessaging().send({
          token: r.token,
          notification: { title, body },
          android: { priority: 'high', notification: { sound: 'default' } },
          apns: { payload: { aps: { sound: 'default' } } },
          data: Object.fromEntries(
            Object.entries(data).map(([k, v]) => [k, String(v)]),
          ),
        });
        return true;
      } catch (e) {
        const dead =
          e.code === 'messaging/registration-token-not-registered' ||
          e.code === 'messaging/invalid-registration-token';
        if (dead && r.uid) {
          await db
            .collection('users')
            .doc(r.uid)
            .update({ fcmToken: FieldValue.delete() })
            .catch(() => {});
        } else {
          logger.warn('فشل إرسال إشعار', { uid: r.uid, code: e.code });
        }
        return false;
      }
    }),
  );
  return results.filter(Boolean).length;
}

async function tokenOf(uid) {
  if (!uid) return null;
  const snap = await db.collection('users').doc(uid).get();
  const token = snap.exists ? snap.get('fcmToken') : null;
  return token ? { uid, token } : null;
}

// ───────────────────────────────────────────────────────────────────────
// ١) إشعارات دورة الطلب
//
// أقوى من المُرحِّل الذي كان في التطبيق (`notify_relay.dart`): ذاك يُطلق
// الإشعار من **جهاز** — فإن كان مغلقاً أو شبكته ساقطة لحظتها، ضاع
// الإشعار بلا أثر. وهذه تعمل لأن **المستند تغيّر**، مهما كان حال أي جهاز.
// ───────────────────────────────────────────────────────────────────────
exports.onOrderWrite = onDocumentWritten(
  {
    document: 'orders/{orderId}',
    region: REGION,
    maxInstances: MAX_INSTANCES,
    retry: false,
  },
  async (event) => {
    const before = event.data?.before?.data() ?? null;
    const after = event.data?.after?.data() ?? null;
    if (!after) return; // حذف طلب — لا إشعار.

    const orderId = event.params.orderId;
    const orderNumber = String(after.orderNumber ?? '');

    // ── حارس الخروج المبكر ───────────────────────────────────────────
    // مستند الطلب يُكتب فيه عشرات المرات في دورته (موقع السائق، أختام،
    // حقول مالية)، ولا يستحق إشعاراً منها إلا ثلاثة تغيّرات. الخروج هنا
    // يجعل الأغلبية الساحقة من الاستدعاءات تكلفتها أجزاء من المليم،
    // ويقطع أي احتمال لحلقة تُغذّي نفسها.
    const isNew = before === null;
    // «تغيّر السائق» لا «أُسند أول مرة»: إعادة الإسناد من كابتن لآخر
    // تستحق إشعاراً للثاني تماماً كالإسناد الأول — والشرط الساذج
    // (كان فارغاً وصار ممتلئاً) كان سيصمت عنها، وهي أكثر وقوعاً عندنا
    // من الإسناد الأول (رفض، انقضاء مهلة، تحويل من الإدارة).
    const driverJustAttached =
      !isNew &&
      !!(after.driverId ?? '') &&
      (before.driverId ?? '') !== (after.driverId ?? '');
    const statusChanged = !isNew && before.status !== after.status;
    if (!isNew && !driverJustAttached && !statusChanged) return;

    try {
      if (isNew) {
        // طلب جديد → مديرو المطعم المعني.
        const managers = await db
          .collection('users')
          .where('role', '==', 'restaurantManager')
          .where('restaurantId', '==', String(after.restaurantId ?? ''))
          .limit(20)
          .get();
        const recipients = managers.docs
          .map((d) => ({ uid: d.id, token: d.get('fcmToken') }))
          .filter((r) => r.token);
        const sent = await sendTo(
          recipients,
          '🛎️ طلب جديد',
          `طلب #${orderNumber} وصل الآن — افتح التطبيق لتأكيد الاستلام`,
          { orderId, event: 'created' },
        );
        logger.info('إشعار طلب جديد', { orderId, sent });
        return;
      }

      if (driverJustAttached) {
        const r = await tokenOf(String(after.driverId ?? ''));
        if (r) {
          await sendTo(
            [r],
            '🛵 طلب مُسند إليك',
            `طلب #${orderNumber} — الاستلام من ${String(after.restaurantName ?? '')}`,
            { orderId, event: 'assigned' },
          );
        }
      }

      if (statusChanged) {
        const label = STATUS_LABELS[String(after.status ?? '')];
        // حالات وسيطة كثيرة لا تستحق إزعاج العميل — الصمت هنا مقصود،
        // فإشعارٌ عن كل خطوة داخلية يُدرَّب المستخدم على تجاهل الكل.
        if (label) {
          const r = await tokenOf(String(after.customerId ?? ''));
          if (r) {
            await sendTo([r], `طلب #${orderNumber}`, label, {
              orderId,
              event: 'status',
            });
          }
        }
      }
    } catch (e) {
      // الإشعار تحسينٌ لا شرطُ صحة: فشلُه لا يجوز أن يُعيد المحاولة على
      // مستندٍ تغيّر بنجاح (وretry: false يمنع ذلك أصلاً).
      logger.error('onOrderWrite', { orderId, error: String(e) });
    }
  },
);

// ───────────────────────────────────────────────────────────────────────
// ٢) نقطة HTTP — التحقق الخادمي من دفعات ميسر (د٣-أ)
//
// العقد نفسه الذي يستدعيه التطبيق اليوم بلا تغيير سطر فيه:
//   POST <base>/verify.php
//   Authorization: Bearer <Firebase ID Token>
//   {"payment_id": "..."}
//
// ولذلك هي دالة واحدة باسم `api` تُوجّه على المسار: التطبيق يشتقّ عنوان
// التحقق باستبدال `notify.php` بـ`verify.php` في `ZADGO_NOTIFY_URL`،
// فبقبول المسارين يكفي متغيّرٌ واحد ولا يُمسّ كود التطبيق.
// ───────────────────────────────────────────────────────────────────────
exports.api = onRequest(
  {
    region: REGION,
    maxInstances: MAX_INSTANCES,
    secrets: [MOYASAR_SECRET],
    cors: false,
  },
  async (req, res) => {
    const path = (req.path || '').replace(/\.php$/, '');

    if (req.method !== 'POST') {
      res.status(405).json({ ok: false, error: 'POST فقط' });
      return;
    }

    // مسار الإشعارات صار زائداً — المُطلَق من Firestore يتولّاها. يُبقى
    // ردّاً فارغاً ناجحاً لا خطأً: حزمٌ قديمة قد تظل تناديه، ولا معنى
    // لأن تسجّل فشلاً على شيء نجح بطريقٍ آخر.
    if (path === '/notify') {
      res.json({ ok: true, sent: 0, skipped: 'يتولّاها مُطلَق Firestore' });
      return;
    }

    if (path !== '/verify') {
      res.status(404).json({ ok: false, error: 'مسار غير معروف' });
      return;
    }

    // ١) هوية المُنادي
    const auth = req.get('Authorization') || '';
    if (!auth.startsWith('Bearer ')) {
      res.status(401).json({ ok: false, error: 'no_token' });
      return;
    }
    let uid;
    try {
      const { getAuth } = require('firebase-admin/auth');
      const decoded = await getAuth().verifyIdToken(auth.slice(7));
      uid = decoded.uid;
    } catch {
      res.status(401).json({ ok: false, error: 'bad_token' });
      return;
    }

    // ٢) معرّف الدفعة — يُرفض شكلاً قبل أن يبلغ البوابة.
    const paymentId = String(req.body?.payment_id ?? '').trim();
    if (!/^[a-f0-9-]{20,60}$/i.test(paymentId)) {
      res.status(400).json({ ok: false, error: 'bad_payment_id' });
      return;
    }

    const secret = MOYASAR_SECRET.value();
    if (!secret) {
      res.status(503).json({ ok: false, error: 'moyasar_not_configured' });
      return;
    }

    // ٣) السؤال من المصدر لا من العميل: العميل يقول «دفعتُ»، وميسر تقول
    //    الحقيقة. هذا هو أصل البند كلّه — كان التطبيق يكتب isPaid بنفسه،
    //    أي أن عميلاً معدَّل البرمجية «ينجح» بلا دفع.
    let payment;
    try {
      const r = await fetch(`https://api.moyasar.com/v1/payments/${paymentId}`, {
        headers: {
          Authorization: `Basic ${Buffer.from(`${secret}:`).toString('base64')}`,
        },
      });
      if (!r.ok) throw new Error(`status ${r.status}`);
      payment = await r.json();
    } catch (e) {
      logger.error('نداء ميسر فشل', { paymentId, error: String(e) });
      res.status(502).json({ ok: false, error: 'gateway_error' });
      return;
    }

    if (payment.status !== 'paid') {
      res.status(409).json({ ok: false, error: 'not_paid' });
      return;
    }
    if (String(payment.currency ?? '').toUpperCase() !== 'SAR') {
      res.status(409).json({ ok: false, error: 'wrong_currency' });
      return;
    }

    // ٤) الختم باسم الدافع والمبلغ — القواعد تربط الطلب بهما لا بكلمة
    //    العميل: `orders` ترفض إنشاء طلبٍ بـpaymentId بلا ختمٍ مطابق
    //    لـuid صاحبه.
    try {
      await db
        .collection('verified_payments')
        .doc(paymentId)
        .set(
          {
            uid,
            amountHalalas: parseInt(payment.amount ?? 0, 10),
            source: 'moyasar',
            verifiedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
    } catch (e) {
      logger.error('تعذّر ختم الدفعة', { paymentId, error: String(e) });
      res.status(500).json({ ok: false, error: 'stamp_failed' });
      return;
    }

    res.json({ ok: true, amount_halalas: parseInt(payment.amount ?? 0, 10) });
  },
);
