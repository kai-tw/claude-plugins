#!/usr/bin/env bash
# asst-mutation-job — take one file from the mutation queue, mutation-test it
# on the default branch's tip, and report it. Mutation is too slow to gate a
# PR, so merged files wait in the queue (asst-mutation-queue) and routine
# sessions work through it (references/mutation-queue.md).
#
# Usage: asst-mutation-job      (from anywhere in the project's clone)
#   Claims a file, runs the adapter's `mutation:` (a plan-mutation command) on
#   it alone, reports to every PR queued for it, then drops it from the queue.
#   A pass is a comment on each of those PRs; a score under the threshold, or a
#   run that scored nothing, is one issue naming them all. With a usable gh it
#   posts itself and prints `posted: <url>`; without one it prints
#   `post: comment <pr…>` or `post: issue <title>`, then the body to post.
#   A file no longer on the default branch is dropped without a report.
# First line of output: `asst-mutation-job: PASS|FAIL|ERROR|GONE <file> @ <sha7> (PR #<n>, …)`,
# or `asst-mutation-job: queue empty`.
# Exit: 0 passed or gone · 1 scored under the threshold · 2 nothing scored ·
# 3 the queue had nothing to claim.
set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/root.sh"; source "$here/github.sh"
queue() { bash "$here/mutation-queue.sh" "$@"; }
root=$(asst_root); cd "$root" || exit 2
field() { sed -nE "s/^$1:[[:space:]]*([^#]*[^#[:space:]]).*/\1/p" .claude/assistant.md 2>/dev/null | head -1; }

job=$(queue claim); rc=$?
[ $rc = 3 ] && { echo "asst-mutation-job: queue empty"; exit 3; }
[ $rc = 0 ] || exit 2
read -r file prs <<< "$job"
refs=$(printf 'PR #%s, ' $prs); refs=${refs%, }
default=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); default=${default#origin/}
default=${default:-main}
log=$(mktemp)

run() {
  local cmd; cmd=$(field mutation)
  case "$cmd" in
    plan-mutation|plan-mutation\ *) ;;
    *) echo "the adapter's mutation: must be a plan-mutation command, not: ${cmd:-(unset)}"; return 2 ;;
  esac
  # --files reads paths up to `--`, so it goes right before the test command.
  # shellcheck disable=SC2086 # the adapter's command is a command line on purpose
  case "$cmd" in
    *" -- "*) ${cmd%% -- *} --files "$file" -- ${cmd#* -- } ;;
    *)        $cmd --files "$file" ;;
  esac
}
verdict=""
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then echo "uncommitted changes in $root" >"$log"; rc=2
elif ! git fetch --quiet origin "$default" || ! git checkout --quiet --detach "origin/$default"; then
  echo "cannot check out origin/$default" >"$log"; rc=2
elif [ ! -f "$file" ]; then verdict=GONE; rc=0
else run >"$log" 2>&1; rc=$?
fi
sha=$(git rev-parse --short=7 HEAD)
if [ -z "$verdict" ]; then
  if [ $rc = 0 ]; then verdict=PASS
  elif [ $rc = 1 ] && grep -q '^plan-mutation: BLOCKED\.' "$log"; then verdict=FAIL
  else verdict=ERROR; rc=2
  fi
fi
head="$file @ $sha ($refs)"
echo "asst-mutation-job: $verdict $head"

if [ $verdict != GONE ]; then
  body=$(printf 'asst-mutation-job: %s %s\n\n```\n%s\n```\n' "$verdict" "$head" "$(cat "$log")")
  title="mutation $verdict: $file ($refs)"
  why=$(gh_unusable "$root")
  if [ -z "$why" ]; then
    if [ $verdict = PASS ]; then
      for pr in $prs; do
        url=$(gh pr comment "$pr" --body "$body") && echo "posted: $url" || why=failed
      done
    else
      url=$(gh issue create --title "$title" --body "$body") && echo "posted: $url" || why=failed
    fi
    [ -z "$why" ] || echo "gh failed to post — post it yourself:"
  fi
  if [ -n "$why" ]; then
    [ $verdict = PASS ] && echo "post: comment $prs" || echo "post: issue $title"
    printf '%s\n' "$body"
  fi
fi
rm -f "$log"
queue done "$file" || echo "asst-mutation-job: reported, but $file is still marked running — the next sweep queues it again" >&2
exit $rc
