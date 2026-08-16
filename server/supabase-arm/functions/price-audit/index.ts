/**
 * الذراع الخادمية ١ — فاحص أسعار الطلبات (كشفٌ لا منع).
 *
 * (دفعة الذراع الخادمية، 2026-08-16 — أول تكامل فيربيز↔Supabase بقرار
 * المالك: «نمط الخانق التدريجي». انظر dev-docs/roadmap-ar.md.)
 *
 * الفكرة: أجهزة العملاء تكتب أسعار طلباتها بنفسها (لا خادم كان عندنا)،
 * وقواعد الحماية لا تستطيع جمع الأصناف. هذه الدالة هي «الطرف الموثوق»
 * الأول: تقرأ طلبات اليوم من Firestore بمفتاح خدمة، تعيد حساب كل
 * فاتورة، وتكتب تقريراً في `server_reports/price_audit` تعرضه شاشة
 * التشخيص للمدير. كشفٌ لا منع — بند مساعد الويب (أ) بفكرته هو نفسها.
 *
 * الفحوص الثلاثة لكل طلب:
 *  ١) عمولة المنصة ≈ مجموع الأصناف × النسبة المختومة (تسامح ٠٫٠٥ ر.س).
 *  ٢) سعر كل صنف ليس أدنى من سعره في منيو المطعم (الأعلى مشروع —
 *     خيارات وإضافات ترفع السعر؛ الأدنى وحده ريبة).
 *  ٣) صنف الطلب موجود في المنيو أصلاً.
 *
 * الأسرار المطلوبة في خزنة Supabase:
 *  - FIREBASE_SERVICE_ACCOUNT: نص JSON لمفتاح خدمة بدور Cloud Datastore User.
 *  - ARM_TRIGGER_KEY (اختياري): إن ضُبط، يُطلب في ترويسة x-arm-key.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { SignJWT, importPKCS8 } from "npm:jose@5";

const PROJECT_ID = "restaurant-app-ed699";
const FS_BASE =
  `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// ── مصادقة حساب الخدمة ──────────────────────────────────────────────
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

// ── قراءة قيم Firestore (صيغة REST المُغلَّفة) ───────────────────────
// deno-lint-ignore no-explicit-any
function fv(v: any): any {
  if (v == null) return null;
  if ("doubleValue" in v) return Number(v.doubleValue);
  if ("integerValue" in v) return Number(v.integerValue);
  if ("stringValue" in v) return v.stringValue;
  if ("booleanValue" in v) return v.booleanValue;
  if ("timestampValue" in v) return v.timestampValue;
  if ("mapValue" in v) {
    // deno-lint-ignore no-explicit-any
    const out: Record<string, any> = {};
    for (const [k, x] of Object.entries(v.mapValue.fields ?? {})) out[k] = fv(x);
    return out;
  }
  if ("arrayValue" in v) return (v.arrayValue.values ?? []).map(fv);
  return null;
}

// deno-lint-ignore no-explicit-any
function docToObj(doc: any): Record<string, any> {
  // deno-lint-ignore no-explicit-any
  const out: Record<string, any> = { _id: doc.name.split("/").pop() };
  for (const [k, v] of Object.entries(doc.fields ?? {})) out[k] = fv(v);
  return out;
}

// deno-lint-ignore no-explicit-any
async function runQuery(token: string, body: unknown): Promise<any[]> {
  const res = await fetch(`${FS_BASE}:runQuery`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ structuredQuery: body }),
  });
  const rows = await res.json();
  if (!Array.isArray(rows)) throw new Error(`runQuery: ${JSON.stringify(rows)}`);
  return rows.filter((r) => r.document).map((r) => docToObj(r.document));
}

Deno.serve(async (req) => {
  // الزناد يقبل المفتاح من الترويسة أو من رابط المتصفح (?key=) — المالك
  // يشغّل الفحص من جواله بلا أدوات، وcron لاحقاً بالترويسة.
  const guard = Deno.env.get("ARM_TRIGGER_KEY");
  const given = req.headers.get("x-arm-key") ??
    new URL(req.url).searchParams.get("key");
  if (guard && given !== guard) {
    return new Response(JSON.stringify({ ok: false, error: "unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const token = await accessToken();

    // نطاق اليوم (توقيت السعودية UTC+3): طلبات اليوم فقط — اقتصاد بحصة
    // قراءات Spark، لا مسح دائم.
    const nowKsa = new Date(Date.now() + 3 * 3600 * 1000);
    const dayStart = new Date(Date.UTC(
      nowKsa.getUTCFullYear(),
      nowKsa.getUTCMonth(),
      nowKsa.getUTCDate(),
    ) - 3 * 3600 * 1000);

    const orders = await runQuery(token, {
      from: [{ collectionId: "orders" }],
      where: {
        fieldFilter: {
          field: { fieldPath: "createdAt" },
          op: "GREATER_THAN_OR_EQUAL",
          value: { timestampValue: dayStart.toISOString() },
        },
      },
      limit: 500,
    });

    // منيو كل مطعم يُجلب مرة واحدة مهما تكررت طلباته.
    // deno-lint-ignore no-explicit-any
    const menus = new Map<string, Map<string, any>>();
    async function menuOf(rId: string) {
      if (menus.has(rId)) return menus.get(rId)!;
      const res = await fetch(
        `${FS_BASE}/restaurants/${rId}/items?pageSize=300`,
        { headers: { Authorization: `Bearer ${token}` } },
      );
      const data = await res.json();
      // deno-lint-ignore no-explicit-any
      const map = new Map<string, any>();
      for (const d of data.documents ?? []) {
        const o = docToObj(d);
        map.set(o._id, o);
      }
      menus.set(rId, map);
      return map;
    }

    // deno-lint-ignore no-explicit-any
    const findings: any[] = [];
    for (const o of orders) {
      const items = (o.items ?? []) as Record<string, unknown>[];
      const itemsSum = items.reduce(
        (s, i) => s + Number(i.price ?? 0) * Number(i.quantity ?? 1),
        0,
      );

      // ١) العمولة المختومة.
      const pct = Number(o.commissionPercent ?? 0);
      if (pct > 0) {
        const expected = itemsSum * (pct / 100);
        if (Math.abs(Number(o.platformCommission ?? 0) - expected) > 0.05) {
          findings.push({
            orderNumber: o.orderNumber ?? o._id,
            type: "commission_mismatch",
            detail:
              `العمولة المختومة ${o.platformCommission} والمتوقعة ${expected.toFixed(2)} ` +
              `(أصناف ${itemsSum.toFixed(2)} × ${pct}%)`,
          });
        }
      }

      // ٢+٣) مطابقة المنيو.
      if (o.restaurantId) {
        const menu = await menuOf(String(o.restaurantId));
        for (const i of items) {
          const m = menu.get(String(i.menuItemId ?? ""));
          if (!m) {
            findings.push({
              orderNumber: o.orderNumber ?? o._id,
              type: "item_not_in_menu",
              detail: `صنف «${i.name}» غير موجود في منيو المطعم`,
            });
          } else if (Number(i.price ?? 0) < Number(m.price ?? 0) - 0.01) {
            findings.push({
              orderNumber: o.orderNumber ?? o._id,
              type: "price_below_menu",
              detail:
                `«${i.name}» سُعِّر ${i.price} والمنيو يقول ${m.price} — سعر أدنى من المنيو`,
            });
          }
        }
      }
    }

    // كتابة التقرير حيث يقرؤه المدير (تتجاوز القواعد بحساب الخدمة —
    // العملاء ممنوعون من الكتابة هنا بقاعدة صريحة).
    const report = {
      fields: {
        runAt: { timestampValue: new Date().toISOString() },
        day: { stringValue: dayStart.toISOString().slice(0, 10) },
        ordersChecked: { integerValue: String(orders.length) },
        findingsCount: { integerValue: String(findings.length) },
        findings: {
          arrayValue: {
            values: findings.slice(0, 50).map((f) => ({
              mapValue: {
                fields: {
                  orderNumber: { stringValue: String(f.orderNumber) },
                  type: { stringValue: f.type },
                  detail: { stringValue: f.detail },
                },
              },
            })),
          },
        },
      },
    };
    await fetch(`${FS_BASE}/server_reports/price_audit`, {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(report),
    });

    return new Response(
      JSON.stringify({
        ok: true,
        ordersChecked: orders.length,
        findings: findings.length,
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
