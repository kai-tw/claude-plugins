#!/usr/bin/env bash
# asst-budget — per-task round counters; review and upload have hard caps, fix has none.
# The counter lives in a file, not in prose, because "stop after N" is the discipline
# that lapses under context pressure.
#
# Usage: asst-budget spend <task-slug> <review|fix|upload>   → prints "n/N" ("n" for fix); exit 1 when a cap is hit
#        asst-budget show  <task-slug>
#        asst-budget reset <task-slug>
# Caps (edit here, nowhere else): review 1 · upload 2 · fix none.
set -uo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/root.sh"; root=$(asst_root)
dir="$root/.claude/.assistant/budget"; op="${1:-}"; slug="${2:-}"; kind="${3:-}"
[ -n "$op" ] && [ -n "$slug" ] || { sed -n '6,9p' "$0" >&2; exit 2; }
f="$dir/$slug"; mkdir -p "$dir"; touch "$f"
cap() { case "$1" in review) echo /1;; fix) echo "";; upload) echo /2;; *) echo -;; esac; }
case "$op" in
  spend)
    c=$(cap "$kind"); [ "$c" != - ] || { echo "asst-budget: kind must be review|fix|upload" >&2; exit 2; }
    n=$(( $(grep -c "^$kind$" "$f") + 1 )); echo "$kind" >> "$f"
    if [ -n "$c" ] && [ "$n" -gt "${c#/}" ]; then echo "asst-budget: $kind $n$c — CAP HIT. Stop: cut scope, or raise it as a 'Needs you' line."; exit 1; fi
    echo "asst-budget: $kind $n$c" ;;
  show)  for k in review fix upload; do echo "$k $(grep -c "^$k$" "$f")$(cap $k)"; done ;;
  reset) rm -f "$f"; echo "asst-budget: $slug reset" ;;
  *) sed -n '6,9p' "$0" >&2; exit 2 ;;
esac
