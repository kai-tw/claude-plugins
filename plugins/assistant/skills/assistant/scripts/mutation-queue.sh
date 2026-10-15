#!/usr/bin/env bash
# asst-mutation-queue — the post-merge mutation queue, kept as files on the
# `mutation-queue` branch of origin: pending/<path> is waiting, running/<path>
# is claimed. Each file lists the PRs that changed <path>, one `pr <n>` per line;
# a running one also says when it was claimed. Every change is a commit pushed
# without force, so of two writers racing, one is rejected as non-fast-forward
# and retries from the new tip — that rejection is the lock. Nothing here
# touches a working tree: changes go through a private index.
#
# Usage: asst-mutation-queue add <pr> <file…>
#          queue the files a merged PR changed; a file already pending gains
#          the PR, so several PRs share one run
#        asst-mutation-queue claim
#          move one pending file to running → prints `<file> <pr…>`;
#          exit 3 when nothing can be claimed
#        asst-mutation-queue done <file>
#          drop a running file
#        asst-mutation-queue sweep [<hours>]
#          put running files claimed over <hours> (default 6) ago back in
#          pending: the session that claimed them is gone
#        asst-mutation-queue status
#          `queue: <n> pending, <m> running`, then one line per file
# Exit: 0 done · 1 the push kept losing races · 2 usage · 3 nothing to claim.
set -uo pipefail
q=mutation-queue
usage() { sed -n '10,23p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
op="${1:-}"; [ -n "$op" ] || usage; shift
git rev-parse --git-dir >/dev/null 2>&1 || { echo "asst-mutation-queue: not in a git repo" >&2; exit 2; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export GIT_INDEX_FILE="$tmp/index"
export GIT_AUTHOR_NAME=asst-mutation-queue GIT_AUTHOR_EMAIL=asst-mutation-queue@localhost
export GIT_COMMITTER_NAME=asst-mutation-queue GIT_COMMITTER_EMAIL=asst-mutation-queue@localhost

base=""
# Load origin's queue into the private index; an empty one when it has none yet.
fresh() {
  if git fetch --quiet origin "+refs/heads/$q:refs/remotes/origin/$q" 2>/dev/null; then
    base=$(git rev-parse "refs/remotes/origin/$q"); git read-tree "$base"
  else
    base=""; git read-tree --empty
  fi
}
get() { git cat-file -p ":$1" 2>/dev/null; }
has() { git cat-file -e ":$1" 2>/dev/null; }
put() { git update-index --add --cacheinfo "100644,$(printf '%s\n' "$2" | git hash-object -w --stdin),$1"; }
del() { git update-index --force-remove "$1"; }
under() { git ls-files -- "$1/" | sed "s#^$1/##"; }
prs() { grep '^pr ' | cut -d' ' -f2 | paste -sd' ' -; }

# Run <fn> against the latest queue and push the result, retrying on a lost race.
# <fn> returning 3 means nothing to change.
transact() {
  local fn=$1 msg=$2 i tree commit rc
  for i in 1 2 3 4 5 6 7 8; do
    fresh; "$fn"; rc=$?
    [ $rc = 0 ] || return $rc
    tree=$(git write-tree)
    [ -n "$base" ] && [ "$tree" = "$(git rev-parse "$base^{tree}")" ] && return 0
    commit=$(git commit-tree "$tree" ${base:+-p "$base"} -m "$msg")
    git push --quiet origin "$commit:refs/heads/$q" 2>/dev/null && return 0
    sleep $(( RANDOM % 3 + i ))
  done
  echo "asst-mutation-queue: $op — lost the push race 8 times, nothing changed" >&2
  return 1
}

case "$op" in
  add)
    pr="${1:-}"; shift 2>/dev/null
    [[ $pr =~ ^[0-9]+$ ]] && [ $# -gt 0 ] || usage
    files=("$@")
    add() {
      local f
      for f in "${files[@]}"; do
        put "pending/$f" "$( { get "pending/$f"; echo "pr $pr"; } | grep . | sort -u)"
      done
    }
    transact add "queue #$pr: ${#files[@]} file(s)" ;;
  claim)
    claimed=""
    claim() {
      local f
      while IFS= read -r f; do
        # One run per file at a time: a file still running stays pending.
        has "running/$f" && continue
        put "running/$f" "$(printf 'claimed %s\n%s' "$(date +%s)" "$(get "pending/$f")")"
        claimed="$f $(get "pending/$f" | prs)"; del "pending/$f"; return 0
      done < <(under pending)
      return 3
    }
    transact claim "claim" || exit $?
    echo "$claimed" ;;
  done)
    file="${1:-}"; [ -n "$file" ] || usage
    finish() { has "running/$file" || return 3; del "running/$file"; }
    transact finish "done: $file"; rc=$?; [ $rc = 3 ] && rc=0; exit $rc ;;
  sweep)
    hours="${1:-6}"; [[ $hours =~ ^[0-9]+$ ]] || usage
    sweep() {
      local f t cut=$(( $(date +%s) - hours * 3600 )) n=0
      while IFS= read -r f; do
        t=$(get "running/$f" | sed -n 's/^claimed //p')
        [ "${t:-0}" -lt "$cut" ] || continue
        put "pending/$f" "$( { get "pending/$f"; get "running/$f" | grep '^pr '; } | grep . | sort -u)"
        del "running/$f"; n=$((n + 1)); echo "requeued: $f"
      done < <(under running)
      [ $n -gt 0 ] || return 3
    }
    transact sweep "sweep"; rc=$?; [ $rc = 3 ] && rc=0; exit $rc ;;
  status)
    fresh
    echo "queue: $(under pending | grep -c .) pending, $(under running | grep -c .) running"
    under pending | while IFS= read -r f; do echo "pending $f · PR $(get "pending/$f" | prs)"; done
    under running | while IFS= read -r f; do echo "running $f · PR $(get "running/$f" | prs)"; done ;;
  *) usage ;;
esac
