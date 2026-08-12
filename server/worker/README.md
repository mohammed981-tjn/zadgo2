# خادم زاد جو المرافق — نسخة Cloudflare Workers

> ⏸ **بديل احتياطي معطَّل — لا يُنشر.**
>
> قرار المالك 2026-08-12: الطريق المعتمد هو **Blaze + Cloud Functions**
> (التفاصيل في [`../../dev-docs/notifications-setup.md`](../../dev-docs/notifications-setup.md)).
> كُتب هذا المجلد قبل وصول القرار، وأُبقي لسببٍ واحد: لو تأخّر حساب
> الفوترة أسابيع، يُنشر في ساعة بلا تكلفة ولا استضافة.

نسخة مكافئة سلوكياً لـ`server/api/notify.php` و`verify.php`: نفس العقد
مع التطبيق، ونفس منطق الأمان، ونفس نصوص الإشعارات حرفاً بحرف.

**ما اختُبر:** طبقة التشفير وحدها — توقيع RS256 بمفتاح PKCS8 حقيقي،
واستيراد JWK والتحقق به، ودورة ترميز base64url. الثلاثة تمرّ. **ولم
تُختبر** الدورة الكاملة مقابل Firestore وFCM، لأنها تحتاج مفتاح حساب
خدمة حقيقياً ولا يُنزَّل إلا عند الحاجة.

---

## النشر (إن لزم)

```bash
cd server/worker
npx wrangler login
npx wrangler secret put SERVICE_ACCOUNT       # ألصق محتوى ملف حساب الخدمة JSON كاملاً
npx wrangler secret put MOYASAR_SECRET_KEY    # اختياري
npx wrangler deploy
```

ينتج عنوان مثل `https://zadgo-notify.<اسمك>.workers.dev`. يُضبط بعده
متغيّر المستودع في GitHub:

```
ZADGO_NOTIFY_URL = https://zadgo-notify.<اسمك>.workers.dev/notify.php
```

اللاحقة `.php` مقصودة رغم أنه ليس PHP: التطبيق يشتقّ عنوان التحقق من
الدفع باستبدال `notify.php` بـ`verify.php`، والعامل يقبل الصيغتين —
فمتغيّرٌ واحد يخدم النقطتين بلا تغيير سطر في التطبيق.

## فحص الحياة

افتح العنوان في المتصفح. الردّ الصحيح:

```json
{"ok":false,"error":"POST فقط"}
```

## الحدود المجانية

١٠٠ ألف نداء يومياً على الخطة المجانية — أضعاف ما يحتاجه التشغيل.
