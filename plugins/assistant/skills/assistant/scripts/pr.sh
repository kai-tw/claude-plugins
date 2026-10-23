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
#        asst-pr checks <task-slug> <worktree>
#          look once at CI on the pushed HEAD and print every check; never waits
#        asst-pr watch <task-slug> <worktree> [--timeout <minutes>, default 60]
#          wait for CI on the pushed HEAD to finish, then print what checks would;
#          one per PR, any number of PRs at once (pr-watch.mjs)
#        asst-pr ready <task-slug> <worktree>
#          refuse unless: the tree is clean and pushed; the PR exists, targets
#          the default branch and has a description; every verify leg the
#          adapter requires has a report filed after HEAD's commit; CI on HEAD passed
# Legs: verify-code always · verify-coverage when the adapter's coverage: is a
# command (not none or ci) · verify-text when ui_strings: is set and the PR's
# diff touches it.
# Exit: 0 done · 1 refused, or a check failed · 2 usage, not a git task, CI
# unreadable, or no PR possible here (gh missing or unauthenticated, no GitHub
# remote), or the PR already watched · 3 CI still running on HEAD.
#
# On a repo not known to be private, `open` refuses to push, and `ready` to turn
# ready, while the commits, the diff or the PR body name something from outside
# the repo (disclosure.sh): a push to a public repo cannot be taken back.
set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/root.sh"; source "$here/github.sh"; source "$here/disclosure.sh"
op="${1:-}"; slug="${2:-}"; wt="${3:-}"
usage() { sed -n '10,25p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
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
# One look at CI on the PR's head commit: prints every check, then the verdict.
# Returns 0 passed · 1 failed · 2 unreadable · 3 running. No check reported yet
# counts as running while the repo has workflows, else as passed.
ci() {
  local out fail run
  out=$(cd "$wt" && gh pr checks "$branch" --json bucket,name --jq '.[] | "\(.bucket) \(.name)"' 2>&1)
  if [ -z "$out" ] || [[ $out == *"no checks reported"* ]]; then
    compgen -G "$wt/.github/workflows/*.y*ml" >/dev/null \
      || { echo "asst-pr: CI PASSED — this repo has no workflows"; return 0; }
    echo "asst-pr: CI RUNNING — no check has reported on $branch yet"; return 3
  fi
  grep -vqE '^(pass|fail|pending|skipping|cancel) ' <<< "$out" \
    && { printf 'asst-pr: CI UNREADABLE — %s\n' "$out" >&2; return 2; }
  sed 's/^/  /' <<< "$out"
  names() { awk -v b="$1" '$1 ~ b { sub(/^[^ ]+ /, ""); print }' <<< "$out" | paste -sd, - | sed 's/,/, /g'; }
  fail=$(names '^(fail|cancel)$'); run=$(names '^pending$')
  [ -z "$fail" ] || { echo "asst-pr: CI FAILED — $fail"; return 1; }
  [ -z "$run" ] || { echo "asst-pr: CI RUNNING — $run"; return 3; }
  echo "asst-pr: CI PASSED"
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
  checks)
    [ "$(g rev-parse HEAD)" = "$(g rev-parse '@{u}' 2>/dev/null)" ] || refuse "HEAD is not pushed, so CI has not seen it — run asst-pr open first"
    github "There is no CI to read."
    (cd "$wt" && gh pr view "$branch" --json number >/dev/null 2>&1) || refuse "no PR for $branch — asst-pr open never ran"
    ci ;;
  watch)
    mins=60
    case "${1:-}" in --timeout) mins=${2:-}; [[ $mins =~ ^[0-9]+(\.[0-9]+)?$ ]] || usage ;; "") ;; *) usage ;; esac
    [ "$(g rev-parse HEAD)" = "$(g rev-parse '@{u}' 2>/dev/null)" ] || refuse "HEAD is not pushed, so CI has not seen it — run asst-pr open first"
    github "There is no CI to watch."
    num=$(cd "$wt" && gh pr view "$branch" --json number --jq .number 2>/dev/null) && [ -n "$num" ] \
      || refuse "no PR for $branch — asst-pr open never ran"
    repo=$(cd "$wt" && gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
    [ -n "$repo" ] || { echo "asst-pr: can't tell which GitHub repo $wt is" >&2; exit 2; }
    wt=$(cd "$wt" && pwd)
    exec node "$here/pr-watch.mjs" "$repo" "$num" "$(g rev-parse HEAD)" "$mins" bash "$here/pr.sh" checks "$slug" "$wt" ;;
  ready)
    [ -z "$(g status --porcelain)" ] || refuse "uncommitted changes in $wt — checkpoint first"
    [ "$(g rev-parse HEAD)" = "$(g rev-parse '@{u}' 2>/dev/null)" ] || refuse "HEAD is not pushed — run asst-pr open first"
    github "Nothing was checked — ③ goes to the founder with this line as a \`Needs you\` line."
    pr=$(cd "$wt" && gh pr view "$branch" --json number,isDraft,baseRefName --jq '"\(.number) \(.isDraft) \(.baseRefName)"' 2>/dev/null) \
      || refuse "no PR for $branch — asst-pr open never ran"
    read -r num draft base <<< "$pr"
    [ "$draft" = true ] || { echo "asst-pr: #$num is already ready"; exit 0; }
    # A PR on top of an unmerged one looks mergeable on its own, and merging it
    # first lands the other PR's unfinished commits with it.
    default=$(g symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); default=${default#origin/}
    [ "$base" = "${default:-main}" ] || refuse "#$num is stacked on $base — it stays a draft until that PR merges and this branch is merged with ${default:-main}"
    body=$(cd "$wt" && gh pr view "$branch" --json body --jq .body 2>/dev/null)
    [ -n "${body//[[:space:]]/}" ] || refuse "#$num has no description — write its title and body from ③ first (gh pr edit)"
    g fetch --quiet origin "$base" 2>/dev/null
    leaks=$(disclosure_leaks "$wt" "origin/$base" "$body")
    [ -z "$leaks" ] || refuse "this repo is not known to be private, and #$num publishes (SKILL.md §Disclosure):
$leaks"

    legs="code"
    case "$(field coverage)" in none|ci|"") ;; *) legs="$legs coverage" ;; esac
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
    ci; case $? in
      0) ;;
      1) refuse "a check failed on HEAD — fix it first" ;;
      3) echo "asst-pr: NOT READY — CI is still running on HEAD" >&2; exit 3 ;;
      *) exit 2 ;;
    esac
    (cd "$wt" && gh pr ready "$num") && echo "asst-pr: #$num ready (legs: $legs)" ;;
  *) usage ;;
esac
