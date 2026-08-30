# Changelog

## [2.0.0] - 2026-08-29
### Added
- Keepalive that performs a **real DB write** (`keepalive` table upsert) and
  **asserts the effect** — reads the row back and confirms `last_run` advanced.
- **Two delivery paths, one script:** a scheduled **GitHub Action**
  (`github-action-keepalive.yml`) for anyone with no always-on host, and host
  `cron` for a self-hosted box.
- `setup.sql` for the dedicated `keepalive(id, last_run)` table, now **RLS-sealed**
  (enabled + forced, anon/authenticated grants revoked — only the service role
  gets through).
- **JSONL health log** (`ts, status, effect_confirmed, source, trigger, http,
  reason?`), one line per run, designed for a monitor to read the last line.
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
