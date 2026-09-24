#!/usr/bin/env bash
# poll-gate.sh — PreToolUse(Bash|Monitor): refuse polling. Waiting on outside
# state by re-checking it — `gh pr checks --watch`, `gh run watch`, `watch`, a
# loop that sleeps — keeps the agent running and billed for as long as the wait
# lasts. The replacement is a one-shot schedule that wakes the session later.
#
# WHY A HOOK AND NOT A `permissions` PATTERN
#   A deny pattern refuses without saying what to do instead, and the agent's
#   next reflex is another form of the same wait. The refusal has to name the
#   replacement — and a sub-agent's replacement differs, since it cannot
#   schedule for itself.
#
# WHAT IT DOES NOT SEE
#   Only the command itself. Quoted strings and heredoc bodies are dropped
#   before matching, so a commit message that mentions `--watch` passes — and so
#   does a loop hidden in `bash -c '…'` or a script file. This catches the
#   reflex of typing a wait, it is not a firewall on waiting.

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

# exit 2, not a JSON deny: only exit 2 is documented to take precedence over a
# `permissions.allow` rule. The reason goes to stderr, which is what Claude is shown.
cat >&2 <<'MSG'
🛡️ guardrails — 不准 polling：反覆查外部狀態（`--watch`、`gh run watch`、`watch`、帶 `sleep` 的迴圈）會讓 agent 在等待期間一直運作、一直計費。

- 主線：用 CronCreate 排一次性回查（`recurring: false`，挑幾分鐘後），然後結束這一輪。PR 的 CI 先用 ccd_pr 的 get_status 查一次。
- sub-agent：無法替自己排程。在報告裡寫明在等什麼、何時該回查，然後結束，交給主線排程。
MSG
exit 2
