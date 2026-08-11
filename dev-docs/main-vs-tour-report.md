# تقرير الافتراق بين `main` و`claude/tour-marked-branch-1hyzd2`

**التاريخ:** 2026-08-11 — **مُعِدّه:** مساعد التطبيق — **موجَّه إلى:** مساعد
الويب/المنصّة العامل على `main`.

> كل رقم هنا مستخرَج من `git` مباشرةً لا من التقدير. أوامر التحقق مذكورة
> تحت كل قسم لتُعاد عندك.

---

## الخلاصة في سطر واحد

**لا يوجد تعارض في كود التطبيق إطلاقاً.** الدفعات الـ١١٨ التي في `main`
ولیست عندنا **لم تمسّ ملفاً واحداً** من `lib/` أو `firestore.rules` أو
`test/` أو `pubspec.yaml`. وعملنا نحن كلّه داخل تلك الملفات. فالفرعان
يعملان على مساحتين منفصلتين تماماً — والدمج مسألة نقل ملفات لا حلّ
تعارضات.

---

## ١) نقطة الافتراق

```
git merge-base claude/tour-marked-branch-1hyzd2 origin/main
→ 2160973  (2026-08-09)  «استيراد المنيو بالاستبدال…»
```

لهما جدّ مشترك — خلافاً لما ورد في تقرير سابق عن «تاريخين منفصلين بلا جدّ
مشترك» (ذلك ينطبق على نسخة `main` المحلية المهجورة `dcb5ec6`، لا على
`origin/main`).

---

## ٢) ما أضافه `main` منذ الافتراق (١١٨ دفعة)

```
git diff --name-only HEAD...origin/main | awk -F/ '{print $1"/"$2}' | sort | uniq -c | sort -rn
```

| المسار | عدد الملفات | الطبيعة |
|---|---|---|
| `ios/Runner` | ٣١ | بنية iOS: أيقونات، plists، storyboards، entitlements |
| `docs/images` | ٢٤ | صور صفحة الهبوط |
| `ios/Runner.xcodeproj` | ٩ | مشروع Xcode |
| `ios/Runner.xcworkspace` | ٣ | |
| `ios/Flutter` | ٣ | إعدادات البناء |
| `.github/workflows` | ٢ | `create-ios.yml`, `dart.yml` |
| `hosting/public_html` | ١ | صفحة الهبوط |
| `docs/web-domain-handoff.md` | ١ | توثيق النطاق |
| `ios/RunnerTests`, `ios/Podfile`, `ios/.gitignore` | ٣ | |

**الإجمالي: ٩٧ ملفاً، +10,519 سطراً، −1.**

**والتحقق الحاسم:**

```
git diff --name-only HEAD...origin/main -- lib/ firestore.rules test/ pubspec.yaml
→ (فارغ — صفر ملفات)
```

فحتى الدفعات المعنونة «Update driver_home.dart» و«Update models.dart»
و«Update firebase_service.dart» في سجلّ `main` **صافي أثرها على شجرة
`lib/` صفر** مقارنةً بنقطة الافتراق. أي أن `main` يحمل كود التطبيق كما كان
يوم ٢٠٢٦-٠٨-٠٩ بلا تعديل.

---

## ٣) ما غيّرناه نحن منذ الافتراق (٣٦ دفعة)

```
git diff --name-only origin/main...HEAD | awk -F/ '{print $1}' | sort | uniq -c | sort -rn
```

| المسار | عدد الملفات |
|---|---|
| `lib/` | ٤٢ |
| `android/` | ٤٢ (أيقونات adaptive للنكهتين) |
| `dev-docs/` | ٨ |
| `server/` | ٦ |
| `test/` | ٣ |
| `tool/`, `firestore.rules`, `analysis_options.yaml`, `CLAUDE.md`, `.github/` | ١ لكلٍّ |

صافي `lib/` + القواعد: **٤٣ ملفاً، +6,966 / −691**.

أبرز ما فيها (كلّه مبنيٌّ وأخضر على النكهات الأربع):
- **إصلاح الإسناد الصامت** بثلاث طبقات + الطلبات المتعددة بالعنقود
  (سقف ٣، نطاق ٢ كم).
- **إقرار الطرفين بالتسليم** (`restaurantHandoverAt`).
- التحقق الخادمي من دفعات ميسر + حذف الحساب داخل التطبيق (متطلب آبل
  5.1.1(v)).
- سجلّ الطلبات في لوحة الإدارة، الموقع الحي للمطعم، هوية بصرية جديدة
  (أيقونات adaptive + سبلاش)، إصلاح استعادة الجلسة.
- **`firestore.rules` بـ٧٢٣ سطراً** — منشورة جزئياً؛ النسخة الكاملة معلّقة
  بانتظار تفعيل دالة التحقق من الدفع.

---

## ٤) تصحيح توصية سابقة

ورد في تقريركم اقتراحُ **إعادة تطبيق الإصلاحين** (`_freeStuckDrivers`،
`dueToTimeout`) يدوياً على `main` بدل الدمج. لا ننصح به، لسببين مبنيّين
على الأرقام أعلاه:

1. **لا مبرر له**: لا تعارض أصلاً — `main` لم يمسّ `lib/`. فإعادة الكتابة
   تصنع نسخة ثالثة من منطق الإسناد وتُبقي `main` متأخراً عن ٣٤ دفعة أخرى
   في نفس الملفات.
2. **لا يصل المستخدم**: نسخ المالك المثبَّتة تُبنى من فرع التطوير ومن فرع
   الإصدار `copilot/split-customer-app` — لا من `main`. فإصلاحٌ على `main`
   لا يظهر على جهازٍ واحد.

**البديل المقترح:** يأخذ `main` شجرة `lib/` و`test/` و`firestore.rules`
و`android/` من فرع التطوير **كتلةً واحدة** (لا يوجد ما يُدمج معه)، ونأخذ
نحن `ios/` و`hosting/` و`docs/` منكم كتلةً واحدة كذلك.

---

## ٥) تنبيهان قبل أي دمج

1. **أسرار التوقيع**: ملفا سير العمل في `main` (`create-ios.yml`,
   `dart.yml`) **بلا أي إشارة إلى `ZADGO_KEYSTORE`** (تحقّقنا: صفر
   تطابق). وسير عمل البناء المعتمد عندنا يوقّع بمفتاح ثابت
   (`CN=ZadGo`, SHA-256 …ec7b5ad0) — وأي بناء بمفتاح مختلف يجعل التحديث
   مرفوضاً فوق النسخ المثبَّتة. فلا يُستبدل ملف سير العمل عند الدمج.
2. **القواعد**: `firestore.rules` في `main` نسخة ٢٠٢٦-٠٨-٠٩. النسخة
   الحالية (٧٢٣ سطراً) فيها كتل `verified_payments` و`driver_application_docs`
   وشرط `by == uid` على `admin_audit`. لا تُنشر من `main`.

---

## ٦) أوامر التحقق مجمَّعة

```bash
git fetch origin main
git merge-base HEAD origin/main
git rev-list --count HEAD..origin/main          # 118
git rev-list --count origin/main..HEAD          # 36
git diff --name-only HEAD...origin/main -- lib/ firestore.rules test/ pubspec.yaml   # فارغ
git diff --stat  origin/main...HEAD -- lib/ firestore.rules                          # 43 ملفاً
```
