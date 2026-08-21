#!/usr/bin/env bash
# tidy.sh — Stop: remind once per session when either side of the ledger is
# drifting. It never tidies anything itself; what gets fused and what gets
# dropped is the founder's call.
#
#   entries over 5   collection is automatic, consumption is not — an inbox that
#                    only grows is a pile, and a pile is not a signal.
#   rules over 12    the rule set speaks out loud; past a certain size nobody
#                    reads it and it becomes wallpaper. That is the moment to
#                    FUSE, not to keep appending.
set -uo pipefail
[ "${GUARDRAILS:-on}" = "off" ] && exit 0
payload="$(cat 2>/dev/null)"
sid="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)"
flag="${TMPDIR:-/tmp}/gr-tidy-${sid:-nosid}.flag"
[ -f "$flag" ] && exit 0

gr="$(dirname "$0")/../bin/gr"
[ -x "$gr" ] || exit 0
msg=''
while read -r cat n; do
  case "$cat" in TOTAL|'') continue ;; esac
  [ "${n:-0}" -gt 5 ] && msg="${msg}  entries/${cat}: ${n} — consume them (land each as a rule, or drop it with a reason), then delete the file."$'\n'
done < <("$gr" count 2>/dev/null | awk '{print $1, $2}')
for f in "$(dirname "$0")/../rules"/*.tsv; do
  [ -e "$f" ] || continue
  n=$(grep -cvE '^#|^$' "$f" 2>/dev/null || echo 0)
  [ "$n" -gt 12 ] && msg="${msg}  rules/$(basename "$f" .tsv): ${n} rules — past this size the set stops being read. Fuse before adding more."$'\n'
done
[ -z "$msg" ] && exit 0
: > "$flag" 2>/dev/null
printf '🛡️ guardrails ledger:\n%s' "$msg"
exit 0
