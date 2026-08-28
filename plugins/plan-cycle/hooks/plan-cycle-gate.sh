#!/usr/bin/env bash
# plan-cycle-gate.sh — hook adapter for the plan-cycle ledger.
#
# WHY THIS EXISTS
#   `bin/plan-cycle` reports in one language — a human-readable reason on stdout
#   plus an exit code. Claude Code's hooks each speak a different one. This
#   adapter is the translation layer, nothing more.
#
#   Stop:         `check`, whose exit 1 becomes {"decision":"block", ...}.
#   SessionStart: `sweep`, whose output becomes additionalContext.
#
#   It deliberately does NOT run project validation (formatters, builds, tests).
#   Those belong to each project's own Stop hook — they differ per repo, and
#   folding them in here would make the plugin un-shareable.
#
# WHY BOTH EVENTS
#   `check` is session-scoped: the ledger is keyed by session id, so it can only
#   ever gate the session that opened the cycle. A PR normally merges SEVERAL
#   sessions after that one ends, and the close-out owed by the merge then has
#   no hook that can see it — it surfaces only if some unrelated later turn in
#   the original session trips Stop. `sweep` is the cross-session half: it reads
#   every ledger in the tree at session start and reports the merged-but-open
#   ones. Reporting, never blocking — SessionStart has no block channel, and the
#   finding is about an earlier cycle, not about the turn now beginning.
#
# SESSION ISOLATION
#   The session id arrives on this hook's stdin; we pass it as an ARGUMENT
#   rather than exporting an environment variable, matching the contract
#   `bin/plan-cycle` expects.
#
# FAILING OPEN
#   Every failure path here exits 0 with no output — no ledger, no jq, an
#   unreadable session id. A planning gate that blocks turn-end because a
#   helper was missing would be worse than the decay it exists to prevent.

set -uo pipefail

input=$(cat)

# No jq → fail open rather than block every turn on a tooling gap.
command -v jq >/dev/null 2>&1 || exit 0

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)

gate="$(dirname "${BASH_SOURCE[0]}")/../bin/plan-cycle"
[ -x "$gate" ] || exit 0

if [ "$event" = "SessionStart" ]; then
  out=$(bash "$gate" --session "$sid" sweep 2>/dev/null)
  # Silent when nothing is owed, so a session with no merged-but-open cycle
  # starts with no injected context at all.
  [ -n "$out" ] || exit 0
  ctx=$(printf '%s\n' "$out" | jq -Rs .)
  printf '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": %s}}\n' "$ctx"
  exit 0
fi

out=$(bash "$gate" --session "$sid" check 2>/dev/null)
ec=$?

# The script is silent and exits 0 when no cycle is active, so this hook is
# invisible for every non-/plan turn — with one deliberate exception: `check`'s
# Gate 0 (commits held unpushed on a worktree branch) needs no ledger, because
# the rule it enforces is about standing in a worktree, not about being mid-cycle.
if [ "$ec" -eq 1 ] && [ -n "$out" ]; then
  reason=$(printf '=== Plan-cycle gate ===\n%s\n' "$out" | jq -Rs .)
  printf '{"decision": "block", "reason": %s}\n' "$reason"
fi

exit 0
