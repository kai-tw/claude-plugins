#!/usr/bin/env bash
# intercept.sh — PreToolUse(Bash): warn at the moment a known-silent idiom is
# about to run, and Stop(--reset) to re-arm.
#
# WHY AT PreToolUse AND NOT IN A DOCUMENT
#   A rule in a file has to be read to work, and the failures these prevent are
#   exactly the ones where the operator does not know to look it up. Firing on
#   the command itself needs no trigger judgment.
#
# WHY IT MUST STAY QUIET
#   A rule that fires on healthy commands teaches the reader to dismiss the
#   warning, and then the one that mattered is dismissed too. Hence: patterns
#   are tested in BOTH directions before they land, and each rule speaks at most
#   once per turn.
#
# Never blocks. Always exit 0.

set -uo pipefail
[ "${GUARDRAILS:-on}" = "off" ] && exit 0

RULES="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/rules/tool.tsv"
flagdir="${TMPDIR:-/tmp}"

payload="$(cat 2>/dev/null)"
sid="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)"

# ---- Stop hook: clear this turn's flags ---------------------------------
if [ "${1:-}" = "--reset" ]; then
  find "$flagdir" -maxdepth 1 -name "gr-${sid:-nosid}-*.flag" -exec /bin/rm -f {} + 2>/dev/null
  exit 0
fi

[ -r "$RULES" ] || exit 0
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0

hits=''
while IFS=$'\t' read -r id pat msg src; do
  case "$id" in \#*|'') continue ;; esac
  [ -z "${pat:-}" ] && continue
  printf '%s' "$cmd" | grep -qE "$pat" 2>/dev/null || continue
  flag="$flagdir/gr-${sid:-nosid}-${id}.flag"
  [ -f "$flag" ] && continue           # already said this, this turn
  : > "$flag" 2>/dev/null
  hits="${hits}⚠️  ${id} — ${msg}"$'\n'"    (踩過：${src})"$'\n\n'
done < "$RULES"

[ -z "$hits" ] && exit 0

printf '%s' "🛡️ guardrails — 這個指令命中已知的靜默陷阱：

${hits}不是錯誤，是提醒：這樣寫會拿到一個看起來對的錯答案。改寫，或明知故犯地繼續。" \
  | jq -cn --rawfile ctx /dev/stdin \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$ctx}}' 2>/dev/null
exit 0
