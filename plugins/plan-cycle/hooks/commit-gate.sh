#!/usr/bin/env bash
# commit-gate.sh — PreToolUse: make the commit gate reachable from the paths
# that never open a skill.
#
# THE HOLE THIS FILLS
#   `plan-cycle-gate.sh` is silent and exits 0 when no cycle is active, because
#   its ledger is keyed by session id and only `/plan` creates one. So a session
#   that fixes a bug and commits — the exact path the founder asked about — sees
#   no gate at all. `commit-gate/SKILL.md` already claims to be "reachable from
#   ANY path that lands code: the /plan engineer phase, a /bug-investigate fix,
#   or an ad-hoc edit", and its content already covers that path. What was
#   missing was DISCOVERY: a session that types `git commit` never considers a
#   skill, and a skill nobody loads is advisory the way `resource-gate.sh`'s
#   header describes.
#
# WHY IT DENIES ONCE INSTEAD OF WARNING EVERY TIME
#   PreToolUse can only allow or deny — there is no field that attaches a note
#   to an allowed call (checked against the hooks reference; `updatedInput` does
#   not exist for this event). So the only way to put the legs in front of the
#   agent is to refuse once, name them, and let the retry through. Refusing
#   EVERY commit would make the gate the thing to route around; refusing the
#   first one per session converts "did not know" into "was told", which is the
#   whole of what was broken. It guarantees the legs are SEEN. It cannot
#   guarantee they are walked — that is the skill's job, and the agent's.
#
# WHY IT DOES NOT LIST THE LEGS ITSELF
#   The legs are right-sized to the diff (Leg 3 only when a plan exists, Leg 5
#   only for a user-facing change, the tooling carve-out on Leg 4). A hook that
#   restated them would be a second copy that drifts, and it cannot see the diff
#   to right-size anything. It delivers; the skill decides.
#
# SILENT WHEN A CYCLE IS ACTIVE
#   In-cycle sessions already have the Stop gate, which walks the same ground
#   with the ledger's context. Firing here too would be two gates for one turn.

set -uo pipefail

input=$(cat)

# No jq → allow. A gate that blocks commits because a helper is missing is
# worse than the omission it exists to prevent.
command -v jq >/dev/null 2>&1 || exit 0

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
[ "$tool" = "Bash" ] || exit 0
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$cmd" ] || exit 0

# Split on separators so a match means "this segment IS a commit", not "these
# words appear somewhere" — `echo "git commit"` and `grep 'git commit' log`
# must pass. Same reasoning as resource-gate.sh's segment split.
is_commit=0
while IFS= read -r seg; do
  case "$seg" in
    git\ commit*|git\ -*\ commit*) is_commit=1; break ;;
  esac
done < <(printf '%s\n' "$cmd" | tr ';|&\n' '\n\n\n\n' | sed 's/^[[:space:]]*//')
[ "$is_commit" -eq 1 ] || exit 0

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
sid=$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9._-')
[ -n "$sid" ] || sid="active"

# A live cycle owns this turn — the Stop gate covers it.
ledger_dir="$root/.claude/.plan-cycle"
[ -f "$ledger_dir/session/$sid" ] && exit 0

# Once per session. The stamp lives beside the ledger so it is per-repo and gets
# cleared by whatever already tidies that directory.
stamp_dir="$ledger_dir/commit-gate"
stamp="$stamp_dir/$sid"
[ -f "$stamp" ] && exit 0
mkdir -p "$stamp_dir" 2>/dev/null && : > "$stamp" 2>/dev/null

reason='=== Commit gate — this path is covered too ===

You are about to commit outside a /plan cycle, so no gate has run on this
change. The commit gate is not the cycle: it binds a /bug-investigate fix and an
ad-hoc edit exactly as it binds the engineer phase.

Read the `commit-gate` skill and walk what it asks for THIS diff — it
right-sizes itself, so a one-line fix does not owe what a feature owes.

Then re-run the same command. This fires once per session; every later commit
goes through untouched.'

jq -n --arg r "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse",
  permissionDecision: "deny", permissionDecisionReason: $r}}'
exit 0
