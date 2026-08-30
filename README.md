# Supabase Keepalive

[![GitHub release](https://img.shields.io/github/v/release/Vexorgd/supabase-keepalive?sort=semver)](https://github.com/Vexorgd/supabase-keepalive/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Keeps a **free-tier** Supabase project from auto-pausing (~7-day inactivity) by
performing one real, tiny `INSERT` per check, several times a day. Each check is
its own row in a dedicated table that keeps a rolling ~1-year window.

> **v1 (the `/auth/v1/health` GitHub Action) is deprecated and removed.** That
> endpoint never touches Postgres, so it never actually prevented pausing. This
> is the real fix — a genuine DB write that verifies its own effect. If you were
> calling the old reusable workflow, see [Migrating from v1](#migrating-from-v1).

## Two ways to run it (pick one — same real write, same assertion)

| Path | Best for | Runs on |
|---|---|---|
| **A. Scheduled GitHub Action** | anyone — **no always-on machine needed** (works with your laptop off) | GitHub's infra (free) |
| **B. Host `cron`** | you already have an always-on box (Raspberry Pi, VPS, home server) | your host |

Both run the **same** `supabase-keepalive.sh`: a real DB write that **asserts the
effect** (reads the row back), plus a JSONL health log. Start with **A** unless
you specifically want a self-hosted box.

## Why v1 didn't work (and why this does)

- **`/auth/v1/health` never touches Postgres.** It's served by the auth gateway.
  Pinging it does not register as database activity, so the project still pauses.
- **Supabase measures _database_ activity, and measures it _daily_.** Its docs
  describe the bar as *"a few user requests to the database each day over the
  previous week."* So even a real write that runs only once every few days can
  fall below the threshold. **The fix is a real write AND a daily-or-better
  cadence** — this tool runs every 6 hours by default.
- **A green log line must mean the write landed.** v1-style scripts asserted on
  the HTTP status code. This script reads the inserted row back and confirms its
  `run_at` is the timestamp we sent, so a success line can't lie.

## Setup

**1. Create the keepalive table** — Supabase dashboard → SQL Editor → run
[`setup.sql`](./setup.sql). It creates a **sterile** `public.keepalive` table
(`id, run_at, source, trigger, meta` — no app data, no PII), adds a trigger that
**drops rows older than 1 year** (a bounded, rolling window), and **seals it with
RLS** (only the service-role key can touch it; even a leaked anon key gets
nothing). Nothing else in your schema is affected.

### Path A — Scheduled GitHub Action (no always-on host)

1. Copy `supabase-keepalive.sh` into your project's repo (e.g.
   `scripts/supabase-keepalive.sh`).
2. Copy [`github-action-keepalive.yml`](./github-action-keepalive.yml) to
   `.github/workflows/keepalive.yml` and set `SCRIPT_PATH` to where you put the
   script.
3. Repo → **Settings → Secrets and variables → Actions** → add `SUPABASE_URL`
   and `SUPABASE_SERVICE_ROLE_KEY`.
4. **Actions** tab → *Supabase keepalive* → **Run workflow** to test now. A green
   run = the write landed; a red X (with GitHub's failure email) = it didn't —
   and because the script asserts the effect, that red is real.

> Heads-up: GitHub **disables scheduled workflows after 60 days of no repo
> activity**. Push something within 60 days or the keepalive stops. (The workflow
> file explains this too.)

### Path B — Host `cron` (always-on box)

**B1. Put the script on your always-on host**

```bash
mkdir -p ~/supabase-keepalive && cd ~/supabase-keepalive
# copy supabase-keepalive.sh and .env.example here
cp .env.example .env
chmod 600 .env            # lock down the secret
nano .env                 # paste SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY
chmod +x supabase-keepalive.sh

# test once — expect: [<ts>] keepalive ok (HTTP 201) — row <n> inserted at <ts>
./supabase-keepalive.sh
```

> The **service-role key** is required (it bypasses RLS so the write always
> lands). Keep it only in `.env` on the host — never in this repo.

**B2. Schedule it — every 6 hours (a few writes/day, comfortably above the bar)**

```cron
# Supabase keepalive — every 6 hours
0 */6 * * * /home/USER/supabase-keepalive/supabase-keepalive.sh >> /home/USER/supabase-keepalive/keepalive.log 2>&1
```

Adjust `USER`/path to your host. **Do not use `*/2` in the day-of-month field
to mean "every 2 days"** — it means days 1,3,5…31 and resets at month
boundaries, leaving uneven gaps. Prefer the hour field as above.

## Verify it's working

- Console shows `keepalive ok … row <n> inserted at …`; `keepalive.log` gains a
  JSONL line per run, e.g. `{"ts":"…","status":"ok","effect_confirmed":true,"sb_id":<n>,…}`.
  A monitor reads only the **last** line — `status` + how fresh `ts` is → ok /
  stale / failed. (`status:"ok"` with `effect_confirmed:false` counts as failed.)
- In Supabase, `public.keepalive` **accumulates rows** — one per check — and the
  newest `run_at` is recent. `sb_id` in the log matches the Supabase row `id`.
- A deliberately wrong `SUPABASE_URL` produces a `FAILED` line (test it — that
  visible-failure behavior is the thing v1 lacked).
- The project status stays **Active**; no pause-warning emails.

## Using an existing table instead

Prefer not to add a table? Point the script at any table that has a
`run_at timestamptz` column (and lets the DB generate the key) via
`KEEPALIVE_TABLE` in `.env`, or adapt the payload in the script.

## Requirements

- `bash`, `curl`, `date` (all standard on Raspberry Pi OS / Linux). `jq`
  optional (a `sed` fallback is built in).
- Outbound HTTPS to `*.supabase.co`.

## Migrating from v1

v1 was a reusable GitHub Action that pinged `/auth/v1/health`. That endpoint is
served by the auth gateway and **never touches Postgres**, so it did not count as
database activity and your project still paused. It has been **removed** — the
old workflow now only prints a deprecation error.

To migrate:

1. Delete the `uses: Vexorgd/supabase-keepalive/.github/workflows/...` call from
   your consuming repo.
2. Follow **Path A** (GitHub Action) or **Path B** (host cron) above.
3. Swap the `SUPABASE_ANON` secret for `SUPABASE_SERVICE_ROLE_KEY` — the real
   write needs the service-role key (kept only as a secret / in `.env`, never in
   a repo).

## Not a billing workaround

This keeps a **dev/staging/demo** project responsive. For anything you rely on,
run it on the **Pro plan** (paid projects don't pause) rather than synthetic
pings.
