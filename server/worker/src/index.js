// server/worker/src/index.js
//
// خادم زاد جو المرافق — نسخة Cloudflare Workers من `server/api/*.php`.
//
// لماذا نسخة ثانية؟ ملفات PHP تحتاج استضافة، ولا استضافة على النطاق بعد
// (بلوهوست تقول حرفياً «You don't have any websites yet»). وWorkers
// تُشغّل هذا الملف على شبكة كلاودفلير مجاناً بعنوان `*.workers.dev`
// جاهز، بلا استضافة ولا لمس DNS إطلاقاً.
//
// النسختان **متكافئتان سلوكياً**: نفس العقد مع التطبيق، ونفس منطق
// الأمان، ونفس نصوص الإشعارات حرفاً بحرف. فمن اشترى استضافةً لاحقاً
// رفع ملفات PHP وغيّر عنواناً واحداً، ولا شيء في التطبيق يتغيّر.
//
// المسارات (تقبل الصيغتين بلاحقة .php وبدونها — العميل يشتقّ عنوان
// التحقق باستبدال `notify.php` بـ`verify.php`، فقبولهما معاً يجعل
// المتغيّر الواحد `ZADGO_NOTIFY_URL` كافياً):
//   POST /notify.php | /notify   → إشعار حدث طلب
//   POST /verify.php | /verify   → التحقق الخادمي من دفعة ميسر
//
// الإعداد (بـwrangler، لا في الكود):
//   vars:    PROJECT_ID
//   secrets: SERVICE_ACCOUNT (محتوى ملف حساب الخدمة JSON كاملاً)
//            MOYASAR_SECRET_KEY (اختياري — بدونه يردّ التحقق 503)

const GOOGLE_JWK_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

const SCOPES =
  'https://www.googleapis.com/auth/datastore ' +
  'https://www.googleapis.com/auth/firebase.messaging';

// ذاكرة العزلة (isolate): مفاتيح جوجل العامة وتوكن حساب الخدمة. كلاهما
// آمن التخزين هنا — الأول عام أصلاً، والثاني قصير العمر ولا يغادر
// الخادم. وبدون هذا يُعاد جلبهما مع كل إشعار فيبطؤ كل شيء بلا داعٍ.
let _jwks = null;
let _jwksAt = 0;
let _saToken = null;
let _saTokenExp = 0;

// ─── أدوات ترميز ──────────────────────────────────────────────────────
const enc = new TextEncoder();

function b64urlToBytes(s) {
  const pad = s.replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(pad + '='.repeat((4 - (pad.length % 4)) % 4));
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}

function bytesToB64url(bytes) {
  let bin = '';
  for (const b of new Uint8Array(bytes)) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function jsonResponse(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}

const fail = (status, error) => jsonResponse({ ok: false, error }, status);

// ─── التحقق من توكن هوية Firebase ─────────────────────────────────────
//
// تُستعمل واجهة JWK لا واجهة الشهادات x509 التي تستعملها نسخة PHP:
// WebCrypto لا تستورد شهادة X.509 مباشرة، وتستورد JWK بسطر واحد. المصدر
// والمفاتيح واحدة، والفحوص هي نفسها: التوقيع، والجمهور = معرّف المشروع،
// والمُصدر، وعدم الانتهاء.
async function verifyIdToken(jwt, projectId) {
  const parts = jwt.split('.');
  if (parts.length !== 3) return null;
  const [h64, p64, s64] = parts;

  let header, payload;
  try {
    header = JSON.parse(new TextDecoder().decode(b64urlToBytes(h64)));
    payload = JSON.parse(new TextDecoder().decode(b64urlToBytes(p64)));
  } catch {
    return null;
  }
  if (header.alg !== 'RS256' || !header.kid) return null;

  const now = Math.floor(Date.now() / 1000);
  if ((payload.exp ?? 0) <= now) return null;
  if ((payload.iat ?? 0) > now + 300) return null;
  if (payload.aud !== projectId) return null;
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) return null;
  const uid = payload.sub || payload.user_id;
  if (!uid || typeof uid !== 'string') return null;

  if (!_jwks || Date.now() - _jwksAt > 3600_000) {
    const res = await fetch(GOOGLE_JWK_URL);
    if (!res.ok) return null;
    _jwks = await res.json();
    _jwksAt = Date.now();
  }
  const jwk = (_jwks.keys || []).find((k) => k.kid === header.kid);
  if (!jwk) return null;

  const key = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    b64urlToBytes(s64),
    enc.encode(`${h64}.${p64}`),
  );
  return valid ? uid : null;
}

// ─── توكن حساب الخدمة (OAuth2 بمنحة JWT) ──────────────────────────────
async function serviceAccountToken(sa) {
  const now = Math.floor(Date.now() / 1000);
  if (_saToken && _saTokenExp > now + 60) return _saToken;

  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: sa.client_email,
    scope: SCOPES,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const unsigned =
    `${bytesToB64url(enc.encode(JSON.stringify(header)))}.` +
    `${bytesToB64url(enc.encode(JSON.stringify(claims)))}`;

  const pem = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  // `b64urlToBytes` تقبل base64 القياسي أيضاً: استبدالاها لا يطابقان
  // شيئاً فيه، فتمرّ السلسلة كما هي.
  const key = await crypto.subtle.importKey(
    'pkcs8',
    b64urlToBytes(pem),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    enc.encode(unsigned),
  );
  const assertion = `${unsigned}.${bytesToB64url(sig)}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!res.ok) return null;
  const data = await res.json();
  if (!data.access_token) return null;

  _saToken = data.access_token;
  _saTokenExp = now + (data.expires_in ?? 3600);
  return _saToken;
}

// ─── Firestore REST ───────────────────────────────────────────────────
function fsValue(v) {
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.integerValue !== undefined) return parseInt(v.integerValue, 10);
  if (v.doubleValue !== undefined) return Number(v.doubleValue);
  if (v.booleanValue !== undefined) return Boolean(v.booleanValue);
  if (v.nullValue !== undefined) return null;
  if (v.timestampValue !== undefined) return v.timestampValue;
  if (v.mapValue !== undefined) return fsFields(v.mapValue.fields || {});
  if (v.arrayValue !== undefined) return (v.arrayValue.values || []).map(fsValue);
  return null;
}

function fsFields(fields) {
  const out = {};
  for (const [k, v] of Object.entries(fields)) out[k] = fsValue(v);
  return out;
}

const fsBase = (projectId) =>
  `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;

async function firestoreGet(projectId, path, token) {
  const res = await fetch(`${fsBase(projectId)}/${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) return null;
  const doc = await res.json();
  return doc.fields ? fsFields(doc.fields) : null;
}

async function firestoreQueryEq(projectId, collection, eqFilters, token) {
  const filters = Object.entries(eqFilters).map(([field, value]) => ({
    fieldFilter: {
      field: { fieldPath: field },
      op: 'EQUAL',
      value:
        typeof value === 'boolean'
          ? { booleanValue: value }
          : { stringValue: String(value) },
    },
  }));
  const where =
    filters.length === 1
      ? filters[0]
      : { compositeFilter: { op: 'AND', filters } };

  const res = await fetch(`${fsBase(projectId)}:runQuery`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      structuredQuery: { from: [{ collectionId: collection }], where, limit: 20 },
    }),
  });
  if (!res.ok) return [];
  const rows = await res.json();
  return (Array.isArray(rows) ? rows : [])
    .filter((r) => r.document?.fields)
    .map((r) => fsFields(r.document.fields));
}

async function firestoreSet(projectId, path, data, token) {
  const fields = {};
  for (const [k, v] of Object.entries(data)) {
    if (typeof v === 'boolean') fields[k] = { booleanValue: v };
    else if (Number.isInteger(v)) fields[k] = { integerValue: String(v) };
    else if (typeof v === 'number') fields[k] = { doubleValue: v };
    else fields[k] = { stringValue: String(v) };
  }
  const mask = Object.keys(data)
    .map((k) => `updateMask.fieldPaths=${encodeURIComponent(k)}`)
    .join('&');
  const res = await fetch(`${fsBase(projectId)}/${path}?${mask}`, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields }),
  });
  return res.ok;
}

// ─── FCM v1 ───────────────────────────────────────────────────────────
async function fcmSend(projectId, token, deviceToken, title, body, data = {}) {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: { title, body },
          android: { priority: 'HIGH', notification: { sound: 'default' } },
          apns: { payload: { aps: { sound: 'default' } } },
          data: Object.fromEntries(
            Object.entries(data).map(([k, v]) => [k, String(v)]),
          ),
        },
      }),
    },
  );
  return res.ok;
}

// ─── نصوص الإشعارات — منقولة حرفاً بحرف من notify.php ─────────────────
const STATUS_LABELS = {
  restaurantAccepted: 'المطعم استلم طلبك وأكّده ✅',
  preparing: 'مطعمك بدأ تحضير طلبك 👨‍🍳',
  onTheWay: 'السائق في الطريق إليك 🛵',
  delivered: 'تم توصيل طلبك، بالهناء والشفاء 🎉',
  cancelled: 'أُلغي طلبك — راجع التطبيق للتفاصيل',
  restaurantRejected: 'اعتذر المطعم عن طلبك — راجع التطبيق',
  refunded: 'تم استرداد مبلغ طلبك إلى محفظتك 💰',
};

// ─── نقطة الإشعارات ───────────────────────────────────────────────────
async function handleNotify(request, env) {
  const projectId = env.PROJECT_ID;

  // ١) هوية المُبلِّغ
  const auth = request.headers.get('Authorization') || '';
  const m = auth.match(/^Bearer\s+(\S+)$/);
  if (!m) return fail(401, 'توكن مفقود');
  const callerUid = await verifyIdToken(m[1], projectId);
  if (!callerUid) return fail(401, 'توكن غير صالح');

  // ٢) قراءة الطلب
  let input;
  try {
    input = await request.json();
  } catch {
    return fail(400, 'جسم غير صالح');
  }
  const orderId = String(input.orderId ?? '');
  const event = String(input.event ?? '');
  if (!/^[A-Za-z0-9_-]{4,64}$/.test(orderId)) return fail(400, 'orderId غير صالح');
  if (!['created', 'assigned', 'status'].includes(event)) {
    return fail(400, 'event غير معروف');
  }

  let sa;
  try {
    sa = JSON.parse(env.SERVICE_ACCOUNT);
  } catch {
    return fail(500, 'إعداد الخادم ناقص');
  }
  const saToken = await serviceAccountToken(sa);
  if (!saToken) return fail(500, 'تعذّر توثيق حساب الخدمة');

  const order = await firestoreGet(projectId, `orders/${orderId}`, saToken);
  if (!order) return fail(404, 'الطلب غير موجود');

  // ٣) المُبلِّغ طرف في الطلب؟ — الحارس الذي يمنع إشعاراً عن طلب الغير.
  const caller = await firestoreGet(projectId, `users/${callerUid}`, saToken);
  const callerRole = caller?.role ?? '';
  const isParty =
    order.customerId === callerUid ||
    order.driverId === callerUid ||
    callerRole === 'admin' ||
    (callerRole === 'restaurantManager' &&
      caller?.restaurantId === order.restaurantId);
  if (!isParty) return fail(403, 'لست طرفاً في هذا الطلب');

  // ٤) المستلمون والنص
  const orderNumber = String(order.orderNumber ?? '');
  const tokens = [];
  let title = '';
  let body = '';

  if (event === 'created') {
    const managers = await firestoreQueryEq(
      projectId,
      'users',
      { role: 'restaurantManager', restaurantId: String(order.restaurantId ?? '') },
      saToken,
    );
    for (const u of managers) if (u.fcmToken) tokens.push(u.fcmToken);
    title = '🛎️ طلب جديد';
    body = `طلب #${orderNumber} وصل الآن — افتح التطبيق لتأكيد الاستلام`;
  } else if (event === 'assigned') {
    const driverId = String(order.driverId ?? '');
    if (driverId) {
      const driver = await firestoreGet(projectId, `users/${driverId}`, saToken);
      if (driver?.fcmToken) tokens.push(driver.fcmToken);
    }
    title = '🛵 طلب مُسند إليك';
    body = `طلب #${orderNumber} — الاستلام من ${String(order.restaurantName ?? '')}`;
  } else {
    const status = String(order.status ?? '');
    if (!STATUS_LABELS[status]) {
      return jsonResponse({ ok: true, sent: 0, skipped: 'حالة لا تُشعر' });
    }
    const customerId = String(order.customerId ?? '');
    if (customerId) {
      const customer = await firestoreGet(projectId, `users/${customerId}`, saToken);
      if (customer?.fcmToken) tokens.push(customer.fcmToken);
    }
    title = `طلب #${orderNumber}`;
    body = STATUS_LABELS[status];
  }

  // ٥) الإرسال — بالتوازي، فالمستلمون قد يكونون عدة مديري مطعم.
  const results = await Promise.all(
    [...new Set(tokens)].map((t) =>
      fcmSend(projectId, saToken, t, title, body, { orderId, event }),
    ),
  );
  return jsonResponse({ ok: true, sent: results.filter(Boolean).length });
}

// ─── نقطة التحقق من الدفع ─────────────────────────────────────────────
async function handleVerify(request, env) {
  const projectId = env.PROJECT_ID;

  const auth = request.headers.get('Authorization') || '';
  if (!auth.startsWith('Bearer ')) return fail(401, 'no_token');
  const uid = await verifyIdToken(auth.slice(7), projectId);
  if (!uid) return fail(401, 'bad_token');

  let body;
  try {
    body = await request.json();
  } catch {
    return fail(400, 'bad_body');
  }
  const paymentId = String(body.payment_id ?? '').trim();
  if (!/^[a-f0-9-]{20,60}$/i.test(paymentId)) return fail(400, 'bad_payment_id');

  const secret = env.MOYASAR_SECRET_KEY || '';
  if (!secret) return fail(503, 'moyasar_not_configured');

  // السؤال من المصدر لا من العميل.
  const res = await fetch(`https://api.moyasar.com/v1/payments/${paymentId}`, {
    headers: { Authorization: `Basic ${btoa(`${secret}:`)}` },
  });
  if (!res.ok) return fail(502, 'gateway_error');
  const p = await res.json();
  if (p.status !== 'paid') return fail(409, 'not_paid');
  if (String(p.currency ?? '').toUpperCase() !== 'SAR') return fail(409, 'wrong_currency');

  let sa;
  try {
    sa = JSON.parse(env.SERVICE_ACCOUNT);
  } catch {
    return fail(500, 'sa_config');
  }
  const saToken = await serviceAccountToken(sa);
  if (!saToken) return fail(500, 'sa_token');

  const ok = await firestoreSet(
    projectId,
    `verified_payments/${paymentId}`,
    {
      uid,
      amountHalalas: parseInt(p.amount ?? 0, 10),
      source: 'moyasar',
      verifiedAt: new Date().toISOString(),
    },
    saToken,
  );
  if (!ok) return fail(500, 'stamp_failed');

  return jsonResponse({ ok: true, amount_halalas: parseInt(p.amount ?? 0, 10) });
}

export default {
  async fetch(request, env) {
    const path = new URL(request.url).pathname.replace(/\.php$/, '');

    if (request.method !== 'POST') {
      // ردّ صريح على GET — هو فحص «هل الخادم حيّ؟» الذي يفتحه المالك في
      // المتصفح، ويطابق ردّ نسخة PHP حرفاً بحرف.
      if (path === '/notify' || path === '/verify') return fail(405, 'POST فقط');
      return fail(404, 'مسار غير معروف');
    }
    if (path === '/notify') return handleNotify(request, env);
    if (path === '/verify') return handleVerify(request, env);
    return fail(404, 'مسار غير معروف');
  },
};
