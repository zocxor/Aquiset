-- AQUISET initial schema (blueprint section 10).
-- Every user-owned table has row-level security: a person can only ever
-- read or write their own rows. Health/routine data is minimal by design.

create extension if not exists pgcrypto;

-- ── Profiles & preferences ─────────────────────────────────────────────

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  locale      text not null default 'en',
  timezone    text not null default 'UTC',
  created_at  timestamptz not null default now()
);

create table public.user_preferences (
  user_id               uuid primary key references auth.users (id) on delete cascade,
  theme_mode            text not null default 'system' check (theme_mode in ('system', 'day', 'night')),
  reduce_motion         boolean not null default false,
  reduce_transparency   boolean not null default false,
  units                 text not null default 'ml' check (units in ('ml', 'floz')),
  nudges_enabled        boolean not null default true,
  quiet_start_min       smallint not null default 1320 check (quiet_start_min between 0 and 1439),
  quiet_end_min         smallint not null default 420 check (quiet_end_min between 0 and 1439),
  nudge_interval_min    smallint not null default 90 check (nudge_interval_min between 30 and 480),
  nudge_cooldown_min    smallint not null default 45 check (nudge_cooldown_min between 0 and 240),
  nudge_daily_cap       smallint not null default 8 check (nudge_daily_cap between 0 and 12),
  clinician_fluid_plan  boolean not null default false,
  updated_at            timestamptz not null default now()
);

create table public.hydration_goals (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  target_ml    integer check (target_ml between 250 and 6000),
  source_type  text not null default 'user_set' check (source_type in ('user_set', 'general_starting_point')),
  updated_at   timestamptz not null default now()
);

-- ── Hydration ──────────────────────────────────────────────────────────

create table public.drink_logs (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  client_id      text not null,                       -- device-generated idempotency key
  amount_ml      integer not null check (amount_ml between 1 and 3000),
  beverage_type  text not null default 'water',
  kind           text not null default 'custom' check (kind in ('sip', 'cup', 'glass', 'bottle', 'custom')),
  source         text not null default 'app' check (source in ('app', 'widget', 'control', 'siri', 'watch', 'shortcut')),
  logged_at      timestamptz not null,
  deleted_at     timestamptz,
  created_at     timestamptz not null default now(),
  unique (user_id, client_id)
);
create index drink_logs_user_time on public.drink_logs (user_id, logged_at desc) where deleted_at is null;

-- ── Sleep & alarms ─────────────────────────────────────────────────────

create table public.sleep_schedule (
  user_id          uuid primary key references auth.users (id) on delete cascade,
  bedtime_min      smallint not null check (bedtime_min between 0 and 1439),
  wake_min         smallint not null check (wake_min between 0 and 1439),
  wind_down_min    smallint not null default 30 check (wind_down_min between 0 and 120),
  alarm_weekdays   smallint[] not null default '{1,2,3,4,5}',
  updated_at       timestamptz not null default now()
);

create table public.sleep_logs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  client_id     text not null,
  bedtime       timestamptz not null,
  wake_time     timestamptz not null check (wake_time > bedtime),
  restfulness   smallint check (restfulness between 1 and 5),  -- the person's own rating, never a clinical score
  created_at    timestamptz not null default now(),
  unique (user_id, client_id)
);
create index sleep_logs_user_time on public.sleep_logs (user_id, bedtime desc);

-- Preference sync only. The device schedule is the runtime authority and
-- alarms ring without this table, the network or the backend.
create table public.alarms (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  label         text not null default 'Good morning',
  time_min      smallint not null check (time_min between 0 and 1439),
  weekdays      smallint[] not null default '{}',
  sound_id      text not null default 'gentle_rise',
  snooze_min    smallint not null default 9 check (snooze_min between 1 and 30),
  enabled       boolean not null default true,
  updated_at    timestamptz not null default now()
);

-- ── Challenges ─────────────────────────────────────────────────────────

create table public.challenges (
  id             text primary key,
  title          text not null,
  type           text not null,
  rules_version  integer not null default 1,
  rules          jsonb not null default '{}',
  safety_notes   text not null,
  active         boolean not null default true
);

create table public.challenge_progress (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  challenge_id  text not null references public.challenges (id),
  progress      jsonb not null default '{}',
  status        text not null default 'active' check (status in ('active', 'paused', 'completed', 'left')),
  updated_at    timestamptz not null default now(),
  unique (user_id, challenge_id)
);

-- ── Reviewed content & consent ─────────────────────────────────────────

create table public.content_items (
  id            text primary key,
  category      text not null,
  locale        text not null default 'en',
  title         text not null,
  body          text not null,
  sources       jsonb not null default '[]',   -- [{title, publisher, url, accessed_at}]
  version       integer not null default 1,
  reviewer      text,
  reviewed_at   timestamptz,                   -- null = not publishable
  published     boolean not null default false
);

create table public.consents (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  consent_type  text not null,
  version       text not null,
  granted_at    timestamptz not null default now(),
  revoked_at    timestamptz
);

-- ── Row-level security ─────────────────────────────────────────────────

alter table public.profiles            enable row level security;
alter table public.user_preferences    enable row level security;
alter table public.hydration_goals     enable row level security;
alter table public.drink_logs          enable row level security;
alter table public.sleep_schedule      enable row level security;
alter table public.sleep_logs          enable row level security;
alter table public.alarms              enable row level security;
alter table public.challenges          enable row level security;
alter table public.challenge_progress  enable row level security;
alter table public.content_items       enable row level security;
alter table public.consents            enable row level security;

create policy "own profile" on public.profiles
  for all using (id = (select auth.uid())) with check (id = (select auth.uid()));

do $$
declare t text;
begin
  foreach t in array array['user_preferences', 'hydration_goals', 'drink_logs', 'sleep_schedule',
                           'sleep_logs', 'alarms', 'challenge_progress', 'consents']
  loop
    execute format(
      'create policy "own rows" on public.%I for all using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))',
      t);
  end loop;
end $$;

create policy "read active challenges" on public.challenges
  for select to authenticated using (active);

create policy "read reviewed content" on public.content_items
  for select using (published and reviewed_at is not null);
