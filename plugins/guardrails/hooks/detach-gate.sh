#!/usr/bin/env bash
# detach-gate.sh — PreToolUse(Bash): refuse a process detached from the call.
# `nohup`, `disown`, `setsid`, or a `&` whose job the same command never
# `wait`s for, leaves a process the harness cannot see: it is missing from the
# session's background tasks, nothing wakes the session when it exits, and the
# agent's next reflex is a blocking wait or a sleep to find out. Measured: a
# mutation run launched with `nohup … & disown`, then waited on with 540-second
# blocking calls until the user asked what it was waiting for. The Bash tool's
# `run_in_background: true` is the tracked form of the same thing.
#
# WHAT IT DOES NOT SEE
#   Only the command itself. Quoted strings and heredoc bodies are dropped
#   before matching, so a commit message that mentions `nohup` passes — and so
#   does a detach hidden in `bash -c '…'` or a script file.

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

# exit 2, not a JSON deny: only exit 2 is documented to take precedence over a
# `permissions.allow` rule. The reason goes to stderr, which is what Claude is shown.
cat >&2 <<'MSG'
🛡️ guardrails — no detached processes: `nohup`, `disown`, `setsid` or a `&` never `wait`ed for hides the process from the harness — it is missing from background tasks and nothing wakes the session when it exits.

Run the same command with the Bash tool's `run_in_background: true` (no `&`), then end the turn: the session is woken when it exits. Do not block or poll on it.
MSG
exit 2
