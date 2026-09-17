#!/usr/bin/env bash
# test-gate.sh — PreToolUse(Bash): a bare `flutter test` / `dart test` is denied
# and pointed at `plan-test`, which holds one of this machine's test slots.
#
# WHY A HOOK AND NOT SKILL PROSE
#   Sessions on this machine cannot see each other's test runs, and a rule in a
#   skill binds only a session that loaded it. A hook is the one thing an agent
#   cannot decline to consult.
#
# WHY IT DENIES INSTEAD OF REWRITING
#   PreToolUse can allow or deny but has no field for editing the command, so the
#   gate refuses and names the command to run instead.
#
# WHY EVERY SURPRISE ALLOWS
#   This runs on every Bash call. Everything here is string matching; the slot
#   accounting, with its state and races, lives in `plan-test`. A missing helper
#   or an unreadable payload exits 0.

set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$cmd" ] || exit 0

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse",
    permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

# One segment per command, so a match means "this segment IS a test run", not
# "these words appear somewhere": `echo "run flutter test"` must pass.
segments() { printf '%s\n' "$cmd" | tr ';|&\n' '\n\n\n\n' | sed 's/^[[:space:]]*//'; }

while IFS= read -r seg; do
  printf '%s' "$seg" | grep -qE '^(flutter|dart)[[:space:]]+test([[:space:]]|$)' || continue
  case "$seg" in *--help*|*-h) continue ;; esac
  # Everything after `test` passes through VERBATIM: filtering out "tokens
  # starting with -" turned `-j 2 test/foo/` into a path named `2`.
  rest=$(printf '%s' "$seg" | sed -E 's/^(flutter|dart)[[:space:]]+test[[:space:]]*//')
  if [ -n "$rest" ]; then suggest="plan-test $rest"; else suggest="plan-test --full"; fi
  scope=$(printf '%s' "$rest" | tr ' ' '\n' | grep -E '/|\.dart$' | head -1)
  deny "$(printf '%s\n' \
    "Test runs go through plan-test, which holds one of this machine's test slots." \
    "" \
    "  $suggest" \
    "" \
    "WHY: several sessions run here at once and cannot see each other. Three" \
    "concurrent suites exhaust 16 GB and macOS answers with a watchdog reboot." \
    "plan-test waits for a slot, and if none frees it tells you who is holding" \
    "one and for how long, so you can narrow scope or go do something else." \
    "" \
    "\`plan-test --status\` shows the current holders." \
    "$( [ -z "$scope" ] && printf '%s' 'An unscoped run is the exception, not the habit — --full says you meant it.' )")"
done < <(segments)

exit 0
