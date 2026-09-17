#!/usr/bin/env bash
# disk-floor.sh — PreToolUse(Bash): `git worktree add` is denied while free disk
# is under a floor, and pointed at `reclaim-space`.
#
# WHY THE FLOOR IS A MEMORY MEASURE
#   The macOS swapfile volume (/System/Volumes/VM) shares an APFS container with
#   the checkouts — same free pool. A new worktree's build output eats swap
#   headroom, and swap is what stands between memory pressure and a watchdog
#   reboot.
#
# WHY EVERY SURPRISE ALLOWS
#   This runs on every Bash call. A missing helper, an unreadable payload or an
#   unparsable `df` exits 0.

set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$cmd" ] || exit 0

printf '%s\n' "$cmd" | tr ';|&\n' '\n\n\n\n' | sed 's/^[[:space:]]*//' \
  | grep -qE '^git[[:space:]]+.*worktree[[:space:]]+add' || exit 0

avail_gb=$(df -k . 2>/dev/null | awk 'NR==2 {print int($4/1048576)}')
floor="${RECLAIM_DISK_FLOOR_GB:-30}"
case "$avail_gb" in ''|*[!0-9]*) exit 0 ;; esac
[ "$avail_gb" -ge "$floor" ] && exit 0

reason=$(printf '%s\n' \
  "Not enough disk for another worktree: ${avail_gb}G free, floor is ${floor}G." \
  "" \
  "  reclaim-space                        # dry run — see what it would free" \
  "  reclaim-space --yes --all-projects   # sweep, including worktree build output" \
  "" \
  "WHY THE FLOOR IS NOT HOUSEKEEPING: /System/Volumes/VM shares an APFS" \
  "container with these checkouts, so free disk IS swap headroom. The sweep" \
  "deletes only regenerable output and keeps every branch and uncommitted file." \
  "" \
  "Set RECLAIM_DISK_FLOOR_GB to move the floor if you have measured that it is wrong.")
jq -n --arg r "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse",
  permissionDecision: "deny", permissionDecisionReason: $r}}'
exit 0
