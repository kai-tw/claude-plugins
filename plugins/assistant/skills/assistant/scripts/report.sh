#!/usr/bin/env bash
# asst-report — every agent report lands on disk before it is returned. The
# assistant's context gets compacted, and a report held only there is lost with it;
# a row waiting on a lost report waits forever.
#
# Usage: asst-report put    <task-slug> <kind>   (report on stdin) → prints the path
#        asst-report latest <task-slug> <kind>   → prints the newest path; exit 1 if none
#        asst-report list   <task-slug>
# kind: scout · brief-review · build-<phase> · verify-<leg>
set -uo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/state_root.sh"
op="${1:-}"; slug="${2:-}"; kind="${3:-}"
usage() { sed -n '6,9p' "$0" >&2; exit 2; }
[ -n "$op" ] && [ -n "$slug" ] || usage
dir="$state/reports/$slug"
# Round numbers of <kind>, ascending — the n in <kind>-<n>.md.
rounds() { ls "$dir" 2>/dev/null | sed -nE "s/^${kind}-([0-9]+)\.md$/\1/p" | sort -n; }
case "$op" in
  put)
    [ -n "$kind" ] || usage
    mkdir -p "$dir"
    n=$(( $(rounds | tail -1) + 1 ))
    f="$dir/$kind-$n.md"; cat > "$f.partial"
    if [ ! -s "$f.partial" ]; then
      rm -f "$f.partial"; echo "asst-report: empty report on stdin — nothing filed" >&2; exit 1
    fi
    mv -f "$f.partial" "$f"; echo "$f" ;;
  latest)
    [ -n "$kind" ] || usage
    n=$(rounds | tail -1)
    [ -n "$n" ] || { echo "asst-report: no $kind report for $slug" >&2; exit 1; }
    echo "$dir/$kind-$n.md" ;;
  list) ls "$dir" 2>/dev/null ;;
  *) usage ;;
esac
