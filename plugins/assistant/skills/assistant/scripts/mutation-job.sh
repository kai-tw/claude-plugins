#!/usr/bin/env bash
# asst-mutation-job — mutation-test ONE file as it was merged, and report it.
# Mutation is too slow to gate a PR, so it runs after the merge instead: a
# workflow fires one cloud session per changed file, and each session runs only
# this command (references/mutation-queue.md).
#
# Usage: asst-mutation-job <pr-number> <merge-sha> <file>
#   Checks out <merge-sha>, runs the adapter's `mutation:` (a plan-mutation
#   command) on <file> alone, then reports: a pass as a comment on PR <n>, a
#   score under the threshold or a run that scored nothing as a new issue.
#   With a usable gh it posts itself and prints `posted: <url>`; without one it
#   prints `post: comment <n>` or `post: issue <title>`, then the body to post.
# First line of output: `asst-mutation-job: PASS|FAIL|ERROR <file> @ <sha7> (PR #<n>)`.
# Exit: 0 passed · 1 scored under the threshold · 2 nothing scored, or usage.
set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/root.sh"; source "$here/github.sh"
pr="${1:-}"; sha="${2:-}"; file="${3:-}"
[[ $pr =~ ^[0-9]+$ && $sha =~ ^[0-9a-f]{7,40}$ && -n $file ]] || { sed -n '7,15p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
root=$(asst_root); cd "$root" || exit 2
field() { sed -nE "s/^$1:[[:space:]]*([^#]*[^#[:space:]]).*/\1/p" .claude/assistant.md 2>/dev/null | head -1; }
head="$file @ ${sha:0:7} (PR #$pr)"
log=$(mktemp)

run() {
  local cmd; cmd=$(field mutation)
  case "$cmd" in
    plan-mutation|plan-mutation\ *) ;;
    *) echo "the adapter's mutation: must be a plan-mutation command, not: ${cmd:-(unset)}"; return 2 ;;
  esac
  [ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "uncommitted changes in $root"; return 2; }
  git cat-file -e "$sha^{commit}" 2>/dev/null || git fetch --quiet origin "$sha" || { echo "cannot fetch $sha"; return 2; }
  git checkout --quiet --detach "$sha" || { echo "cannot check out $sha"; return 2; }
  # --files reads paths up to `--`, so it goes right before the test command.
  # shellcheck disable=SC2086 # the adapter's command is a command line on purpose
  case "$cmd" in
    *" -- "*) ${cmd%% -- *} --files "$file" -- ${cmd#* -- } ;;
    *)        $cmd --files "$file" ;;
  esac
}
run >"$log" 2>&1; rc=$?
if [ $rc = 0 ]; then verdict=PASS
elif [ $rc = 1 ] && grep -q '^plan-mutation: BLOCKED\.' "$log"; then verdict=FAIL
else verdict=ERROR; rc=2
fi

body=$(printf 'asst-mutation-job: %s %s\n\n```\n%s\n```\n' "$verdict" "$head" "$(cat "$log")")
rm -f "$log"
title="mutation $verdict: $file (PR #$pr)"
echo "asst-mutation-job: $verdict $head"
why=$(gh_unusable "$root")
if [ -z "$why" ]; then
  if [ $verdict = PASS ]; then url=$(gh pr comment "$pr" --body "$body")
  else url=$(gh issue create --title "$title" --body "$body"); fi \
    && echo "posted: $url" || { echo "gh failed to post — post it yourself:"; why=failed; }
fi
if [ -n "$why" ]; then
  [ $verdict = PASS ] && echo "post: comment $pr" || echo "post: issue $title"
  printf '%s\n' "$body"
fi
exit $rc
