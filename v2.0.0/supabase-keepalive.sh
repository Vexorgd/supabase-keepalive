#!/usr/bin/env bash
# =============================================================================
# Supabase keepalive v2 — run on an always-on host (Raspberry Pi, small VPS,
# home server) via cron, OR from a scheduled GitHub Action. See README.md and
# setup.sql in this folder.
# =============================================================================
# WHY v1 FAILED: v1 pinged the public /auth/v1/health endpoint. That endpoint is
# served by the auth gateway and NEVER touches your Postgres database, so it does
# not count as activity and the project still pauses.
#
# WHY A SINGLE WEEKLY WRITE ALSO FAILS: Supabase measures "sufficient user
# database activity over the past week", and its own docs describe the bar as
# "a few user requests to the database EACH DAY". That is a DAILY expectation.
# One write every few days can still fall below it. => run this SEVERAL times a
# day (the sample cron does every 6 hours). An upsert is free.
#
# WHAT THIS DOES: upserts one dedicated row in a tiny `keepalive` table, bumping
# `last_run` to now() — a real, unambiguous Postgres write every run.
#
# It asserts the EFFECT (reads the row back and checks the timestamp actually
# advanced), not just the HTTP status — so a green log line can never lie.
#
# It appends one JSONL line per run to a log (KEEPALIVE_LOG). An external health
# monitor reads ONLY the last line: status + freshness of `ts` tell it
# ok / stale / failed. `effect_confirmed:false` on an ok is still a failure.
#
# Secrets come from a local .env beside this script (chmod 600) or the
# environment. NEVER commit real credentials.
# =============================================================================
set -uo pipefail   # deliberately NOT -e: we handle failure ourselves so it logs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$SCRIPT_DIR/.env"
  set +a
fi

: "${SUPABASE_URL:?SUPABASE_URL not set (put it in .env beside this script or the environment)}"
: "${SUPABASE_SERVICE_ROLE_KEY:?SUPABASE_SERVICE_ROLE_KEY not set}"

# Configurable so you can point it at an existing table instead of the dedicated
# one from setup.sql. Defaults match setup.sql.
TABLE="${KEEPALIVE_TABLE:-keepalive}"
ROW_ID="${KEEPALIVE_ID:-1}"

# Observability + tuning. LOG is the JSONL health log the monitor reads.
# SOURCE labels who ran it (hostname on a self-host box; "github-action" in CI).
LOG="${KEEPALIVE_LOG:-$SCRIPT_DIR/keepalive.log}"
SOURCE="${KEEPALIVE_SOURCE:-$(hostname 2>/dev/null || echo unknown)}"
ATTEMPTS="${KEEPALIVE_ATTEMPTS:-3}"
DELAY="${KEEPALIVE_DELAY:-10}"

# What kicked off this run: "cron" by default; a health dashboard forcing an
# on-demand check sets KEEPALIVE_TRIGGER=manual. Recorded in the log so history
# can tell a scheduled success from an operator-forced one.
TRIGGER="${KEEPALIVE_TRIGGER:-cron}"

# Prevent a scheduled run and an on-demand ("check now") run from overlapping and
# racing the assert-the-effect check. Best-effort: only where flock exists (Linux
# hosts, GitHub Actions). If another run holds the lock we skip quietly (exit 0) —
# a skipped duplicate is not a failure and must not log one.
LOCK="${KEEPALIVE_LOCK:-$SCRIPT_DIR/.keepalive.lock}"
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK"
  if ! flock -n 9; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] keepalive: another run holds the lock — skipping" >&2
    exit 0
  fi
fi

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
URL="${SUPABASE_URL%/}/rest/v1/${TABLE}?on_conflict=id"
PAYLOAD="{\"id\":${ROW_ID},\"last_run\":\"${TS}\"}"

BODY="$(mktemp)"; HDRS="$(mktemp)"
trap 'rm -f "$BODY" "$HDRS"' EXIT

# --- JSONL health log ---------------------------------------------------------
json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# emit_health <status ok|failed> <effect_confirmed true|false> <http-int> <reason-or-empty>
emit_health() {
  local st="$1" eff="$2" ht="$3" rs="$4" line
  line="{\"ts\":\"${TS}\",\"status\":\"${st}\",\"effect_confirmed\":${eff}"
  line="${line},\"source\":\"$(json_escape "$SOURCE")\",\"trigger\":\"$(json_escape "$TRIGGER")\""
  line="${line},\"http\":$(( 10#${ht:-0} ))"
  [ -n "$rs" ] && line="${line},\"reason\":\"$(json_escape "$rs")\""
  line="${line}}"
  printf '%s\n' "$line" >> "$LOG" 2>/dev/null || true
}

CODE=""; RC=1
for i in $(seq 1 "$ATTEMPTS"); do
  CODE="$(curl -sS --max-time 30 --no-location \
    -o "$BODY" -D "$HDRS" -w '%{http_code}' \
    -X POST "$URL" \
    -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
    -H "Content-Type: application/json" \
    -H "Prefer: resolution=merge-duplicates,return=representation" \
    -d "${PAYLOAD}")"
  RC=$?
  [ "$RC" -eq 0 ] && break
  echo "[$TS] attempt $i/$ATTEMPTS: curl exit=$RC (network/DNS/timeout) — retrying in ${DELAY}s" >&2
  sleep "$DELAY"
done

SERVER="$(grep -i '^server:' "$HDRS" | tr -d '\r' | head -n1)"
REF="$(grep -i '^sb-project-ref:' "$HDRS" | tr -d '\r' | head -n1)"

# Transport failure: no HTTP response at all (DNS/timeout/refused).
if [ "$RC" -ne 0 ]; then
  emit_health failed false 0 "curl_exit_${RC}"
  echo "[$TS] keepalive FAILED after $ATTEMPTS attempts: curl exit=$RC (no HTTP response)" >&2
  exit 1
fi

# Assert the EFFECT: did last_run actually advance to the timestamp we sent?
if command -v jq >/dev/null 2>&1; then
  GOT="$(jq -r '.[0].last_run // empty' < "$BODY" 2>/dev/null)"
else
  GOT="$(sed -n 's/.*"last_run":"\([^"]*\)".*/\1/p' "$BODY" | head -n1)"
fi

# Supabase returns +00:00; our TS uses Z. Both are UTC — compare the
# second-precision prefix so the offset formatting doesn't cause a false miss.
if [ -n "$GOT" ] && [ "${GOT:0:19}" = "${TS:0:19}" ]; then
  emit_health ok true "$CODE" ""
  echo "[$TS] keepalive ok (HTTP $CODE) — row advanced to $GOT"
  exit 0
fi

# HTTP said something, but the row did NOT move. This is the dangerous case the
# whole rewrite exists to catch: a 2xx that is not a real write.
emit_health failed false "$CODE" "row_not_advanced expected=${TS} got=${GOT:-none}"
echo "[$TS] keepalive FAILED (HTTP $CODE) — row did NOT advance. expected=$TS got='${GOT:-<none>}' [$SERVER] [$REF]" >&2
exit 1
