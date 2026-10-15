#!/usr/bin/env bash
# asst-mutation-job — take one file from the mutation queue, mutation-test it,
# and report it. Mutation is too slow to gate a PR, so merged files wait in the
# queue (asst-mutation-queue) and routine sessions work through it
# (references/mutation-queue.md).
#
# Usage: asst-mutation-job      (from anywhere in the project's clone)
#   First sweeps the queue, opening an issue for each file it gives up on. Then
#   claims a file and runs the adapter's `mutation:` (a plan-mutation command)
#   on it alone, at the commit the queue pinned, in a worktree at a fixed path:
#   $ASST_MUTATION_SRC (default /tmp/asst-mutation)/<repo>, after the adapter's
#   `worktree_init:` when set — the worktree is a clean checkout, so nothing
#   git ignores is there until that command makes it. Whatever it generates
#   under lib/ must come out the same on every run of one commit, or a resumed
#   run starts over. The run's journal
#   is saved to the queue every $ASST_MUTATION_BEAT seconds (default 300) and
#   restored on the next claim, so a session that dies part-way is resumed by
#   the next one instead of starting over — the engine keys finished mutants on
#   their absolute path and the package's content, hence the fixed path and the
#   pinned commit.
#   A pass is a comment on each PR queued for the file; a score under the
#   threshold, or a run that scored nothing, is one issue naming them all. With
#   a usable gh it posts itself and prints `posted: <url>`; without one it
#   prints `post: comment <pr…>` or `post: issue <title>`, then the body.
#   A file the pinned commit doesn't have is dropped without a report.
# First line per job: `asst-mutation-job: PASS|FAIL|ERROR|GONE|STUCK <file> @ <sha7> (PR #<n>, …)`;
# `asst-mutation-job: queue empty` when there was nothing to claim.
# Exit: 0 passed or gone · 1 scored under the threshold · 2 nothing scored ·
# 3 the queue had nothing to claim.
set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/root.sh"; source "$here/github.sh"
queue() { bash "$here/mutation-queue.sh" "$@"; }
root=$(asst_root); cd "$root" || exit 2
field() { sed -nE "s/^$1:[[:space:]]*([^#]*[^#[:space:]]).*/\1/p" .claude/assistant.md 2>/dev/null | head -1; }
refs_of() { local r; r=$(printf 'PR #%s, ' $1); echo "${r%, }"; }

# report <verdict> <file> <sha> <prs> <log-file>
report() {
  local verdict=$1 file=$2 sha=$3 prs=$4 log=$5 head body title why="" url pr
  head="$file @ ${sha:0:7} ($(refs_of "$prs"))"
  echo "asst-mutation-job: $verdict $head"
  [ "$verdict" = GONE ] && return
  body=$(printf 'asst-mutation-job: %s %s\n\n```\n%s\n```\n' "$verdict" "$head" "$(cat "$log")")
  title="mutation $verdict: $file ($(refs_of "$prs"))"
  why=$(gh_unusable "$root")
  if [ -z "$why" ]; then
    if [ "$verdict" = PASS ]; then
      for pr in $prs; do url=$(gh pr comment "$pr" --body "$body") && echo "posted: $url" || why=failed; done
    else
      url=$(gh issue create --title "$title" --body "$body") && echo "posted: $url" || why=failed
    fi
    [ -z "$why" ] || echo "gh failed to post — post it yourself:"
  fi
  if [ -n "$why" ]; then
    [ "$verdict" = PASS ] && echo "post: comment $prs" || echo "post: issue $title"
    printf '%s\n' "$body"
  fi
}

state=$(mktemp -d); trap 'rm -rf "$state"' EXIT
journal="$state/plan-mutation-dart.jsonl"

queue sweep | while IFS= read -r line; do
  case "$line" in
    "stuck: "*)
      set -- ${line#stuck: }; f=$1; shift
      echo "Three sessions in a row ended before this file's journal grew: no claim finished a single mutant. Split the file, or run it somewhere a session lives longer." > "$state/stuck.log"
      report STUCK "$f" "" "$*" "$state/stuck.log" ;;
    *) echo "asst-mutation-queue: $line" ;;
  esac
done

job=$(queue claim "$journal"); rc=$?
[ $rc = 3 ] && { echo "asst-mutation-job: queue empty"; exit 3; }
[ $rc = 0 ] || exit 2
read -r file sha prs <<< "$job"

src="${ASST_MUTATION_SRC:-/tmp/asst-mutation}/$(basename "$root")"
log="$state/run.log"
run() {
  local cmd; cmd=$(field mutation)
  case "$cmd" in
    plan-mutation|plan-mutation\ *) ;;
    *) echo "the adapter's mutation: must be a plan-mutation command, not: ${cmd:-(unset)}"; return 2 ;;
  esac
  # The worktree is a clean checkout: whatever the build generates and git
  # ignores (generated code, assets, .dart_tool) is made here, in the shell.
  local init; init=$(field worktree_init)
  if [ -n "$init" ] && [ "$init" != none ]; then
    bash -c "$init" || { echo "worktree_init failed (exit $?): $init — nothing was mutated; fix the command, not the tests"; return 2; }
  fi
  # --files reads paths up to `--`, so the added flags go right before the test command.
  # shellcheck disable=SC2086 # the adapter's command is a command line on purpose
  case "$cmd" in
    *" -- "*) ${cmd%% -- *} --keep-dir "$state" --files "$file" -- ${cmd#* -- } ;;
    *)        $cmd --keep-dir "$state" --files "$file" ;;
  esac
}
verdict=""
git worktree remove --force "$src" >/dev/null 2>&1; rm -rf "$src"; git worktree prune
if ! { git cat-file -e "$sha^{commit}" 2>/dev/null || git fetch --quiet origin "$sha"; } \
   || ! git worktree add --quiet --detach "$src" "$sha" 2>"$log"; then
  echo "cannot check out $sha at $src" >>"$log"; rc=2
elif [ ! -f "$src/$file" ]; then verdict=GONE; rc=0
else
  (cd "$src" && run) >"$log" 2>&1 &
  pid=$!; beat=${ASST_MUTATION_BEAT:-300}; t=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1; t=$((t + 1))
    [ $t -ge "$beat" ] && { t=0; queue save "$file" "$journal" >/dev/null || true; }
  done
  wait "$pid"; rc=$?
fi
if [ -z "$verdict" ]; then
  if [ $rc = 0 ]; then verdict=PASS
  elif [ $rc = 1 ] && grep -q '^plan-mutation: BLOCKED\.' "$log"; then verdict=FAIL
  else verdict=ERROR; rc=2
  fi
fi
report "$verdict" "$file" "$sha" "$prs" "$log"
git worktree remove --force "$src" >/dev/null 2>&1
queue done "$file" || echo "asst-mutation-job: reported, but $file is still marked running — the next sweep queues it again" >&2
exit $rc
