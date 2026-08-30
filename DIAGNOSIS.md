# What actually causes free-tier pausing — field notes

**Date:** 2026-08-29

These are the findings behind the v2 rewrite, written up so the fix is
understandable (and so we don't relearn it a fourth time). No project-specific
credentials or infrastructure details are included here.

## The three-strike history

1. **v1 — `/auth/v1/health` ping (GitHub Action).** Failed. That endpoint is the
   auth gateway; it never reaches Postgres, so it doesn't count as activity.
2. **v1.x rewrite — a real DB write, but every ~2 days.** Still paused. The write
   *did* land (verified — see below), so the failure was not the mechanism.
3. **v2 — a real DB write, several times a day, that asserts its own effect.**
   The version in this folder.

## The key evidence that reframed it

Running the write by hand with response headers visible showed:

- The correct project answered (`sb-project-ref` matched), via real
  Supabase/Cloudflare infrastructure.
- The response returned the sentinel **row**, and its timestamp equaled the
  timestamp we had just sent — i.e. **the row provably mutated in Postgres.**
- The `HTTP 200` that earlier looked suspicious was normal: Supabase sits behind
  Cloudflare + Envoy and returns 200 with genuine `sb-*` gateway headers. It was
  never a fake proxy 200.

So: **the write was reaching the database the whole time.** That killed the
long-standing "the write isn't landing" hypothesis.

## The real cause

Supabase's [pausing docs](https://supabase.com/docs/guides/platform/free-project-pausing)
describe the activity bar as *"a few user requests to the database **each day**
over the previous week."* That is a **daily** expectation. A single write every
2 days leaves most days with **zero** activity and can sit below the threshold —
which matches paused-despite-landing-writes exactly.

Two aggravating bugs made it worse and hid it:

- **`0 4 */2 * *` is not "every 2 days."** In the day-of-month field, `*/2`
  fires on days 1,3,5…31 and resets at month boundaries — uneven gaps, not a
  clean 48-hour cadence.
- **`set -euo pipefail` swallowed failures.** When a run hit a transient DNS
  error, `set -e` aborted the script *before* the failure-logging branch, so the
  log showed neither success nor failure for that run — a silent gap. The old
  script also used `return=minimal` and asserted on the status code, so it never
  checked whether the row actually moved.

## The fix (implemented in v2)

1. **Cadence: every 6 hours** — several real writes per day, comfortably above
   "a few requests each day." An upsert is free.
2. **Assert the effect, not the status.** `return=representation` + compare the
   returned timestamp to the one sent. A green line means the row moved.
3. **Fail loudly.** Drop `set -e`; handle curl's exit code; `--max-time`; retry
   transient DNS/network errors; always write a `FAILED` line; record who
   answered (`server` / `sb-project-ref`) so the next failure self-diagnoses.
4. **Fix the schedule footgun** — schedule via the hour field, not `*/2` on day.

## If it ever pauses again after this

The daily threshold is deliberately vague ("sufficient"). If v2 at every-6-hours
ever still pauses, the remaining honest options are: tighten cadence further,
open a Supabase support ticket with the log as evidence, or move the project to
the Pro plan (paid projects don't pause). Don't reach for those until v2 at this
cadence has been given a full 7-day window to prove itself.
