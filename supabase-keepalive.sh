#!/usr/bin/env bash
# =============================================================================
# Supabase keepalive v2 — run on an always-on host via cron, OR from a scheduled
# GitHub Action. See README.md and setup.sql in this folder.
# =============================================================================
# WHAT THIS DOES: INSERTS one new row into a dedicated `keepalive` table on every
# run — a real, unambiguous Postgres write. The table is a bounded ~1-year window
# (a DB trigger drops rows older than a year), so each check accumulates as its
# own row without the table growing forever.
#
# It asserts the EFFECT (reads the inserted row back and checks run_at is the
# timestamp we sent), not just the HTTP status — so a green log line can't lie.
#
# It appends one JSONL line per run to a log (KEEPALIVE_LOG), carrying the
# Supabase-assigned row id (`sb_id`) so the Pi log and HQ's store can be matched
# back to the Supabase row. A monitor reads the LAST line for live status.
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

TABLE="${KEEPALIVE_TABLE:-keepalive}"
LOG="${KEEPALIVE_LOG:-$SCRIPT_DIR/keepalive.log}"
SOURCE="${KEEPALIVE_SOURCE:-$(hostname 2>/dev/null || echo unknown)}"
TRIGGER="${KEEPALIVE_TRIGGER:-cron}"
ATTEMPTS="${KEEPALIVE_ATTEMPTS:-3}"
DELAY="${KEEPALIVE_DELAY:-10}"
RETAIN="${KEEPALIVE_RETAIN:-1 year}"   # Pi-log retention window (GNU `date` syntax)

LOCK="${KEEPALIVE_LOCK:-$SCRIPT_DIR/.keepalive.lock}"
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK"
  if ! flock -n 9; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] keepalive: another run holds the lock — skipping" >&2
    exit 0
  fi
fi

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
URL="${SUPABASE_URL%/}/rest/v1/${TABLE}"
PAYLOAD="{\"run_at\":\"${TS}\",\"source\":\"$(json_escape "$SOURCE")\",\"trigger\":\"$(json_escape "$TRIGGER")\"}"

BODY="$(mktemp)"; HDRS="$(mktemp)"
trap 'rm -f "$BODY" "$HDRS"' EXIT

# emit_health <status ok|failed> <effect true|false> <sb_id-or-empty> <http-int> <reason-or-empty>
emit_health() {
  local st="$1" eff="$2" id="$3" ht="$4" rs="$5" line
  line="{\"ts\":\"${TS}\",\"status\":\"${st}\",\"effect_confirmed\":${eff}"
  line="${line},\"sb_id\":${id:-null}"
  line="${line},\"source\":\"$(json_escape "$SOURCE")\",\"trigger\":\"$(json_escape "$TRIGGER")\""
  line="${line},\"http\":$(( 10#${ht:-0} ))"
  [ -n "$rs" ] && line="${line},\"reason\":\"$(json_escape "$rs")\""
  line="${line}}"
  printf '%s\n' "$line" >> "$LOG" 2>/dev/null || true
}

# Keep the Pi log to the same ~1-year window as the Supabase table (best-effort;
# needs GNU `date`). Drops JSONL lines whose ts is older than the window.
prune_log() {
  command -v date >/dev/null 2>&1 || return 0
  [ -f "$LOG" ] || return 0
  local cutoff
  cutoff="$(date -u -d "$RETAIN ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" || return 0
  [ -n "$cutoff" ] || return 0
  awk -v c="$cutoff" '
    { if (match($0, /"ts":"[^"]+"/)) { t=substr($0,RSTART+6,RLENGTH-7); if (t>=c) print } else print }
  ' "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG" 2>/dev/null || rm -f "$LOG.tmp"
}

CODE=""; RC=1
for i in $(seq 1 "$ATTEMPTS"); do
  CODE="$(curl -sS --max-time 30 --no-location \
    -o "$BODY" -D "$HDRS" -w '%{http_code}' \
    -X POST "$URL" \
    -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
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
  emit_health failed false "" 0 "curl_exit_${RC}"
  prune_log
  echo "[$TS] keepalive FAILED after $ATTEMPTS attempts: curl exit=$RC (no HTTP response)" >&2
  exit 1
fi

# Assert the EFFECT: did the INSERT return a row with the run_at we sent?
if command -v jq >/dev/null 2>&1; then
  GOT_RUN="$(jq -r '.[0].run_at // empty' < "$BODY" 2>/dev/null)"
  GOT_ID="$(jq -r '.[0].id // empty' < "$BODY" 2>/dev/null)"
else
  GOT_RUN="$(sed -n 's/.*"run_at":"\([^"]*\)".*/\1/p' "$BODY" | head -n1)"
  GOT_ID="$(sed -n 's/.*"id":\([0-9]\{1,\}\).*/\1/p' "$BODY" | head -n1)"
fi

# Supabase returns +00:00; our TS uses Z. Compare the second-precision prefix.
if [ -n "$GOT_RUN" ] && [ "${GOT_RUN:0:19}" = "${TS:0:19}" ]; then
  emit_health ok true "$GOT_ID" "$CODE" ""
  prune_log
  echo "[$TS] keepalive ok (HTTP $CODE) — row ${GOT_ID:-?} inserted at $GOT_RUN"
  exit 0
fi

# HTTP responded, but no inserted row came back. The dangerous case: a 2xx that
# is not a real write.
emit_health failed false "" "$CODE" "insert_not_confirmed expected=${TS} got=${GOT_RUN:-none}"
prune_log
echo "[$TS] keepalive FAILED (HTTP $CODE) — insert not confirmed. expected=$TS got='${GOT_RUN:-<none>}' [$SERVER] [$REF]" >&2
exit 1
