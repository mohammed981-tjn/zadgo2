/**
 * الذراع الخادمية ٢ — إعادة حساب رصيد الكابتن خادمياً (الذراع ٢، بند ٥).
 *
 * (أمر المالك «نفذ الذراع» ثم «ابدأ» 2026-08-20 بعد عودة موصّل Supabase.)
 *
 * المشكلة (بند ٥): حقل `drivers/{id}/balance` المجمَّع كان **غائباً عن
 * قائمة المنع** في قواعد `drivers`، والتطبيق يكتبه من جهاز الكابتن في
 * ستة مواضع — فجهازٌ معدَّل يكتب رصيده رقماً مباشراً. هذه الدالة تجعل
 * الرصيد **مشتقّاً خادمياً**: تجمع حركات `driver_transactions` لكل كابتن
 * (كلٌّ بمبلغه المُوقَّع) وتكتب المجموع في `balance` بمفتاح خدمة يتجاوز
 * القواعد. بعد تشغيلها والتحقق، يُغلق الحقل في القاعدة (الخطوة ٤).
 *
 * **الحدّ المعروف والمقصود**: `driver_transactions` تحرسها القاعدة نوعاً
 * (السائق يسكّ حركات تدفّق التوصيل فقط، والمكافآت والتسوية للمدير، ولا
 * تعديل ولا حذف) — لكن حقل `amount` نفسه يكتبه الجهاز في حركات التوصيل.
 * فهذه الذراع تُزيل أضعف سطح (كتابة الرصيد المجمَّع مباشرةً)، وتحصينُ
 * `amount` مقابل الطلب المصدر (orders المحمية) دفعةٌ تالية (الذراع ٣).
 *
 * الأسرار المطلوبة في خزنة Supabase (نفس الذراع ١):
 *  - FIREBASE_SERVICE_ACCOUNT: JSON لمفتاح خدمة بدور Cloud Datastore User.
 *  - ARM_TRIGGER_KEY (اختياري): إن ضُبط، يُطلب في ترويسة x-arm-key أو ?key=.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { importPKCS8, SignJWT } from "npm:jose@5";

const PROJECT_ID = "restaurant-app-ed699";
const FS_BASE =
  `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// ── مصادقة حساب الخدمة (منسوخة من price-audit) ──────────────────────
let cachedToken: { value: string; exp: number } | null = null;

async function accessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp - 60 > now) return cachedToken.value;

  const sa = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}");
  if (!sa.client_email) throw new Error("FIREBASE_SERVICE_ACCOUNT غير مضبوط");

  const pk = await importPKCS8(sa.private_key, "RS256");
  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/datastore",
  })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(sa.client_email)
    .setAudience(sa.token_uri)
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(pk);

  const res = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const data = await res.json();
  if (!data.access_token) throw new Error(`token: ${JSON.stringify(data)}`);
  cachedToken = { value: data.access_token, exp: now + 3500 };
  return data.access_token;
}

// deno-lint-ignore no-explicit-any
function fv(v: any): any {
  if (v == null) return null;
  if ("doubleValue" in v) return Number(v.doubleValue);
  if ("integerValue" in v) return Number(v.integerValue);
  if ("stringValue" in v) return v.stringValue;
  if ("booleanValue" in v) return v.booleanValue;
  return null;
}

// deno-lint-ignore no-explicit-any
function docToObj(doc: any): Record<string, any> {
  // deno-lint-ignore no-explicit-any
  const out: Record<string, any> = { _id: doc.name.split("/").pop() };
  for (const [k, v] of Object.entries(doc.fields ?? {})) out[k] = fv(v);
  return out;
}

Deno.serve(async (req) => {
  const guard = Deno.env.get("ARM_TRIGGER_KEY");
  const url = new URL(req.url);
  const given = req.headers.get("x-arm-key") ?? url.searchParams.get("key");
  if (guard && given !== guard) {
    return new Response(JSON.stringify({ ok: false, error: "unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // **الأمان أولاً**: الوضع الافتراضي محاكاة (dry-run) — يقارن ولا يكتب
  // رصيداً. الكتابة الفعلية تلزمها `?apply=1` صراحةً، فلا تُفسد دالةٌ
  // منحرفةٌ أرصدةً حيّة قبل أن نرى فروقها. الخطوة ٢ في README تعتمد هذا.
  const apply = url.searchParams.get("apply") === "1";

  try {
    const token = await accessToken();

    // تجميع مبالغ كل كابتن من كامل سجلّ الحركات (مصفَّحاً بـpageToken —
    // السجلّ ثابتٌ لا يُحذف، فالمجموع نهائي). المبلغ مُوقَّع: موجب يزيد
    // الرصيد وسالب ينقصه، فمجموعه هو الرصيد بحكم التعريف.
    const sums = new Map<string, number>();
    let pageToken = "";
    let scanned = 0;
    do {
      const qurl =
        `${FS_BASE}/driver_transactions?pageSize=300${
          pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ""
        }`;
      const res = await fetch(qurl, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      for (const d of data.documents ?? []) {
        const o = docToObj(d);
        const id = String(o.driverId ?? "");
        if (!id) continue;
        sums.set(id, (sums.get(id) ?? 0) + Number(o.amount ?? 0));
        scanned++;
      }
      pageToken = data.nextPageToken ?? "";
    } while (pageToken);

    // لكل كابتن: اقرأ رصيده الحالي (الذي كتبه جهازه)، قارنه بالمُشتقّ.
    // نكتب فقط في وضع apply، وبقناعٍ على `balance` وحده كي لا يُمسّ أي
    // حقل آخر (PATCH بلا قناع كان يستبدل المستند كاملاً).
    let written = 0;
    const diffs: { id: string; current: number; computed: number }[] = [];
    for (const [id, bal] of sums) {
      const rounded = Math.round(bal * 100) / 100;
      const cur = await fetch(`${FS_BASE}/drivers/${id}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const curDoc = cur.ok ? await cur.json() : {};
      const currentBal = Number(fv(curDoc.fields?.balance) ?? 0);
      if (Math.abs(currentBal - rounded) > 0.01) {
        diffs.push({ id, current: currentBal, computed: rounded });
      }
      if (apply) {
        const res = await fetch(
          `${FS_BASE}/drivers/${id}?updateMask.fieldPaths=balance`,
          {
            method: "PATCH",
            headers: {
              Authorization: `Bearer ${token}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              fields: { balance: { doubleValue: rounded } },
            }),
          },
        );
        if (res.ok) written++;
      }
    }

    // تقرير للمدير في شاشة التشخيص (server_reports كنمط الذراع ١).
    await fetch(`${FS_BASE}/server_reports/driver_balance`, {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        fields: {
          runAt: { timestampValue: new Date().toISOString() },
          mode: { stringValue: apply ? "apply" : "dryRun" },
          transactionsScanned: { integerValue: String(scanned) },
          driversScanned: { integerValue: String(sums.size) },
          mismatches: { integerValue: String(diffs.length) },
          driversUpdated: { integerValue: String(written) },
        },
      }),
    });

    return new Response(
      JSON.stringify({
        ok: true,
        mode: apply ? "apply" : "dryRun",
        transactionsScanned: scanned,
        driversScanned: sums.size,
        mismatches: diffs.length,
        driversUpdated: written,
        // أول ٢٠ فرقاً للمراجعة قبل الكتابة الفعلية.
        sampleDiffs: diffs.slice(0, 20),
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
