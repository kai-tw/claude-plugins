#!/usr/bin/env bash
# asst-pr — a task's PR is opened as a DRAFT and turned ready only at ③.
#
# A PR that looks mergeable gets merged: opened ready while agents were still
# working, one was merged before its work was done. A draft cannot be merged, so
# `open` hard-codes --draft, and `ready` refuses until every stage it can check
# is complete. A hook cannot hold this line — hooks do not reach sub-agents, and
# the Builder is one; a script it calls by bare name does.
#
# Usage: asst-pr open  <task-slug> <worktree> [gh pr create flags…]
#          push the branch, then ensure a draft PR exists for it → prints the URL
#        asst-pr ready <task-slug> <worktree>
#          refuse unless: the tree is clean and pushed; the PR exists; every
#          verify leg the adapter requires has a report filed after HEAD's commit
# Legs: verify-code always · verify-coverage / verify-mutation when the adapter's
# coverage: / mutation: are set · verify-text when ui_strings: is set and the
# PR's diff touches it. Exit: 0 done · 1 refused · 2 usage or not a git task.
set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/root.sh"
op="${1:-}"; slug="${2:-}"; wt="${3:-}"
usage() { sed -n '10,17p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
[ -n "$op" ] && [ -n "$slug" ] && [ -n "$wt" ] || usage
shift 3
[ -d "$wt" ] || { echo "asst-pr: no worktree at $wt" >&2; exit 2; }
root=$(cd "$wt" && asst_root)
adapter="$root/.claude/assistant.md"
field() { sed -nE "s/^$1:[[:space:]]*([^#]*[^#[:space:]]).*/\1/p" "$adapter" 2>/dev/null | head -1; }
[ "$(field vcs)" = svn ] && { echo "asst-pr: vcs is svn — there is no PR; ③ ends in svn commit" >&2; exit 2; }

g() { git -C "$wt" "$@"; }
branch=$(g symbolic-ref --quiet --short HEAD) || { echo "asst-pr: $wt is on a detached HEAD" >&2; exit 2; }
refuse() { printf 'asst-pr: NOT READY — %s\n' "$1" >&2; exit 1; }

case "$op" in
  open)
    default=$(g symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); default=${default#origin/}
    [ "$branch" != "${default:-main}" ] || { echo "asst-pr: $branch is the default branch — a task PR comes from its own branch" >&2; exit 2; }
    g push --quiet -u origin HEAD || { echo "asst-pr: push failed" >&2; exit 1; }
    url=$(cd "$wt" && gh pr view "$branch" --json url --jq .url 2>/dev/null) && { echo "$url"; exit 0; }
    case " $* " in *" --title "*|*" -t "*|*" --fill "*) ;; *) set -- "$@" --fill ;; esac
    (cd "$wt" && gh pr create --draft --head "$branch" "$@") ;;
  ready)
    [ -z "$(g status --porcelain)" ] || refuse "uncommitted changes in $wt — checkpoint first"
    [ "$(g rev-parse HEAD)" = "$(g rev-parse '@{u}' 2>/dev/null)" ] || refuse "HEAD is not pushed — run asst-pr open first"
    pr=$(cd "$wt" && gh pr view "$branch" --json number,isDraft,baseRefName --jq '"\(.number) \(.isDraft) \(.baseRefName)"' 2>/dev/null) \
      || refuse "no PR for $branch — asst-pr open never ran"
    read -r num draft base <<< "$pr"
    [ "$draft" = true ] || { echo "asst-pr: #$num is already ready"; exit 0; }

    legs="code"
    [ "$(field coverage)" != none ] && [ -n "$(field coverage)" ] && legs="$legs coverage"
    [ "$(field mutation)" != none ] && [ -n "$(field mutation)" ] && legs="$legs mutation"
    glob=$(field ui_strings)
    if [ -n "$glob" ] && [ "$glob" != none ]; then
      g fetch --quiet origin "$base" 2>/dev/null
      while IFS= read -r f; do
        # shellcheck disable=SC2053 # $glob is a pattern on purpose
        [[ $f == $glob ]] && { legs="$legs text"; break; }
      done < <(g diff --name-only "origin/$base...HEAD" 2>/dev/null)
    fi

    # A report older than HEAD graded code that is not what ships.
    head_t=$(g log -1 --format=%ct)
    missing=""
    for leg in $legs; do
      f=$(cd "$wt" && bash "$here/report.sh" latest "$slug" "verify-$leg" 2>/dev/null) \
        || { missing="$missing verify-$leg(none)"; continue; }
      t=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")
      [ "$t" -ge "$head_t" ] || missing="$missing verify-$leg(older than HEAD)"
    done
    [ -z "$missing" ] || refuse "verify reports missing or stale:$missing"
    (cd "$wt" && gh pr ready "$num") && echo "asst-pr: #$num ready (legs: $legs)" ;;
  *) usage ;;
esac
