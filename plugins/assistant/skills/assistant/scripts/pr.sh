#!/usr/bin/env bash
# asst-pr — a task's PR is opened as a DRAFT and turned ready only at the delivery summary.
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
#          look once at CI on the pushed HEAD and print every check
#        asst-pr merged <task-slug> <worktree>
#          look once at whether the task's PR merged, closed, or is still open
#          (run when the user says it can merge or has merged — never scheduled)
#        asst-pr release <label> <checkout> [--dry-run | --run <id>]
#          base_branch: projects only — list what base_branch's head carries
#          that the default branch lacks, then start the repo's release.yml on
#          that commit (it fast-forwards the default branch and deploys) and
#          print its run id; --dry-run lists and starts nothing. With --run, look
#          once at that run: RELEASED, or RELEASE NOT PUSHED with the user's push
#          command when the default branch never moved, or RELEASE FAILED with
#          the run's link when it moved
#        asst-pr ready <task-slug> <worktree>
#          refuse unless: the tree is clean and pushed; the PR exists, targets
#          the project config's base_branch (else the default branch) and has a
#          description; every verify-* report the project config
#          requires was filed after HEAD's commit, and an
#          `exempt:` verify-code covers at most 20 changed lines; CI on HEAD
#          passed. A PR that is already ready is checked the same way. A draft
#          whose every check skipped is turned ready so CI runs, and exits 3
# Nothing waits: every outcome ends with a `next:` line, and one not settled yet
# names the look to schedule once (CronCreate) a few minutes out.
# Reports: verify-code always · verify-coverage when the project config's coverage: is a
# command (not none or ci) · verify-text when ui_strings: is set and the PR's
# diff touches it · verify-device when device_test: is a command, and its first
# line must be `device: passed` (asst-device).
# Exit: 0 done (merged: merged) · 1 refused, a check failed, (merged) closed without
# merging, or (release --run) the run failed · 2 usage, not a git task, CI
# unreadable, or no PR possible here (gh missing or unauthenticated, no GitHub
# remote) · 3 not settled yet: CI still running or not yet run on HEAD, the PR
# still open, or the release run still going.
#
# On a repo not known to be private, `open` refuses to push, and `ready` to turn
# ready, while the commits, the diff or the PR body name something from outside
# the repo (disclosure.sh): a push to a public repo cannot be taken back.
set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/root.sh"; source "$here/github.sh"; source "$here/disclosure.sh"
op="${1:-}"; slug="${2:-}"; wt="${3:-}"
usage() { sed -n '10,42p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
[ -n "$op" ] && [ -n "$slug" ] && [ -n "$wt" ] || usage
shift 3
[ -d "$wt" ] || { echo "asst-pr: no worktree at $wt" >&2; exit 2; }
root=$(cd "$wt" && asst_root)
config="$root/.claude/assistant.md"
field() { sed -nE "s/^$1:[[:space:]]*([^#]*[^#[:space:]]).*/\1/p" "$config" 2>/dev/null | head -1; }
if [ "$(field vcs)" = svn ]; then
  [ "$op" = release ] && { echo "asst-pr: vcs is svn — base_branch and releases are git only; an svn task ends in svn commit after the delivery summary" >&2; exit 2; }
  echo "asst-pr: vcs is svn — there is no PR; the task ends in svn commit after the delivery summary" >&2; exit 2
fi

g() { git -C "$wt" "$@"; }
branch=$(g symbolic-ref --quiet --short HEAD) || { echo "asst-pr: $wt is on a detached HEAD" >&2; exit 2; }
default=$(g symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); default=${default#origin/}; default=${default:-main}
# Task PRs go into the project config's base_branch when it names one (e.g. staging,
# which deploys to a test environment); a release then carries it into the
# default branch.
target=$(field base_branch); case "$target" in ""|none) target=$default ;; esac
refuse() { printf 'asst-pr: NOT READY — %s\n' "$1" >&2; exit 1; }
# Nothing here waits: an outcome that isn't settled yet names the one look to
# schedule, and the session that scheduled it wakes for that look.
later() { echo "next: schedule '$1' to run once in $2 minutes (CronCreate, recurring: false), then end the turn — never wait in a loop"; }
github() {
  local why; why=$(gh_unusable "$wt")
  [ -z "$why" ] && return 0
  printf 'asst-pr: NO PR POSSIBLE HERE — %s. %s\n' "$why" "$1" >&2; exit 2
}
# One look at CI on the PR's head commit: prints every check, then the verdict.
# Returns 0 passed · 1 failed · 2 unreadable · 3 running. No check reported yet
# counts as running while the repo has workflows, else as passed. On a draft
# ($draft=true) whose every check skipped, CI hasn't run at all — many repos
# skip drafts — so that's 3 too, with ci_unrun=1, never a pass.
ci_unrun=0
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
  if [ "${draft:-}" = true ] && ! grep -vqE '^skipping ' <<< "$out"; then
    ci_unrun=1
    echo "asst-pr: CI NOT RUN — every check skipped on this draft; CI runs once the PR is ready"; return 3
  fi
  echo "asst-pr: CI PASSED"
}

case "$op" in
  open)
    [ "$branch" != "$default" ] && [ "$branch" != "$target" ] \
      || { echo "asst-pr: $branch is the branch task PRs go into — a task PR comes from its own branch" >&2; exit 2; }
    body="" prev=""
    for a in "$@"; do
      case "$prev" in --body|-b) body+="$a"$'\n' ;; --body-file|-F) body+="$(cat -- "$a" 2>/dev/null)"$'\n' ;; esac
      prev=$a
    done
    leaks=$(disclosure_leaks "$wt" "origin/$target" "$body")
    [ -z "$leaks" ] || { printf 'asst-pr: NOT PUSHED — this repo is not known to be private, and this would publish (SKILL.md §Disclosure):\n%s\n' "$leaks" >&2; exit 1; }
    g push --quiet -u origin HEAD || { echo "asst-pr: push failed" >&2; exit 1; }
    github "$branch is pushed; the PR is the user's to open — report it as a \`Needs you\` line."
    url=$(cd "$wt" && gh pr view "$branch" --json url --jq .url 2>/dev/null) && { echo "$url"; exit 0; }
    case " $* " in *" --title "*|*" -t "*|*" --fill "*) ;; *) set -- "$@" --fill ;; esac
    (cd "$wt" && gh pr create --draft --base "$target" --head "$branch" "$@") ;;
  release)
    [ "$target" != "$default" ] || { echo "asst-pr: the project config names no base_branch — task PRs go straight into $default, so there is nothing to release" >&2; exit 2; }
    dry="" run=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --dry-run) dry=1; shift ;;
        --run) run=${2:-}; [[ $run =~ ^[0-9]+$ ]] || usage; shift 2 ;;
        *) usage ;;
      esac
    done
    if [ -n "$run" ]; then
      # One look at a release run this command started earlier.
      github "There is no run to look at."
      repo=$(cd "$wt" && gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
      [ -n "$repo" ] || { echo "asst-pr: can't tell which GitHub repo $wt is — check run $run in Actions" >&2; exit 2; }
      look=$(gh run view "$run" --repo "$repo" --json status,conclusion,url,displayTitle \
        --jq '[.status, (.conclusion // ""), .url, .displayTitle] | join("\t")' 2>/dev/null) \
        || { echo "asst-pr: can't read run $run on $repo" >&2; exit 2; }
      IFS=$'\t' read -r status conclusion url title <<< "$look"
      sha=$(grep -oE '[0-9a-f]{40}' <<< "$title" | head -1)
      [ "$status" = completed ] || { echo "asst-pr: release run $run still running — $url"; later "asst-pr release $slug $wt --run $run" 5; exit 3; }
      echo "asst-pr: run $run $(tr '[:lower:]' '[:upper:]' <<< "$conclusion") — $url"
      if [ "$conclusion" = success ]; then
        echo "asst-pr: RELEASED — $default is at ${sha:0:7} and production is deployed"
        echo "next: tell the user it's released"; exit 0
      fi
      # Whether the default branch moved tells a refused push from a failed
      # deploy, whatever each repo names its steps. GITHUB_TOKEN can't push a
      # commit that changes .github/workflows/, so such a release always ends
      # here, and the user's own push does what release.yml couldn't.
      at=$(g ls-remote origin "refs/heads/$default" | cut -f1)
      if [ "$at" != "$sha" ]; then
        echo "asst-pr: RELEASE NOT PUSHED — $default never moved to ${sha:0:7}. The user pushes it, and that push deploys: git fetch origin && git push origin $sha:refs/heads/$default"
        echo "next: give the user that push command as a Needs you line"
      else
        echo "asst-pr: RELEASE FAILED — $default is at ${sha:0:7}, but the run failed after that — $url"
        echo "next: report the run's link to the user; there is no push to offer"
      fi
      exit 1
    fi
    g fetch --quiet origin "$default" "$target" || { echo "asst-pr: can't fetch $default and $target" >&2; exit 2; }
    sha=$(g rev-parse "origin/$target")
    # Only a fast-forward is released: a release PR would make base_branch its
    # head, and a repo that deletes head branches after merge deletes it.
    g merge-base --is-ancestor "origin/$default" "$sha" \
      || { echo "asst-pr: $target doesn't contain $default — merge $default into $target first" >&2; exit 1; }
    carried=$(g log --first-parent --format='- %s' "origin/$default..$sha")
    [ -n "$carried" ] || { echo "asst-pr: $target has nothing that $default lacks — nothing to release"; exit 0; }
    echo "asst-pr: release $slug carries ${sha:0:7} into $default:"
    echo "$carried"
    [ -z "$dry" ] || exit 0
    [ -f "$wt/.github/workflows/release.yml" ] \
      || { echo "asst-pr: no .github/workflows/release.yml here — the user fast-forwards $default: git push origin $sha:refs/heads/$default" >&2; exit 2; }
    github "The release is the user's to start — report it as a \`Needs you\` line."
    # The commit listed above is the one released, whatever reaches the
    # branch meanwhile.
    (cd "$wt" && gh workflow run release.yml --ref "$default" -f "sha=$sha") || exit 2
    echo "asst-pr: release.yml started on ${sha:0:7}"
    repo=$(cd "$wt" && gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
    [ -n "$repo" ] || { echo "asst-pr: can't tell which GitHub repo $wt is — check the run in Actions" >&2; exit 2; }
    # The run is found by its title, which release.yml sets to carry the SHA
    # (run-name); a just-dispatched run takes a moment to be listed.
    run=""
    for wait_s in 2 3 5 10; do
      sleep "$wait_s"
      run=$(gh run list --repo "$repo" --workflow release.yml --event workflow_dispatch --limit 20 \
        --json databaseId,displayTitle --jq ".[] | select(.displayTitle | contains(\"$sha\")) | .databaseId" 2>/dev/null | head -1)
      [ -n "$run" ] && break
    done
    [ -n "$run" ] || { echo "asst-pr: no release.yml run titled with $sha — give release.yml \`run-name: Release \${{ inputs.sha }}\`, and check the run in Actions" >&2; exit 2; }
    echo "asst-pr: release run $run started — never run release again for ${sha:0:7}, which would start a second run"
    later "asst-pr release $slug $wt --run $run" 5
    exit 3 ;;
  checks)
    [ "$(g rev-parse HEAD)" = "$(g rev-parse '@{u}' 2>/dev/null)" ] || refuse "HEAD is not pushed, so CI has not seen it — run asst-pr open first"
    github "There is no CI to read."
    pr=$(cd "$wt" && gh pr view "$branch" --json number,isDraft,baseRefName --jq '"\(.number) \(.isDraft) \(.baseRefName)"' 2>/dev/null) \
      || refuse "no PR for $branch — asst-pr open never ran"
    read -r _ draft _ <<< "$pr"
    ci; rc=$?
    case $rc in
      0) echo "next: run asst-pr ready $slug $wt" ;;
      1) echo "next: fix the failing check and push, then look again" ;;
      3) later "asst-pr checks $slug $wt" 5 ;;
    esac
    exit $rc ;;
  merged)
    github "There is no PR to look at."
    st=$(cd "$wt" && gh pr view "$branch" --json number,state,mergeCommit --jq '"\(.number) \(.state) \(.mergeCommit.oid // "")"' 2>/dev/null) \
      || refuse "no PR for $branch — asst-pr open never ran"
    read -r num state oid <<< "$st"
    case "$state" in
      MERGED) echo "asst-pr: #$num MERGED as ${oid:0:7}"; echo "next: close the task (step 8)"; exit 0 ;;
      CLOSED) echo "asst-pr: #$num CLOSED without merging"; echo "next: tell the user #$num closed without merging"; exit 1 ;;
      *) echo "asst-pr: #$num still open"; echo "next: wait for the user to say the PR can merge"; exit 3 ;;
    esac ;;
  ready)
    [ -z "$(g status --porcelain)" ] || refuse "uncommitted changes in $wt — commit first"
    [ "$(g rev-parse HEAD)" = "$(g rev-parse '@{u}' 2>/dev/null)" ] || refuse "HEAD is not pushed — run asst-pr open first"
    github "Nothing was checked — the delivery summary goes to the user with this line as a \`Needs you\` line."
    pr=$(cd "$wt" && gh pr view "$branch" --json number,isDraft,baseRefName --jq '"\(.number) \(.isDraft) \(.baseRefName)"' 2>/dev/null) \
      || refuse "no PR for $branch — asst-pr open never ran"
    read -r num draft base <<< "$pr"
    # A PR on top of an unmerged one looks mergeable on its own, and merging it
    # first lands the other PR's unfinished commits with it.
    if [ "$base" != "$target" ]; then
      [ "$base" = "$default" ] && refuse "#$num targets $default, but this project's task PRs go into $target — gh pr edit $num --base $target"
      refuse "#$num is stacked on $base — it stays a draft until that PR merges and this branch is merged with $target"
    fi
    body=$(cd "$wt" && gh pr view "$branch" --json body --jq .body 2>/dev/null)
    [ -n "${body//[[:space:]]/}" ] || refuse "#$num has no description — write its title and body from the delivery summary first (gh pr edit)"
    g fetch --quiet origin "$base" 2>/dev/null
    leaks=$(disclosure_leaks "$wt" "origin/$base" "$body")
    [ -z "$leaks" ] || refuse "this repo is not known to be private, and #$num publishes (SKILL.md §Disclosure):
$leaks"

    reviews="code"
    case "$(field coverage)" in none|ci|"") ;; *) reviews="$reviews coverage" ;; esac
    case "$(field device_test)" in none|"") ;; *) reviews="$reviews device" ;; esac
    glob=$(field ui_strings)
    if [ -n "$glob" ] && [ "$glob" != none ]; then
      while IFS= read -r f; do
        # shellcheck disable=SC2053 # $glob is a pattern on purpose
        [[ $f == $glob ]] && { reviews="$reviews text"; break; }
      done < <(g diff --name-only "origin/$base...HEAD" 2>/dev/null)
    fi

    # A report older than HEAD reviewed code that is not what ships.
    head_t=$(g log -1 --format=%ct)
    missing=""
    for review in $reviews; do
      f=$(cd "$wt" && bash "$here/report.sh" latest "$slug" "verify-$review" 2>/dev/null) \
        || { missing="$missing verify-$review(none)"; continue; }
      t=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")
      [ "$t" -ge "$head_t" ] || missing="$missing verify-$review(older than HEAD)"
    done
    [ -z "$missing" ] || refuse "verify reports missing or stale:$missing"
    # A device report is filed whatever the outcome; only a pass counts.
    if [[ " $reviews " == *" device "* ]]; then
      f=$(cd "$wt" && bash "$here/report.sh" latest "$slug" verify-device 2>/dev/null)
      first=$(head -1 "$f")
      [ "$first" = "device: passed" ] || refuse "verify-device says: $first — run asst-device again once every platform can pass"
    fi
    # The assistant may review a diff itself only as `exempt` (SKILL.md step 6),
    # and that verdict starts with `exempt:`. Past 20 lines it isn't exempt.
    f=$(cd "$wt" && bash "$here/report.sh" latest "$slug" verify-code 2>/dev/null)
    if head -1 "$f" | grep -q '^exempt:'; then
      n=$(g diff --numstat "origin/$base...HEAD" | awk '{ s += $1 + $2 } END { print s + 0 }')
      [ "$n" -le 20 ] || refuse "verify-code is an \`exempt:\` verdict, but the diff changes $n lines — dispatch the verifier's code review"
    fi
    ci; case $? in
      0) ;;
      1) refuse "a check failed on HEAD — fix it first" ;;
      3)
        if [ "$ci_unrun" = 1 ]; then
          (cd "$wt" && gh pr ready "$num") >/dev/null || exit 2
          echo "asst-pr: NOT READY — #$num is out of draft so CI can run, but nothing has passed yet" >&2
        else
          echo "asst-pr: NOT READY — CI is still running on HEAD" >&2
        fi
        later "asst-pr checks $slug $wt" 5
        exit 3 ;;
      *) exit 2 ;;
    esac
    if [ "$draft" = true ]; then (cd "$wt" && gh pr ready "$num") || exit 2; fi
    echo "asst-pr: #$num ready (reviews: $reviews)"
    echo "next: write the delivery summary"
    echo "next: wait for the user to say the PR can merge" ;;
  *) usage ;;
esac
