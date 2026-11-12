#!/usr/bin/env bash
# asst-report — every agent report lands on disk before it is returned. The
# assistant's context gets compacted, and a report held only there is lost with it;
# a row waiting on a lost report waits forever.
#
# Usage: asst-report put    <task-slug> <kind> [--worktree <dir>]
#                           (report on stdin) → prints the path
#        asst-report latest <task-slug> <kind>   → prints the newest path; exit 1 if none
#        asst-report list   <task-slug>
#        asst-report form   <kind>               → prints the form that kind's report fills in
#        asst-report summary                     → per task, its newest report of each kind
# kind: investigation · brief-review · build-<phase> · tests · verify-<review>
# --worktree names the task's checkout when the caller is not in it.
set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/root.sh"
op="${1:-}"; slug="${2:-}"; kind="${3:-}"
usage() { sed -n '6,12p' "$0" >&2; exit 2; }
# One form per report kind, the only copy of its shape; the agents print it here.
if [ "$op" = form ]; then
  k=${slug:-}; case "$k" in build-*) k=build ;; esac
  f="$here/../forms/$k.md"
  [ -n "$k" ] && [ -f "$f" ] || { echo "asst-report: no form for '${slug:-}' — kinds: $(ls "$here/../forms" | sed 's/\.md$//; s/^build$/build-<phase>/' | paste -sd ' ' -)" >&2; exit 2; }
  cat "$f"; exit 0
fi
# Every task's newest report of each kind, in one look: what a scheduler pass reads.
if [ "$op" = summary ]; then
  rd="$(asst_root)/.claude/.assistant/reports"
  for d in "$rd"/*/; do
    [ -d "$d" ] || continue
    s=$(basename "$d")
    line=$(ls "$d" | sed -nE 's/^(.+)-([0-9]+)\.md$/\1 \2/p' | sort -k1,1 -k2,2nr \
      | awk '!seen[$1]++ { printf "%s%s-%s", sep, $1, $2; sep=" · " }')
    echo "$s: ${line:-no reports}"
  done
  exit 0
fi
[ -n "$op" ] && [ -n "$slug" ] || usage
wt=$PWD
if [ "$op" = put ]; then
  shift 3 2>/dev/null
  while [ $# -gt 0 ]; do
    case "$1" in
      --worktree) wt="${2:-}"; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -d "$wt" ] || { echo "asst-report: no worktree at $wt" >&2; exit 2; }
fi
root=$(cd "$wt" && asst_root)
dir="$root/.claude/.assistant/reports/$slug"
# Older versions filed these kinds as scout and build-wire: a report under the old
# name is filed under the new one, and `latest` falls back to the old files.
case "$kind" in scout) kind=investigation ;; build-wire) kind=build-integration ;; esac
case "$kind" in investigation) old=scout ;; build-integration) old=build-wire ;; *) old="" ;; esac
# Round numbers of <kind> (default: $kind), ascending — the n in <kind>-<n>.md.
rounds() { ls "$dir" 2>/dev/null | sed -nE "s/^${1:-$kind}-([0-9]+)\.md$/\1/p" | sort -n; }

case "$op" in
  put)
    [ -n "$kind" ] || usage
    # A numbered kind files as <kind>-<n>-1.md, which `latest <kind>` never finds.
    [[ $kind =~ -[0-9]+$ ]] && { echo "asst-report: '$kind' carries a round number — pass the bare kind (${kind%-*}); put numbers the rounds itself" >&2; exit 2; }
    mkdir -p "$dir"
    n=$(( $(rounds | tail -1) + 1 ))
    f="$dir/$kind-$n.md"; cat > "$f.partial"
    if [ ! -s "$f.partial" ]; then
      rm -f "$f.partial"; echo "asst-report: empty report on stdin — nothing filed" >&2; exit 1
    fi
    # A builder or tester that never loaded the style pack writes code the verifier then
    # checks against rules it never saw.
    case "$kind" in build-ui|build-integration|build-fix|tests)
      grep -q '^rules: style-pack --paths ' "$f.partial" || {
        rm -f "$f.partial"
        echo "asst-report: NOT FILED — a $kind report needs the line 'rules: style-pack --paths <the files you touched>', naming the run you made before your first edit or test (builder.md, tester.md)" >&2
        exit 1
      } ;;
    esac
    mv -f "$f.partial" "$f"; echo "$f" ;;
  latest)
    [ -n "$kind" ] || usage
    n=$(rounds | tail -1); k=$kind
    [ -n "$n" ] || [ -z "$old" ] || { n=$(rounds "$old" | tail -1); k=$old; }
    [ -n "$n" ] || { echo "asst-report: no $kind report for $slug" >&2; exit 1; }
    echo "$dir/$k-$n.md" ;;
  list) ls "$dir" 2>/dev/null ;;
  *) usage ;;
esac
