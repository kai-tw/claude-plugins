#!/usr/bin/env bash
# resource-gate.sh — PreToolUse gate for the two resources several concurrent
# sessions silently fight over on one machine: memory and disk.
#
# WHY A HOOK AND NOT SKILL PROSE
#   A rule written in a skill is advisory: a session that never loads it, or
#   loads it and forgets, runs the bare command anyway — and the sessions
#   causing this cannot see each other, so nothing corrects them. A hook is the
#   only thing in a plugin that an agent cannot decline to consult. Coverage is
#   exactly right: plan-cycle is installed in NovelGlide-Flutter,
#   CherishCRM-Flutter and kai-packages, which are the only repos on this
#   machine with a pubspec.yaml, hence the only ones that can run a test suite.
#
# WHY IT DENIES INSTEAD OF REWRITING
#   PreToolUse can only allow or deny — there is no field for editing the
#   command (checked against the hooks reference; `updatedInput` does not exist
#   for this event). So the gate cannot quietly insert a budget; it refuses and
#   names the command to run instead. One extra round trip against a five-minute
#   suite is free.
#
# WHY THE GATE ITSELF TOUCHES NOTHING THAT CAN FAIL
#   Everything here is string matching on the command plus one `df`. The slot
#   accounting — the part with state, races and stale holders — lives in
#   `plan-test`, behind the gate. A bug in a gate that guards every Bash call in
#   three repos would be far more expensive than the over-subscription it
#   prevents, so every unexpected condition below exits 0 and allows.
#
# WHY DISK IS IN THE SAME GATE AS MEMORY
#   They are one problem. The macOS swapfile volume (/System/Volumes/VM) shares
#   an APFS container with the checkouts — measured on this machine: same
#   /dev/disk3s6, same free pool. Worktree build/ output eating the disk caps
#   how far swap can grow, and swap is what stands between memory pressure and
#   a watchdog reboot. Gating worktree creation on free space is therefore a
#   memory measure, not housekeeping.

set -uo pipefail

input=$(cat)

# No jq → allow. A gate that blocks every Bash call because a helper is missing
# is worse than the contention it exists to prevent.
command -v jq >/dev/null 2>&1 || exit 0

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
[ "$tool" = "Bash" ] || exit 0
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$cmd" ] || exit 0

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse",
    permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

# Split the command line into segments so a match means "this segment IS a test
# run", not "these words appear somewhere" — `echo "run flutter test"` and
# `grep 'dart test' foo` must pass.
segments() { printf '%s\n' "$cmd" | tr ';|&\n' '\n\n\n\n' | sed 's/^[[:space:]]*//'; }

while IFS= read -r seg; do
  [ -n "$seg" ] || continue

  # ---------------------------------------------------------------- memory
  if printf '%s' "$seg" | grep -qE '^(flutter|dart)[[:space:]]+test([[:space:]]|$)'; then
    case "$seg" in *--help*|*-h) continue ;; esac
    # The suggestion is a VERBATIM passthrough of everything after `test`, so a
    # flag with a separated value cannot be mistaken for a path: filtering out
    # "tokens starting with -" turned `-j 2 test/foo/` into `plan-test 2
    # test/foo/`, a command that would have failed on a path named `2`.
    rest=$(printf '%s' "$seg" | sed -E 's/^(flutter|dart)[[:space:]]+test[[:space:]]*//')
    if [ -n "$rest" ]; then suggest="plan-test $rest"; else suggest="plan-test --full"; fi
    # A separate question, and only used to pick the nudge line below: was a
    # SCOPE given? A scope is a path — it has a slash or ends in .dart.
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
      "$( [ -z "$scope" ] && printf '%s' 'An unscoped run is the exception, not the habit (qa/SKILL.md §Running the suite) — --full says you meant it.' )")"
  fi

  # ------------------------------------------------------------------ disk
  if printf '%s' "$seg" | grep -qE '^git[[:space:]]+.*worktree[[:space:]]+add'; then
    avail_gb=$(df -k . 2>/dev/null | awk 'NR==2 {print int($4/1048576)}')
    floor="${PLAN_CYCLE_DISK_FLOOR_GB:-30}"
    case "$avail_gb" in ''|*[!0-9]*) continue ;; esac
    [ "$avail_gb" -ge "$floor" ] && continue
    deny "$(printf '%s\n' \
      "Not enough disk for another worktree: ${avail_gb}G free, floor is ${floor}G." \
      "" \
      "  reclaim-space                        # dry run — see what it would free" \
      "  reclaim-space --yes --all-projects   # sweep, including worktree build/" \
      "" \
      "WHY THE FLOOR IS NOT HOUSEKEEPING: /System/Volumes/VM shares an APFS" \
      "container with these checkouts, so free disk IS swap headroom. A built" \
      "Flutter worktree costs ~2.5G, nearly all of it regenerable build/ output." \
      "Sweeping keeps every branch and every uncommitted file." \
      "" \
      "Set PLAN_CYCLE_DISK_FLOOR_GB to move the floor if you have measured that it is wrong.")"
  fi
done < <(segments)

exit 0
