#!/usr/bin/env bash
# deletion-gate.sh — PreToolUse(Bash): route deletion to whichever tool this
# machine actually has, and refuse the other one.
#
# WHY THIS IS SEPARATE FROM intercept.sh
#   intercept.sh promises "never blocks" — that promise is why it can speak on
#   every Bash command without becoming noise. This one DENIES, so it lives
#   apart and carries exactly one rule.
#
# WHY IT ASKS THE MACHINE RATHER THAN THE ENVIRONMENT
#   `trash` keeps deletions recoverable and is the founder's rule where it
#   exists; it does not exist everywhere — a cloud container has no `trash` at
#   all. Branching on a "am I in the cloud" flag would encode a proxy for the
#   real question. Asking whether the binary is here answers it directly, stays
#   correct when either side changes, and anyone can check it with
#   `command -v trash`.
#
#   The silent failure this closes: `trash X 2>/dev/null` on a machine without
#   it deletes nothing and looks exactly like success. Measured 2026-09-02 — a
#   tamper test read as "passed" because the file it was supposed to delete was
#   never deleted.

set -uo pipefail
[ "${GUARDRAILS:-on}" = "off" ] && exit 0

payload="$(cat 2>/dev/null)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0

# Command position: the start, or after ; & | ( — which is what keeps `npm`,
# `git rm`, `rmdir` and an `rm` inside a quoted string out.
POS='(^|[;&|(]|&&|\|\|)[[:space:]]*(sudo[[:space:]]+)?((/usr)?/bin/)?'
BIN='((/usr)?/bin/)?'

# Three ways a command actually invokes rm. NOT exhaustive over "ways to unlink
# a file" — `find -delete`, a node `fs.rmSync`, a python unlink all pass. This
# gate exists to catch the reflex of typing `rm`, not to be an unlink firewall;
# claiming the latter would be the false confidence it is meant to remove.
uses_rm() {
  printf '%s' "$1" | grep -qE "${POS}rm[[:space:]]"                                    && return 0
  printf '%s' "$1" | grep -qE "${POS}xargs[[:space:]]+(-[^[:space:]]+[[:space:]]+)*${BIN}rm([[:space:]]|$)" && return 0
  printf '%s' "$1" | grep -qE "\-exec(dir)?[[:space:]]+${BIN}rm[[:space:]]"             && return 0
  return 1
}

# exit 2, not a JSON `permissionDecision: "deny"`: only exit 2 is documented to
# take precedence over a `permissions.allow` rule, and both consumer projects
# carry an allow that covers the commands this gate judges. The reason goes to
# stderr, which is what Claude is shown.
deny() { printf '%s\n' "$1" >&2; exit 2; }

if command -v trash >/dev/null 2>&1 || [ -x /usr/bin/trash ]; then
  uses_rm "$cmd" && deny \
"🛡️ guardrails — 這台機器有 \`trash\`，所以刪除走它：\`/usr/bin/trash -v <targets…>\`。

\`rm\` 不可回復，而 \`trash\` 可以。（同卷宗的 trash 在清空前不會釋放磁碟空間；要真的
騰出空間，最後一步是人自己在 Finder 按 ⌘⇧⌫，shell 做不到。）"
else
  printf '%s' "$cmd" | grep -qE "${POS}trash[[:space:]]" && deny \
"🛡️ guardrails — 這台機器**沒有** \`trash\`（\`command -v trash\` 為空），用 \`rm\`。

擋下來而不是讓它跑，是因為 \`trash … 2>/dev/null\` 在這裡刪不掉任何東西，卻跟成功
長得一模一樣——2026-09-02 就這樣讓一個竄改測試誤判為通過。"
fi

exit 0
