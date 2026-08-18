#!/usr/bin/env node
/**
 * صفة المدير — ادّعاء موقّع يُمنح بمفتاح الخادم، لا حقلاً في مستند.
 *
 * لماذا ادّعاء (custom claim) أصلاً؟ لأن `auth.token.admin` توقّعه Firebase
 * داخل رمز الهوية نفسه ولا يستطيع عميل — مهما عدّل الحزمة — تزويره. وفحصه
 * في القواعد لا يكلّف شيئاً، بخلاف `hasRole()` التي تدفع قراءة مستند
 * (`get`) في كل تقييم قاعدة إدارية.
 *
 * ولماذا سكربت في CI لا شاشة في التطبيق؟ للسبب الذي دفعنا ثمنه في مستودع
 * تكسي طيبة: منح الصلاحيات يحتاج مفتاح خادم، ومفتاح خادم داخل APK يُستخرج
 * في ثوانٍ. فالمنح يجري من ورشة GitHub (admin-claim.yml) حيث السرّ لا
 * يغادر المشغِّل. (الغنيمة الثانية من فحص taxi-taiba — بتصرّف لزادقو:
 * لا RTDB هنا، وقواعدنا Firestore.)
 *
 *   node tools/set-admin-claim.js list
 *   node tools/set-admin-claim.js grant  someone@example.com
 *   node tools/set-admin-claim.js revoke someone@example.com
 *
 * البيئة: GOOGLE_APPLICATION_CREDENTIALS (تهيّئه ورشة GitHub عبر
 * google-github-actions/auth — نفس مسار مصادقة نشر القواعد، لأن كتابة
 * الملف يدوياً فشلت في هذا المستودع من قبل بـ«Failed to authenticate»).
 */

'use strict';

const admin = require('firebase-admin');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('GOOGLE_APPLICATION_CREDENTIALS غير مضبوط — لا مفتاح خادم.');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.applicationDefault() });
const auth = admin.auth();

/* ── الأفعال ─────────────────────────────────────────────────────────────── */

// المنح لا يُبطل الجلسات: الادّعاء الجديد يصل مع تجديد الرمز التلقائي خلال
// ساعة على الأكثر (أو فوراً بخروج ودخول)، وقاعدة isAdmin تقبل — مؤقتاً —
// مسار الدور القديم أيضاً، فلا فجوة ينتظر فيها المدير صلاحيته.
async function grant(email) {
  const user = await auth.getUserByEmail(email);
  await auth.setCustomUserClaims(user.uid, {
    ...(user.customClaims || {}),
    admin: true,
  });
  console.log(`مُنحت صفة المدير: ${email} (uid: ${user.uid})`);
  console.log('تسري مع تجديد الرمز (ساعة كحد أقصى)، أو فوراً بخروج ودخول.');
}

// السحب — على النقيض — يُبطل جلسات الحساب كلها: صلاحية تُسحب يجب ألّا
// تعيش في رمزٍ صادر قبل السحب حتى تنتهي مدته.
async function revoke(email) {
  const user = await auth.getUserByEmail(email);
  const claims = { ...(user.customClaims || {}) };
  delete claims.admin;
  await auth.setCustomUserClaims(user.uid, claims);
  await auth.revokeRefreshTokens(user.uid);
  console.log(`سُحبت صفة المدير وأُبطلت الجلسات: ${email} (uid: ${user.uid})`);
}

async function list() {
  const admins = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const u of page.users) {
      if (u.customClaims && u.customClaims.admin === true) {
        admins.push(`${u.email || '(بلا بريد)'}  uid: ${u.uid}`);
      }
    }
    pageToken = page.pageToken;
  } while (pageToken);

  if (admins.length === 0) {
    console.log('لا حساب يحمل الادّعاء بعد — القاعدة تعمل بمسار الدور القديم.');
  } else {
    console.log(`حاملو ادّعاء المدير (${admins.length}):`);
    admins.forEach((line) => console.log(`  ${line}`));
  }
}

/* ── التنفيذ ─────────────────────────────────────────────────────────────── */

(async () => {
  const [action, email] = process.argv.slice(2);

  try {
    if (action === 'list') {
      await list();
    } else if (action === 'grant' || action === 'revoke') {
      if (!email) {
        console.error(`الفعل ${action} يتطلب بريد الحساب.`);
        process.exit(1);
      }
      await (action === 'grant' ? grant(email) : revoke(email));
    } else {
      console.error('الاستخدام: set-admin-claim.js <list|grant|revoke> [email]');
      process.exit(1);
    }
    process.exit(0);
  } catch (err) {
    // أشيع فشلين يستحقان رسالة تدلّ على العلاج لا على الأعراض:
    if (err.code === 'auth/user-not-found') {
      console.error(`لا حساب بهذا البريد: ${email} — أنشئه من التطبيق أولاً.`);
    } else if (err.code === 'auth/insufficient-permission' ||
               String(err.message || '').includes('PERMISSION_DENIED')) {
      console.error(
        'مفتاح الخدمة لا يملك صلاحية إدارة الحسابات — أضف دور ' +
        '«Firebase Authentication Admin» لحساب الخدمة من Google Cloud Console.'
      );
    } else {
      console.error(err.message || err);
    }
    process.exit(1);
  }
})();
