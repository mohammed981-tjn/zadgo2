// server/supabase-ai/functions/ai-gateway/index.ts
//
// بوابة الذكاء الاصطناعي لزاد جو — دالة الحافة التي كانت الحلقة الناقصة في
// حزمة «الخطوة صفر» (وصلنا عميل Dart والجداول بلا الخادم الذي يربطهما).
//
// المسارات:
//   POST /            توليد نص: فحص الميزانية ← التخزين المؤقت ← المزوّد
//                     ← تسجيل النداء كاملاً (المدخل/المخرج/التكلفة/الزمن)
//   POST /feedback    تسجيل الحكم البشري على مخرج سابق
//   GET  /health      فحص جاهزية (هل المفاتيح مضبوطة؟)
//
// المبادئ الحاكمة (نفس عقيدة التطبيق):
//   • مفاتيح المزوّدين لا تغادر أسرار المشروع — التطبيق لا يعرفها.
//   • كل ريال محسوب: سقف يومي/شهري يُفحص قبل كل نداء، وتجاوزه = 429.
//   • هوية المستخدم تُجزَّأ (SHA-256) قبل التخزين — لا هوية صريحة في السجل.
//   • فشل التسجيل لا يمنع الجواب: الخدمة للمستخدم أولاً والسجل ثانياً.
import { createClient } from "npm:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const APP = "zadgo"; // مشروع مخصص — التطبيق الوحيد المقبول هنا.

// أسعار تقديرية بالدولار لكل مليون رمز (إدخال/إخراج) — تُحدَّث يدوياً عند
// تغيّر تسعير المزوّد؛ دقتها تكفي لسقف الإنفاق لا للمحاسبة الدفترية.
const PRICES: Record<string, [number, number]> = {
  "gemini-2.5-flash-lite": [0.10, 0.40],
  "gemini-2.5-flash": [0.30, 2.50],
  "claude-haiku-4-5": [1.00, 5.00],
};

async function sha256(text: string): Promise<string> {
  const buf = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(text),
  );
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

// ── نداء المزوّد ────────────────────────────────────────────────────────────
async function callProvider(
  model: string,
  system: string,
  user: string,
  maxTokens: number,
): Promise<{ text: string; tokensIn: number; tokensOut: number }> {
  const gemini = Deno.env.get("GEMINI_API_KEY");
  const anthropic = Deno.env.get("ANTHROPIC_API_KEY");

  if (model.startsWith("gemini") && gemini) {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${gemini}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          ...(system ? { system_instruction: { parts: [{ text: system }] } } : {}),
          contents: [{ role: "user", parts: [{ text: user }] }],
          generationConfig: { maxOutputTokens: maxTokens },
        }),
      },
    );
    if (!res.ok) throw new Error(`gemini_${res.status}: ${await res.text()}`);
    const data = await res.json();
    return {
      text: data.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text ?? "").join("") ?? "",
      tokensIn: data.usageMetadata?.promptTokenCount ?? 0,
      tokensOut: data.usageMetadata?.candidatesTokenCount ?? 0,
    };
  }

  if (model.startsWith("claude") && anthropic) {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": anthropic,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model,
        max_tokens: maxTokens,
        ...(system ? { system } : {}),
        messages: [{ role: "user", content: user }],
      }),
    });
    if (!res.ok) throw new Error(`anthropic_${res.status}: ${await res.text()}`);
    const data = await res.json();
    return {
      text: data.content?.map((b: { text?: string }) => b.text ?? "").join("") ?? "",
      tokensIn: data.usage?.input_tokens ?? 0,
      tokensOut: data.usage?.output_tokens ?? 0,
    };
  }

  throw new Error("no_api_key");
}

// ── المعالج ────────────────────────────────────────────────────────────────
Deno.serve(async (req) => {
  const url = new URL(req.url);
  const path = url.pathname.replace(/\/$/, "");

  if (req.method === "GET" && path.endsWith("/health")) {
    return json(200, {
      ok: true,
      app: APP,
      providers: {
        gemini: !!Deno.env.get("GEMINI_API_KEY"),
        anthropic: !!Deno.env.get("ANTHROPIC_API_KEY"),
      },
      secured: !!Deno.env.get("AI_GATEWAY_SECRET"),
    });
  }

  // السر المشترك (إن ضُبط): حاجز أولي أمام الاستهلاك العابر — ليس مصادقة
  // حقيقية (يُشحن في التطبيق)، والترقية اللاحقة: التحقق من رمز Firebase.
  const secret = Deno.env.get("AI_GATEWAY_SECRET");
  if (secret && req.headers.get("x-app-secret") !== secret) {
    return json(401, { error: "unauthorized" });
  }

  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "bad_json" });
  }

  // ── التغذية الراجعة ──
  if (path.endsWith("/feedback")) {
    const { error } = await supabase.rpc("ai_log_feedback", {
      p_request_id: body.request_id,
      p_action: body.action,
      p_edited_output: body.edited_output ?? null,
      p_rating: body.rating ?? null,
      p_outcome: body.outcome ?? {},
      p_note: body.note ?? null,
      p_created_by: body.created_by ?? null,
    });
    if (error) return json(500, { error: error.message });
    return json(200, { ok: true });
  }

  // ── التوليد ──
  if ((body.app ?? APP) !== APP) return json(400, { error: "wrong_app" });
  const feature = String(body.feature ?? "");
  const user = String(body.user ?? "");
  if (!feature || !user) return json(400, { error: "missing_feature_or_user" });

  const system = String(body.system ?? "");
  const model = String(body.model ?? "gemini-2.5-flash-lite");
  const maxTokens = Math.min(Number(body.max_tokens ?? 1024), 4096);

  // الميزانية قبل كل شيء — 429 صريحة يفهمها العميل ويعرضها بلطف.
  const { data: budget } = await supabase.rpc("ai_check_budget", { p_app: APP });
  if (budget && budget.allowed === false) return json(429, { budget });

  // هوية مجزّأة + بصمة طلب للتخزين المؤقت.
  const actorRef = body.actor_ref
    ? await sha256(`zadgo:${body.actor_ref}`)
    : null;
  const requestHash = await sha256(`${APP}|${feature}|${model}|${system}|${user}`);

  if (body.use_cache !== false) {
    const { data: cached } = await supabase.rpc("ai_find_cached", {
      p_app: APP,
      p_hash: requestHash,
    });
    if (cached?.text) {
      return json(200, {
        request_id: "",
        cached: true,
        output: cached,
        usage: { cost_usd: 0, latency_ms: 0 },
      });
    }
  }

  const { data: requestId } = await supabase.rpc("ai_log_request", {
    p_app: APP,
    p_feature: feature,
    p_input: { system, user },
    p_actor_role: body.actor_role ?? null,
    p_actor_ref: actorRef,
    p_provider: model.startsWith("claude") ? "anthropic" : "google",
    p_model: model,
    p_prompt_version: body.prompt_version ?? "v1",
    p_request_hash: requestHash,
    p_locale: body.locale ?? "ar-SA",
    p_meta: body.meta ?? {},
  });

  const t0 = Date.now();
  try {
    const out = await callProvider(model, system, user, maxTokens);
    const [inP, outP] = PRICES[model] ?? [1, 5];
    const cost = (out.tokensIn * inP + out.tokensOut * outP) / 1_000_000;
    const latency = Date.now() - t0;

    if (requestId) {
      await supabase.rpc("ai_complete_request", {
        p_id: requestId,
        p_status: "ok",
        p_output: { text: out.text },
        p_tokens_in: out.tokensIn,
        p_tokens_out: out.tokensOut,
        p_cost_usd: cost,
        p_latency_ms: latency,
      });
    }
    return json(200, {
      request_id: requestId ?? "",
      cached: false,
      output: { text: out.text },
      usage: { cost_usd: cost, latency_ms: latency },
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (requestId) {
      await supabase.rpc("ai_complete_request", {
        p_id: requestId,
        p_status: "error",
        p_error_code: msg.slice(0, 120),
        p_latency_ms: Date.now() - t0,
      });
    }
    return json(502, { error: msg.startsWith("no_api_key") ? "no_api_key" : "provider_error" });
  }
});
