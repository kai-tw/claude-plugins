#!/usr/bin/env bash
# shadow.sh — PreToolUse(Bash): block a process detached from the call.
#
# In Andersen's "The Shadow", a man's shadow walks off on its own and comes back
# years later as a master he can't control. `nohup`, `disown`, `setsid`, or a
# `&` the same command never `wait`s for sets a process loose the same way: the
# harness can't see it, so it's missing from the session's background tasks,
# nothing wakes the session when it exits, and the agent's next reflex is a
# blocking wait or a sleep to find out. Seen in practice: a mutation run started
# with `nohup … & disown`, then waited on with 540-second blocking calls until
# the user asked what it was waiting for. The Bash tool's
# `run_in_background: true` does the same job, tracked.
#
# WHAT IT DOESN'T SEE
#   Only the command itself. Quoted strings and heredoc bodies are dropped
#   before matching, so a commit message that mentions `nohup` gets through —
#   and so does a detach hidden in `bash -c '…'` or a script file.

set -uo pipefail
[ "${GUARDRAILS:-on}" = "off" ] && exit 0

payload="$(cat 2>/dev/null)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0

# Everything after the first `<<` line is a heredoc body; then drop quoted text.
bare="$(printf '%s\n' "$cmd" | awk '{print} /<</{exit}' | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")"
flat="$(printf '%s' "$bare" | tr '\n' ';')"

POS='(^|[;&|(]|&&|\|\|)[[:space:]]*'
detaches() {
  printf '%s' "$flat" | grep -qE "${POS}(nohup|disown|setsid)([[:space:]]|;|$)" && return 0
  # A lone `&` — not `&&`, `|&`, `>&`, `<&` or `&>` — with no `wait` in the same command.
  printf '%s' "$flat" | grep -qE '(^|[^&|<>])&([^&>]|$)' || return 1
  printf '%s' "$flat" | grep -qE "${POS}wait([[:space:]]|;|$)" && return 1
  return 0
}
detaches || exit 0

# exit 2, not a JSON deny: only exit 2 is documented to override a
# `permissions.allow` rule. The reason goes to stderr, which is what Claude sees.
cat >&2 <<'MSG'
🛡️ guardrails · shadow — no detached processes. `nohup`, `disown`, `setsid` or a `&` that's never `wait`ed for sets the process loose like Andersen's shadow: it doesn't show up in background tasks, and nothing wakes the session when it finishes.

Run the same command with the Bash tool's `run_in_background: true` (no `&`) and end the turn — the session wakes up when it exits. Don't block or poll on it.
MSG
exit 2
