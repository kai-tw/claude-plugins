#!/usr/bin/env bash
# godot.sh — PreToolUse(Bash|Monitor): block polling.
#
# Vladimir and Estragon wait by the tree, asking every so often whether Godot
# has come; the curtain falls and they're still waiting. Re-checking outside
# state — `gh pr checks --watch`, `gh run watch`, `watch`, a loop that sleeps —
# keeps the agent on that stage, running and billed, for as long as the wait
# lasts. The fix is a one-off schedule that wakes the session later.
#
# WHY A HOOK AND NOT A `permissions` PATTERN
#   A deny pattern blocks without saying what to do instead, and the agent's
#   next reflex is another way of waiting. The message has to name the
#   alternative — and a sub-agent's is different, since it can't schedule
#   anything itself.
#
# WHAT IT DOESN'T SEE
#   Only the command itself. Quoted strings and heredoc bodies are dropped
#   before matching, so a commit message that mentions `--watch` gets through —
#   and so does a loop hidden in `bash -c '…'` or a script file. This catches
#   the reflex of typing a wait; it isn't a firewall on waiting.

set -uo pipefail
[ "${GUARDRAILS:-on}" = "off" ] && exit 0

payload="$(cat 2>/dev/null)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0

# Everything after the first `<<` line is a heredoc body; then drop quoted text.
bare="$(printf '%s\n' "$cmd" | awk '{print} /<</{exit}' | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")"

POS='(^|[;&|(]|&&|\|\|)[[:space:]]*'
polls() {
  printf '%s' "$bare" | grep -qE 'gh[[:space:]]+pr[[:space:]]+checks([[:space:]]+[^;&|]*)?[[:space:]]--watch' && return 0
  printf '%s' "$bare" | grep -qE 'gh[[:space:]]+run[[:space:]]+watch([[:space:]]|$)'                    && return 0
  printf '%s' "$bare" | grep -qE "${POS}watch[[:space:]]"                                               && return 0
  printf '%s' "$bare" | tr '\n' ';' | grep -qE "${POS}(while|until|for)[[:space:]].*sleep[[:space:]]"   && return 0
  return 1
}
polls || exit 0

# exit 2, not a JSON deny: only exit 2 is documented to override a
# `permissions.allow` rule. The reason goes to stderr, which is what Claude sees.
cat >&2 <<'MSG'
🛡️ guardrails · godot — no polling. Re-checking something outside (`--watch`, `gh run watch`, `watch`, a loop with `sleep`) is Waiting for Godot: the agent stays running, and billed, the whole time.

- Main thread: schedule a one-off re-check with CronCreate (`recurring: false`, a few minutes out), then end the turn. For a PR's CI, check once first with ccd_pr's get_status.
- Sub-agent: you can't schedule anything yourself. Say in your report what you're waiting on and when to check again, then finish and let the main thread schedule it.
MSG
exit 2
