#!/usr/bin/env bash
# charon.sh — PreToolUse(Bash): make deletion go through whichever tool this
# machine actually has, and block the other one.
#
# Named after Charon, who ferries the dead across the Styx — one way. `rm` is
# that trip; from `trash`, a file can still come back, on machines that have it.
#
# WHY IT'S SEPARATE FROM intercept.sh
#   intercept.sh promises never to block — that's what lets it speak up on every
#   Bash command without turning into noise. This hook blocks, so it lives on
#   its own and holds exactly one rule.
#
# WHY IT ASKS THE MACHINE, NOT THE ENVIRONMENT
#   `trash` keeps deletions recoverable and is the founder's rule where it
#   exists, but it doesn't exist everywhere — a cloud container has no `trash`
#   at all. Branching on an "am I in the cloud" flag would test a proxy for the
#   real question. Asking whether the binary is here answers it directly, stays
#   right when either side changes, and anyone can check it with
#   `command -v trash`.
#
#   The silent failure this closes: on a machine without it, `trash X
#   2>/dev/null` deletes nothing and looks exactly like success. Seen on
#   2026-09-02 — a tamper test "passed" because the file it was supposed to
#   delete was never deleted.

set -uo pipefail
[ "${GUARDRAILS:-on}" = "off" ] && exit 0

payload="$(cat 2>/dev/null)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0

# Command position: the start, or after ; & | ( — which is what keeps `npm`,
# `git rm`, `rmdir` and an `rm` inside a quoted string out.
POS='(^|[;&|(]|&&|\|\|)[[:space:]]*(sudo[[:space:]]+)?((/usr)?/bin/)?'
BIN='((/usr)?/bin/)?'

# Three ways a command actually runs rm. This does NOT cover every way to delete
# a file — `find -delete`, node's `fs.rmSync` and a python unlink all get
# through. The hook is here to catch the reflex of typing `rm`, not to act as an
# unlink firewall; claiming otherwise would be the false confidence it exists to
# remove.
uses_rm() {
  printf '%s' "$1" | grep -qE "${POS}rm[[:space:]]"                                    && return 0
  printf '%s' "$1" | grep -qE "${POS}xargs[[:space:]]+(-[^[:space:]]+[[:space:]]+)*${BIN}rm([[:space:]]|$)" && return 0
  printf '%s' "$1" | grep -qE "\-exec(dir)?[[:space:]]+${BIN}rm[[:space:]]"             && return 0
  return 1
}

# exit 2, not a JSON `permissionDecision: "deny"`: only exit 2 is documented to
# override a `permissions.allow` rule, and both consumer projects have an allow
# rule that covers the commands this hook checks. The reason goes to stderr,
# which is what Claude sees.
deny() { printf '%s\n' "$1" >&2; exit 2; }

if command -v trash >/dev/null 2>&1 || [ -x /usr/bin/trash ]; then
  uses_rm "$cmd" && deny \
"🛡️ guardrails · charon — this machine has \`trash\`, so delete with it: \`/usr/bin/trash -v <targets…>\`.

\`rm\` is a one-way trip across the Styx; anything sent to the Trash can still come back. (Trash on the
same volume doesn't free any disk space until it's emptied, and only a person can empty it — ⌘⇧⌫ in
Finder. The shell can't.)"
else
  printf '%s' "$cmd" | grep -qE "${POS}trash[[:space:]]" && deny \
"🛡️ guardrails · charon — this machine has **no** \`trash\` (\`command -v trash\` prints nothing), so use \`rm\`.

This is blocked instead of run because here \`trash … 2>/dev/null\` deletes nothing and still
looks like it worked — on 2026-09-02 that made a tamper test look like it had passed."
fi

exit 0
