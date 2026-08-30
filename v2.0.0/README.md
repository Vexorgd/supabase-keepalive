# Supabase Keepalive v2 (host-run, real DB write)

> **v1 (the `/auth/v1/health` GitHub Action) is deprecated — it does not prevent pausing.**
> v2 makes a real database write, several times a day, from an always-on host.

Keeps a **free-tier** Supabase project from auto-pausing (~7-day inactivity) by
performing one real, tiny `UPDATE` every few hours.

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
  the HTTP status code. This script reads the row back and confirms the
  timestamp actually advanced, so a success line can't lie.

## Setup

**1. Create the keepalive table** — Supabase dashboard → SQL Editor → run
[`setup.sql`](./setup.sql). It creates a tiny **sterile** `public.keepalive(id,
last_run)` table (one row, just a timestamp — no app data, no PII) and **seals it
with RLS** (only the service-role key can touch it; even a leaked anon key gets
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

# test once — expect: [<ts>] keepalive ok (HTTP 200) — row advanced to <ts>
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

- Console shows `keepalive ok … row advanced to …`; `keepalive.log` gains a JSONL
  line per run, e.g. `{"ts":"…","status":"ok","effect_confirmed":true,…}`. A
  monitor reads only the **last** line — `status` + how fresh `ts` is → ok / stale
  / failed. (`status:"ok"` with `effect_confirmed:false` counts as failed.)
- In Supabase, `public.keepalive` row `id=1` has a recent `last_run`.
- A deliberately wrong `SUPABASE_URL` produces a `FAILED` line (test it — that
  visible-failure behavior is the thing v1 lacked).
- The project status stays **Active**; no pause-warning emails.

## Using an existing table instead

Prefer not to add a table? Point the script at any table that has an int `id`
primary key and a `last_run timestamptz` column via `KEEPALIVE_TABLE` /
`KEEPALIVE_ID` in `.env`, or adapt the payload in the script. Filter the
sentinel row out of real queries (e.g. a dedicated id, or a `source` column).

## Requirements

- `bash`, `curl`, `date` (all standard on Raspberry Pi OS / Linux). `jq`
  optional (a `sed` fallback is built in).
- Outbound HTTPS to `*.supabase.co`.

## Not a billing workaround

This keeps a **dev/staging/demo** project responsive. For anything you rely on,
run it on the **Pro plan** (paid projects don't pause) rather than synthetic
pings.
