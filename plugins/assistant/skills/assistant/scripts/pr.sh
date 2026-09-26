#!/usr/bin/env bash
# asst-pr — a task's PR is opened as a DRAFT and turned ready only at ③.
#
# A PR that looks mergeable gets merged: opened ready while agents were still
# working, one was merged before its work was done. A draft cannot be merged, so
# `open` hard-codes --draft, and `ready` refuses until every stage it can check
# is complete. Those stages are the task's own state (its worktree, its verify
# reports), which a hook on a bare `gh` command cannot see.
#
# Usage: asst-pr open  <task-slug> <worktree> [gh pr create flags…]
#          push the branch, then ensure a draft PR exists for it → prints the URL
#        asst-pr ready <task-slug> <worktree>
#          refuse unless: the tree is clean and pushed; the PR exists; every
#          verify leg the adapter requires has a report filed after HEAD's commit
# Legs: verify-code always · verify-coverage / verify-mutation when the adapter's
# coverage: / mutation: are set · verify-text when ui_strings: is set and the
# PR's diff touches it. Exit: 0 done · 1 refused · 2 usage, not a git task, or no
# PR possible here (gh missing or unauthenticated, no GitHub remote).
#
# On a repo not known to be private, `open` refuses to push, and `ready` to turn
# ready, while the commits, the diff or the PR body name something from outside
# the repo (disclosure.sh): a push to a public repo cannot be taken back.
set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/root.sh"; source "$here/github.sh"; source "$here/disclosure.sh"
op="${1:-}"; slug="${2:-}"; wt="${3:-}"
usage() { sed -n '10,18p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
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
github() {
  local why; why=$(gh_unusable "$wt")
  [ -z "$why" ] && return 0
  printf 'asst-pr: NO PR POSSIBLE HERE — %s. %s\n' "$why" "$1" >&2; exit 2
}

case "$op" in
  open)
    default=$(g symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); default=${default#origin/}
    [ "$branch" != "${default:-main}" ] || { echo "asst-pr: $branch is the default branch — a task PR comes from its own branch" >&2; exit 2; }
    body="" prev=""
    for a in "$@"; do
      case "$prev" in --body|-b) body+="$a"$'\n' ;; --body-file|-F) body+="$(cat -- "$a" 2>/dev/null)"$'\n' ;; esac
      prev=$a
    done
    leaks=$(disclosure_leaks "$wt" "origin/${default:-main}" "$body")
    [ -z "$leaks" ] || { printf 'asst-pr: NOT PUSHED — this repo is not known to be private, and this would publish (SKILL.md §Disclosure):\n%s\n' "$leaks" >&2; exit 1; }
    g push --quiet -u origin HEAD || { echo "asst-pr: push failed" >&2; exit 1; }
    github "$branch is pushed; the PR is the founder's to open — report it as a \`Needs you\` line."
    url=$(cd "$wt" && gh pr view "$branch" --json url --jq .url 2>/dev/null) && { echo "$url"; exit 0; }
    case " $* " in *" --title "*|*" -t "*|*" --fill "*) ;; *) set -- "$@" --fill ;; esac
    (cd "$wt" && gh pr create --draft --head "$branch" "$@") ;;
  ready)
    [ -z "$(g status --porcelain)" ] || refuse "uncommitted changes in $wt — checkpoint first"
    [ "$(g rev-parse HEAD)" = "$(g rev-parse '@{u}' 2>/dev/null)" ] || refuse "HEAD is not pushed — run asst-pr open first"
    github "Nothing was checked — ③ goes to the founder with this line as a \`Needs you\` line."
    pr=$(cd "$wt" && gh pr view "$branch" --json number,isDraft,baseRefName --jq '"\(.number) \(.isDraft) \(.baseRefName)"' 2>/dev/null) \
      || refuse "no PR for $branch — asst-pr open never ran"
    read -r num draft base <<< "$pr"
    [ "$draft" = true ] || { echo "asst-pr: #$num is already ready"; exit 0; }
    g fetch --quiet origin "$base" 2>/dev/null
    leaks=$(disclosure_leaks "$wt" "origin/$base" "$(cd "$wt" && gh pr view "$branch" --json body --jq .body 2>/dev/null)")
    [ -z "$leaks" ] || refuse "this repo is not known to be private, and #$num publishes (SKILL.md §Disclosure):
$leaks"

    legs="code"
    [ "$(field coverage)" != none ] && [ -n "$(field coverage)" ] && legs="$legs coverage"
    [ "$(field mutation)" != none ] && [ -n "$(field mutation)" ] && legs="$legs mutation"
    glob=$(field ui_strings)
    if [ -n "$glob" ] && [ "$glob" != none ]; then
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
