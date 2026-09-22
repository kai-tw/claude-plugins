#!/usr/bin/env bash
# asst-report — every agent report lands on disk before it is returned. The
# assistant's context gets compacted, and a report held only there is lost with it;
# a row waiting on a lost report waits forever.
#
# Usage: asst-report put    <task-slug> <kind> [--worktree <dir>] [--no-post]
#                           (report on stdin) → prints the path
#        asst-report latest <task-slug> <kind>   → prints the newest path; exit 1 if none
#        asst-report list   <task-slug>
# kind: scout · brief-review · build-<phase> · verify-<leg>
#
# A verify-<leg> report is also posted to the task's PR as a comment: the founder
# merges from the PR page, so a leg missing there is seen before the merge, not
# found in a directory nobody opens. The file stays the record the gates read.
# --worktree names the task's checkout when the caller is not in it; --no-post
# is for a report that is already on the PR (a cloud session's). When nothing is
# posted, stderr says why — the file is filed either way.
set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/root.sh"; source "$here/github.sh"
op="${1:-}"; slug="${2:-}"; kind="${3:-}"
usage() { sed -n '6,10p' "$0" >&2; exit 2; }
[ -n "$op" ] && [ -n "$slug" ] || usage
wt=$PWD; post=1
if [ "$op" = put ]; then
  shift 3 2>/dev/null
  while [ $# -gt 0 ]; do
    case "$1" in
      --worktree) wt="${2:-}"; shift 2 ;;
      --no-post)  post=0; shift ;;
      *) usage ;;
    esac
  done
  [ -d "$wt" ] || { echo "asst-report: no worktree at $wt" >&2; exit 2; }
fi
root=$(cd "$wt" && asst_root)
dir="$root/.claude/.assistant/reports/$slug"
# Round numbers of <kind>, ascending — the n in <kind>-<n>.md.
rounds() { ls "$dir" 2>/dev/null | sed -nE "s/^${kind}-([0-9]+)\.md$/\1/p" | sort -n; }

# Post $1 to the PR of the branch checked out in $wt, or say why not.
post_to_pr() {
  local f=$1 name branch why num
  name=$(basename "$f" .md)
  skip() { echo "asst-report: $name NOT posted to a PR — $1 (filed at $f)" >&2; }
  branch=$(git -C "$wt" symbolic-ref --quiet --short HEAD 2>/dev/null) || { skip "$wt is not on a git branch"; return; }
  git -C "$wt" rev-parse --verify --quiet '@{u}' >/dev/null || { skip "$branch has no upstream, so no PR"; return; }
  why=$(gh_unusable "$wt"); [ -z "$why" ] || { skip "$why"; return; }
  num=$(cd "$wt" && gh pr view "$branch" --json number --jq .number 2>/dev/null) || { skip "no PR for $branch"; return; }
  { printf 'assistant-report %s %s @ %s\n\n' "$slug" "$name" "$(git -C "$wt" rev-parse --short HEAD)"; cat "$f"; } \
    | (cd "$wt" && gh pr comment "$num" --body-file - >/dev/null) \
    || { skip "gh pr comment failed on #$num"; return; }
  echo "asst-report: $name posted to #$num" >&2
}

case "$op" in
  put)
    [ -n "$kind" ] || usage
    mkdir -p "$dir"
    n=$(( $(rounds | tail -1) + 1 ))
    f="$dir/$kind-$n.md"; cat > "$f.partial"
    if [ ! -s "$f.partial" ]; then
      rm -f "$f.partial"; echo "asst-report: empty report on stdin — nothing filed" >&2; exit 1
    fi
    mv -f "$f.partial" "$f"; echo "$f"
    case "$kind" in verify-*) [ "$post" = 1 ] && post_to_pr "$f" ;; esac ;;
  latest)
    [ -n "$kind" ] || usage
    n=$(rounds | tail -1)
    [ -n "$n" ] || { echo "asst-report: no $kind report for $slug" >&2; exit 1; }
    echo "$dir/$kind-$n.md" ;;
  list) ls "$dir" 2>/dev/null ;;
  *) usage ;;
esac
