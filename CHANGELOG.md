# Changelog

## [2.0.0] - 2026-08-29
### Added
- Keepalive that performs a **real DB write** — an **INSERT (append), one row per
  check** — and **asserts the effect** (reads the inserted row back and confirms
  its `run_at`).
- **Two delivery paths, one script:** a scheduled **GitHub Action**
  (`github-action-keepalive.yml`) for anyone with no always-on host, and host
  `cron` for a self-hosted box.
- `setup.sql` for the dedicated `keepalive(id, run_at, source, trigger, meta)`
  table, with a **1-year rolling-retention trigger** (drops rows older than a
  year) and **RLS-sealed** (enabled + forced, anon/authenticated revoked — only
  the service role gets through). `meta jsonb` keeps the row extensible.
- **JSONL health log** (`ts, status, effect_confirmed, sb_id, source, trigger,
  http, reason?`), one line per run; `sb_id` links each line to its Supabase row.
  A monitor reads the last line.
- `flock` guard so a scheduled run and an on-demand run can't overlap/race; a
  `trigger` field distinguishing `cron` from `manual` runs.
- Retries for transient DNS/network failures; loud `FAILED` logging that records
  which server answered (`server` / `sb-project-ref`).
- README explaining why v1 pings and sparse writes both fail, plus `DIAGNOSIS.md`.

### Changed
- **Cadence guidance: every 6 hours** (several writes/day). Supabase measures
  activity *daily*; one write every couple of days can fall below the bar.
- Schedule via the hour field, not `*/2` on day-of-month (which is not "every 2 days").

### Deprecated
- v1.0.x `/auth/v1/health` ping method (never reaches Postgres; does not prevent pausing).

## [1.0.x] - prior
- Initial `/auth/v1/health` GitHub Action approach (deprecated).
