-- Supabase keepalive v2 — one-time setup (APPEND model + 1-year rolling retention).
-- Run in the Supabase dashboard: SQL Editor -> New query -> Run.
--
-- Each keepalive check INSERTS a new row (a real, unambiguous Postgres write).
-- The table is a bounded ~1-year window: a trigger drops rows older than a year
-- on every insert, so it never grows without limit. The row is deliberately
-- extensible (a `meta` jsonb) so richer diagnostic fields can be added later
-- with no schema change. Holds no app data / PII — only run metadata.
--
-- NOTE: this REPLACES the earlier single-row heartbeat table. That table held
-- only a timestamp (no real data), so dropping it loses nothing.

drop table if exists public.keepalive cascade;

create table public.keepalive (
  id       bigint generated always as identity primary key,
  run_at   timestamptz not null default now(),
  source   text,          -- who ran it (hostname, or "github-action")
  trigger  text,          -- "cron" | "manual"
  meta     jsonb not null default '{}'::jsonb   -- future diagnostic fields
);

create index if not exists keepalive_run_at_idx on public.keepalive (run_at);

-- Rolling retention: after each insert, drop anything older than 1 year.
create or replace function public.keepalive_prune() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  delete from public.keepalive where run_at < now() - interval '1 year';
  return null;
end;
$$;

drop trigger if exists keepalive_prune_trg on public.keepalive;
create trigger keepalive_prune_trg
  after insert on public.keepalive
  for each statement execute function public.keepalive_prune();

-- Lock it down: service-role only (bypasses RLS); anon/authenticated get nothing.
alter table public.keepalive enable row level security;
alter table public.keepalive force row level security;
revoke all on public.keepalive from anon, authenticated;
-- (No policy, no grant — that absence is what seals it.)
