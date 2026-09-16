#!/usr/bin/env bash
# asst-budget — per-task round counters with hard caps. The counter lives in a file,
# not in prose, because "stop after N" is the discipline that lapses under context
# pressure. Every gate in the flow terminates here or on a script exit code.
#
# Usage: asst-budget spend <task-slug> <lint|review|fix|upload>   → prints "n/N"; exit 1 when the cap is hit
#        asst-budget show  <task-slug>
#        asst-budget reset <task-slug>
# Caps (edit here, nowhere else): lint 3 · review 1 · fix 2 · upload 2.
set -uo pipefail
root=$(git rev-parse --show-toplevel 2>/dev/null) || root=$PWD
dir="$root/.claude/.assistant/budget"; op="${1:-}"; slug="${2:-}"; kind="${3:-}"
[ -n "$op" ] && [ -n "$slug" ] || { sed -n '6,9p' "$0" >&2; exit 2; }
f="$dir/$slug"; mkdir -p "$dir"; touch "$f"
cap() { case "$1" in lint) echo 3;; review) echo 1;; fix) echo 2;; upload) echo 2;; *) echo 0;; esac; }
case "$op" in
  spend)
    [ "$(cap "$kind")" -gt 0 ] || { echo "asst-budget: kind must be lint|review|fix|upload" >&2; exit 2; }
    n=$(( $(grep -c "^$kind$" "$f") + 1 )); echo "$kind" >> "$f"; c=$(cap "$kind")
    if [ "$n" -gt "$c" ]; then echo "asst-budget: $kind $n/$c — CAP HIT. Stop: record the residue as debt, cut scope, or raise it as 需要你."; exit 1; fi
    echo "asst-budget: $kind $n/$c" ;;
  show)  for k in lint review fix upload; do echo "$k $(grep -c "^$k$" "$f")/$(cap $k)"; done ;;
  reset) rm -f "$f"; echo "asst-budget: $slug reset" ;;
  *) sed -n '6,9p' "$0" >&2; exit 2 ;;
esac
