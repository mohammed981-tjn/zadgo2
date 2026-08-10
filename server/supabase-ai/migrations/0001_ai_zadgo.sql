-- ═══════════════════════════════════════════════════════════════════════════
-- ZadGo — سجلّ نداءات الذكاء الاصطناعي (المشروع المخصص لزاد جو وحده)
--
-- مُهيّأ للمشروع الثاني (الفارغ) في حساب Supabase — قرار المالك 2026-08-10:
-- مشروع zol/AdCraft مستقل بمنظومته، وهذا المشروع لذكاء زاد جو حصراً.
-- القيد app = 'zadgo' متعمّد: مشروع مخصص لا تتسرب إليه سجلات تطبيق آخر.
--
-- الفلسفة: كل نداء ذكاء يُسجَّل بمدخلاته ومخرجاته وتكلفته، وكل تفاعل بشري
-- معه (قبول/تعديل/رفض) يُسجَّل بجانبه. مجموع الاثنين بعد أشهر = بيانات
-- التدريب التي تصنع نموذجاً خاصاً لا يستطيع أحد نسخه.
-- ═══════════════════════════════════════════════════════════════════════════

create schema if not exists ai;

-- ── ١) سجل النداءات ────────────────────────────────────────────────────────
create table if not exists ai.requests (
  id             uuid primary key default gen_random_uuid(),
  app            text not null check (app = 'zadgo'),
  feature        text not null,
  actor_role     text,
  actor_ref      text,                       -- مُجزَّأ (hash) — ممنوع تخزين هوية صريحة
  locale         text not null default 'ar-SA',
  provider       text,
  model          text,
  prompt_version text,                       -- أساس مقارنة إصدارات البرومبت
  input          jsonb not null,
  output         jsonb,
  status         text not null default 'pending'
                 check (status in ('pending','ok','error','blocked','cached')),
  error_code     text,
  tokens_in      integer,
  tokens_out     integer,
  cost_usd       numeric(12,6) not null default 0,
  latency_ms     integer,
  request_hash   text,
  parent_id      uuid references ai.requests(id) on delete set null,
  meta           jsonb not null default '{}'::jsonb,
  created_at     timestamptz not null default now()
);

create index if not exists idx_ai_requests_app_time     on ai.requests (app, created_at desc);
create index if not exists idx_ai_requests_feature_time on ai.requests (app, feature, created_at desc);
create index if not exists idx_ai_requests_hash         on ai.requests (request_hash) where request_hash is not null;
create index if not exists idx_ai_requests_actor        on ai.requests (actor_ref, created_at desc) where actor_ref is not null;
create index if not exists idx_ai_requests_status       on ai.requests (status) where status <> 'ok';

-- ── ٢) الحكم البشري: إشارة التدريب ─────────────────────────────────────────
create table if not exists ai.feedback (
  id            uuid primary key default gen_random_uuid(),
  request_id    uuid not null references ai.requests(id) on delete cascade,
  action        text not null check (action in ('accepted','edited','rejected','regenerated','ignored')),
  edited_output jsonb,                       -- ← الذهب: ما استخدمه الإنسان فعلاً
  rating        smallint check (rating between 1 and 5),
  outcome       jsonb not null default '{}'::jsonb,
  note          text,
  created_by    text,
  created_at    timestamptz not null default now()
);

create index if not exists idx_ai_feedback_request on ai.feedback (request_id);
create index if not exists idx_ai_feedback_action  on ai.feedback (action, created_at desc);

-- ── ٣) سقف الإنفاق ─────────────────────────────────────────────────────────
create table if not exists ai.budget (
  app               text primary key check (app = 'zadgo'),
  daily_limit_usd   numeric(10,2) not null default 5,
  monthly_limit_usd numeric(10,2) not null default 50,
  is_enabled        boolean not null default true,
  updated_at        timestamptz not null default now()
);

insert into ai.budget (app, daily_limit_usd, monthly_limit_usd)
values ('zadgo', 5, 50)
on conflict (app) do nothing;

-- ── ٤) مفاتيح تشغيل الميزات (بلا إصدار تطبيق جديد) ─────────────────────────
create table if not exists ai.feature_flags (
  app            text not null check (app = 'zadgo'),
  feature        text not null,
  is_enabled     boolean not null default false,
  model          text,
  prompt_version text,
  config         jsonb not null default '{}'::jsonb,
  updated_at     timestamptz not null default now(),
  primary key (app, feature)
);

-- ── ٥) الأمان: منع أي وصول مباشر من العملاء ────────────────────────────────
alter table ai.requests      enable row level security;
alter table ai.feedback      enable row level security;
alter table ai.budget        enable row level security;
alter table ai.feature_flags enable row level security;
-- لا سياسات = رفض تام لكل الأدوار العامة. مفتاح الخدمة وحده يتجاوز RLS.

revoke all on schema ai from anon, authenticated;
revoke all on all tables in schema ai from anon, authenticated;

-- ── ٦) الدوال ──────────────────────────────────────────────────────────────
create or replace function ai.spend_today(p_app text)
returns numeric language sql stable security definer set search_path = ai, public as $$
  select coalesce(sum(cost_usd), 0) from ai.requests
  where app = p_app
    and created_at >= date_trunc('day', now() at time zone 'Asia/Riyadh') at time zone 'Asia/Riyadh';
$$;

create or replace function ai.spend_month(p_app text)
returns numeric language sql stable security definer set search_path = ai, public as $$
  select coalesce(sum(cost_usd), 0) from ai.requests
  where app = p_app
    and created_at >= date_trunc('month', now() at time zone 'Asia/Riyadh') at time zone 'Asia/Riyadh';
$$;

create or replace function ai.check_budget(p_app text)
returns jsonb language plpgsql stable security definer set search_path = ai, public as $$
declare b ai.budget%rowtype; v_day numeric; v_month numeric;
begin
  select * into b from ai.budget where app = p_app;
  if not found then return jsonb_build_object('allowed', false, 'reason', 'no_budget_row'); end if;
  if not b.is_enabled then return jsonb_build_object('allowed', false, 'reason', 'disabled'); end if;
  v_day := ai.spend_today(p_app); v_month := ai.spend_month(p_app);
  if v_day >= b.daily_limit_usd then
    return jsonb_build_object('allowed', false, 'reason', 'daily_limit',
                              'spent_today', v_day, 'daily_limit', b.daily_limit_usd);
  end if;
  if v_month >= b.monthly_limit_usd then
    return jsonb_build_object('allowed', false, 'reason', 'monthly_limit',
                              'spent_month', v_month, 'monthly_limit', b.monthly_limit_usd);
  end if;
  return jsonb_build_object('allowed', true,
    'spent_today', v_day, 'remaining_today', b.daily_limit_usd - v_day,
    'spent_month', v_month, 'remaining_month', b.monthly_limit_usd - v_month);
end; $$;

create or replace function ai.log_request(
  p_app text, p_feature text, p_input jsonb,
  p_actor_role text default null, p_actor_ref text default null,
  p_provider text default null, p_model text default null,
  p_prompt_version text default null, p_request_hash text default null,
  p_parent_id uuid default null, p_locale text default 'ar-SA',
  p_meta jsonb default '{}'::jsonb
) returns uuid language plpgsql security definer set search_path = ai, public as $$
declare v_id uuid;
begin
  insert into ai.requests (app, feature, input, actor_role, actor_ref, provider, model,
                           prompt_version, request_hash, parent_id, locale, meta)
  values (p_app, p_feature, p_input, p_actor_role, p_actor_ref, p_provider, p_model,
          p_prompt_version, p_request_hash, p_parent_id, p_locale, coalesce(p_meta, '{}'::jsonb))
  returning id into v_id;
  return v_id;
end; $$;

create or replace function ai.complete_request(
  p_id uuid, p_status text, p_output jsonb default null,
  p_tokens_in integer default null, p_tokens_out integer default null,
  p_cost_usd numeric default 0, p_latency_ms integer default null,
  p_error_code text default null
) returns void language sql security definer set search_path = ai, public as $$
  update ai.requests
     set status = p_status,
         output = coalesce(p_output, output),
         tokens_in = coalesce(p_tokens_in, tokens_in),
         tokens_out = coalesce(p_tokens_out, tokens_out),
         cost_usd = coalesce(p_cost_usd, cost_usd),
         latency_ms = coalesce(p_latency_ms, latency_ms),
         error_code = p_error_code
   where id = p_id;
$$;

create or replace function ai.log_feedback(
  p_request_id uuid, p_action text, p_edited_output jsonb default null,
  p_rating smallint default null, p_outcome jsonb default '{}'::jsonb,
  p_note text default null, p_created_by text default null
) returns uuid language plpgsql security definer set search_path = ai, public as $$
declare v_id uuid;
begin
  insert into ai.feedback (request_id, action, edited_output, rating, outcome, note, created_by)
  values (p_request_id, p_action, p_edited_output, p_rating,
          coalesce(p_outcome, '{}'::jsonb), p_note, p_created_by)
  returning id into v_id;
  return v_id;
end; $$;

create or replace function ai.find_cached(p_app text, p_hash text, p_max_age_hours integer default 24)
returns jsonb language sql stable security definer set search_path = ai, public as $$
  select output from ai.requests
  where app = p_app and request_hash = p_hash and status = 'ok' and output is not null
    and created_at > now() - make_interval(hours => p_max_age_hours)
  order by created_at desc limit 1;
$$;

-- ── ٧) لوحات القياس ────────────────────────────────────────────────────────
create or replace view ai.v_daily_usage as
select app, feature, (created_at at time zone 'Asia/Riyadh')::date as day_riyadh,
       count(*) as calls,
       count(*) filter (where status = 'ok') as ok_calls,
       count(*) filter (where status = 'error') as error_calls,
       count(*) filter (where status = 'cached') as cached_calls,
       round(sum(cost_usd), 4) as cost_usd,
       round(avg(latency_ms)) as avg_latency_ms,
       percentile_disc(0.95) within group (order by latency_ms) as p95_latency_ms,
       sum(tokens_in) as tokens_in, sum(tokens_out) as tokens_out
from ai.requests group by 1, 2, 3;

create or replace view ai.v_feature_quality as
select r.app, r.feature, r.prompt_version, r.model,
       count(distinct r.id) as calls,
       count(*) filter (where f.action = 'accepted') as accepted,
       count(*) filter (where f.action = 'edited') as edited,
       count(*) filter (where f.action = 'rejected') as rejected,
       count(*) filter (where f.action = 'regenerated') as regenerated,
       round(100.0 * count(*) filter (where f.action = 'accepted')
             / nullif(count(*) filter (where f.action is not null), 0), 1) as accept_rate_pct,
       round(avg(f.rating), 2) as avg_rating
from ai.requests r left join ai.feedback f on f.request_id = r.id
group by 1, 2, 3, 4;

-- الأصل الحقيقي: أزواج تدريب معتمدة من بشر
create or replace view ai.v_training_pairs as
select r.id as request_id, r.app, r.feature, r.locale, r.prompt_version,
       r.input as prompt_input,
       coalesce(f.edited_output, r.output) as target_output,
       (f.edited_output is not null) as was_edited_by_human,
       f.rating, f.outcome, r.created_at
from ai.requests r join ai.feedback f on f.request_id = r.id
where r.status = 'ok' and f.action in ('accepted','edited')
  and coalesce(f.edited_output, r.output) is not null;

-- ── ٨) أغلفة public (لأن PostgREST يكشف public فقط) ────────────────────────
create or replace function public.ai_check_budget(p_app text)
returns jsonb language sql security definer set search_path = ai, public as $$
  select ai.check_budget(p_app); $$;

create or replace function public.ai_find_cached(p_app text, p_hash text, p_max_age_hours integer default 24)
returns jsonb language sql security definer set search_path = ai, public as $$
  select ai.find_cached(p_app, p_hash, p_max_age_hours); $$;

create or replace function public.ai_log_request(
  p_app text, p_feature text, p_input jsonb, p_actor_role text default null,
  p_actor_ref text default null, p_provider text default null, p_model text default null,
  p_prompt_version text default null, p_request_hash text default null,
  p_parent_id uuid default null, p_locale text default 'ar-SA', p_meta jsonb default '{}'::jsonb
) returns uuid language sql security definer set search_path = ai, public as $$
  select ai.log_request(p_app, p_feature, p_input, p_actor_role, p_actor_ref, p_provider,
                        p_model, p_prompt_version, p_request_hash, p_parent_id, p_locale, p_meta); $$;

create or replace function public.ai_complete_request(
  p_id uuid, p_status text, p_output jsonb default null,
  p_tokens_in integer default null, p_tokens_out integer default null,
  p_cost_usd numeric default 0, p_latency_ms integer default null, p_error_code text default null
) returns void language sql security definer set search_path = ai, public as $$
  select ai.complete_request(p_id, p_status, p_output, p_tokens_in, p_tokens_out,
                             p_cost_usd, p_latency_ms, p_error_code); $$;

create or replace function public.ai_log_feedback(
  p_request_id uuid, p_action text, p_edited_output jsonb default null,
  p_rating smallint default null, p_outcome jsonb default '{}'::jsonb,
  p_note text default null, p_created_by text default null
) returns uuid language sql security definer set search_path = ai, public as $$
  select ai.log_feedback(p_request_id, p_action, p_edited_output, p_rating,
                         p_outcome, p_note, p_created_by); $$;

-- الأهم أمنياً: لا ينفّذها إلا مفتاح الخدمة (دالة الحافة)
revoke execute on function public.ai_check_budget(text) from public, anon, authenticated;
revoke execute on function public.ai_find_cached(text, text, integer) from public, anon, authenticated;
revoke execute on function public.ai_log_request(text,text,jsonb,text,text,text,text,text,text,uuid,text,jsonb) from public, anon, authenticated;
revoke execute on function public.ai_complete_request(uuid,text,jsonb,integer,integer,numeric,integer,text) from public, anon, authenticated;
revoke execute on function public.ai_log_feedback(uuid,text,jsonb,smallint,jsonb,text,text) from public, anon, authenticated;

grant execute on function public.ai_check_budget(text) to service_role;
grant execute on function public.ai_find_cached(text, text, integer) to service_role;
grant execute on function public.ai_log_request(text,text,jsonb,text,text,text,text,text,text,uuid,text,jsonb) to service_role;
grant execute on function public.ai_complete_request(uuid,text,jsonb,integer,integer,numeric,integer,text) to service_role;
grant execute on function public.ai_log_feedback(uuid,text,jsonb,smallint,jsonb,text,text) to service_role;
