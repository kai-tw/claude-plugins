#!/usr/bin/env bash
# asst-mutation-job — mutation-test one file as a PR merged it, and report it.
# Mutation is too slow to gate a PR, so it runs after the merge: a workflow on
# a self-hosted runner runs this once per changed file
# (references/mutation-after-merge.md).
#
# Usage: asst-mutation-job <pr> <merge-sha> <file>   (from the project's clone)
#   Runs the adapter's `mutation:` (a plan-mutation command) on <file> alone,
#   at <merge-sha>, in a worktree at a fixed path per commit and file under
#   $ASST_MUTATION_SRC (default /tmp/asst-mutation), after the adapter's
#   `worktree_init:` when set — the worktree is a clean checkout, so nothing
#   git ignores is there until that command makes it.
#   The run's journal (each finished mutant, and the coverage pass test file by
#   test file) is kept under $ASST_MUTATION_STATE (default
#   ~/.cache/asst-mutation), per repo, commit and file, until the file is
#   scored. Run the same command again after an interruption, or after an
#   ERROR, and it resumes from there. The engine keys that journal on each file's absolute path and
#   the package's content, hence the fixed path, and whatever worktree_init
#   generates under lib/ must come out the same every time.
#   A pass is a comment on the PR; a score under the threshold is an issue, and
#   so is a run that scored nothing. With a usable gh it posts itself and
#   prints `posted: <url>`; without one it prints `post: comment <pr>` or
#   `post: issue <title>`, then the body.
#   A file the commit doesn't have is skipped without a report.
# First line: `asst-mutation-job: PASS|FAIL|ERROR|GONE <file> @ <sha7> (PR #<n>)`.
# Exit: 0 reported, whatever the verdict — so a failed job means one that was
# cut off before reporting, which is worth running again · 2 usage, or the
# commit can't be checked out.
set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/root.sh"; source "$here/github.sh"
pr="${1:-}"; sha="${2:-}"; file="${3:-}"
[[ $pr =~ ^[0-9]+$ && $sha =~ ^[0-9a-f]{7,40}$ && -n $file ]] || { sed -n '7,28p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
root=$(asst_root); cd "$root" || exit 2
field() { sed -nE "s/^$1:[[:space:]]*([^#]*[^#[:space:]]).*/\1/p" .claude/assistant.md 2>/dev/null | head -1; }
git cat-file -e "$sha^{commit}" 2>/dev/null || git fetch --quiet origin "$sha" 2>/dev/null
sha=$(git rev-parse --verify --quiet "$sha^{commit}") || { echo "asst-mutation-job: no commit $2 here or on origin" >&2; exit 2; }

repo=$(basename "$root")
key=$(printf '%s' "$file" | tr '/' '_')
src="${ASST_MUTATION_SRC:-/tmp/asst-mutation}/$repo/${sha:0:12}/$key"
keep="${ASST_MUTATION_STATE:-$HOME/.cache/asst-mutation}/$repo/$sha/$key"
mkdir -p "$keep" || exit 2
log="$keep/run.log"

run() {
  local cmd init; cmd=$(field mutation)
  case "$cmd" in
    plan-mutation|plan-mutation\ *) ;;
    *) echo "the adapter's mutation: must be a plan-mutation command, not: ${cmd:-(unset)}"; return 2 ;;
  esac
  # The worktree is a clean checkout: whatever the build generates and git
  # ignores (generated code, assets, .dart_tool) is made here, in the shell.
  init=$(field worktree_init)
  if [ -n "$init" ] && [ "$init" != none ]; then
    bash -c "$init" || { echo "worktree_init failed (exit $?): $init — nothing was mutated; fix the command, not the tests"; return 2; }
  fi
  # --files reads paths up to `--`, so the added flags go right before the test command.
  # shellcheck disable=SC2086 # the adapter's command is a command line on purpose
  case "$cmd" in
    *" -- "*) ${cmd%% -- *} --keep-dir "$keep" --files "$file" -- ${cmd#* -- } ;;
    *)        $cmd --keep-dir "$keep" --files "$file" ;;
  esac
}

verdict=""
git worktree remove --force "$src" >/dev/null 2>&1; rm -rf "$src"; git worktree prune
mkdir -p "$(dirname "$src")"
if ! git worktree add --quiet --detach "$src" "$sha" 2>"$log"; then
  echo "cannot check out $sha at $src" >>"$log"; rc=2
elif [ ! -f "$src/$file" ]; then verdict=GONE; rc=0
else (cd "$src" && run) >"$log" 2>&1; rc=$?
fi
if [ -z "$verdict" ]; then
  if [ $rc = 0 ]; then verdict=PASS
  elif [ $rc = 1 ] && grep -q '^plan-mutation: BLOCKED\.' "$log"; then verdict=FAIL
  else verdict=ERROR
  fi
fi
git worktree remove --force "$src" >/dev/null 2>&1

head="$file @ ${sha:0:7} (PR #$pr)"
echo "asst-mutation-job: $verdict $head"
if [ "$verdict" != GONE ]; then
  body=$(printf 'asst-mutation-job: %s %s\n\n```\n%s\n```\n' "$verdict" "$head" "$(cat "$log")")
  title="mutation $verdict: $file (PR #$pr)"
  why=$(gh_unusable "$root")
  if [ -z "$why" ]; then
    if [ "$verdict" = PASS ]; then url=$(gh pr comment "$pr" --body "$body")
    else url=$(gh issue create --title "$title" --body "$body"); fi \
      && echo "posted: $url" || { echo "gh failed to post — post it yourself:"; why=failed; }
  fi
  if [ -n "$why" ]; then
    [ "$verdict" = PASS ] && echo "post: comment $pr" || echo "post: issue $title"
    printf '%s\n' "$body"
  fi
fi
# A scored file needs its journal no more; an unscored one keeps it, so the
# same command run again resumes.
[ "$verdict" = ERROR ] || rm -rf "$keep"
exit 0
