-- Supabase keepalive v2 — one-time setup.
-- Run this in the Supabase dashboard: SQL Editor -> New query -> Run.
--
-- Creates a tiny DEDICATED, STERILE table with a single row that the keepalive
-- script upserts on every run. It holds nothing but a timestamp — no app data,
-- no PII — so the keepalive path never touches anything sensitive. Nothing else
-- in your schema is affected.

create table if not exists public.keepalive (
  id       int primary key,
  last_run timestamptz not null default now()
);

-- Seed the single sentinel row (id = 1). Safe to run repeatedly.
insert into public.keepalive (id, last_run)
values (1, now())
on conflict (id) do nothing;

-- Lock it down. The script authenticates with the SERVICE-ROLE key, which
-- bypasses Row Level Security. Everyone else should get nothing:
--   * Enable RLS and add NO permissive policies -> anon/authenticated are denied.
--   * Revoke the default API grants for good measure (defense in depth).
-- Result: even if your anon key leaks, this table is unreadable and unwritable
-- through the API; only the service role (which stays on your always-on host)
-- can touch it.
alter table public.keepalive enable row level security;
alter table public.keepalive force row level security;

revoke all on public.keepalive from anon, authenticated;
-- (No `grant` and no `create policy` here on purpose — that is what seals it.)
