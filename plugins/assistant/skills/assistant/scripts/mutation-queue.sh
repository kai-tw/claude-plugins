#!/usr/bin/env bash
# asst-mutation-queue — the post-merge mutation queue, kept as files on the
# `mutation-queue` branch of origin: pending/<path> is waiting, running/<path>
# is claimed, journal/<path> is what a run of <path> finished so far. Every
# change is a commit pushed without force, so of two writers racing, one is
# rejected as non-fast-forward and retries from the new tip — that rejection is
# the lock. Nothing here touches a working tree: changes go through a private
# index.
#
# Usage: asst-mutation-queue add <pr> <file…>
#          queue the files a merged PR changed; a file already pending gains
#          the PR, so several PRs share one run
#        asst-mutation-queue claim [<journal>]
#          move one pending file to running → prints `<file> <sha> <pr…>`; the
#          run grades <sha>, which the first claim pins to the default branch's
#          tip and every resumed claim keeps. A saved journal is written to
#          <journal>. Exit 3 when nothing can be claimed
#        asst-mutation-queue save <file> <journal>
#          store a running file's journal; it doubles as the heartbeat
#        asst-mutation-queue done <file>
#          drop a running file and its journal
#        asst-mutation-queue sweep [<minutes>]
#          put running files with no heartbeat for <minutes> (default 30) back
#          in pending to resume. A file whose journal didn't grow over 3 claims
#          in a row is dropped and printed as `stuck: <file> <pr…>`
#        asst-mutation-queue status
#          `queue: <n> pending, <m> running`, then one line per file
# A file queued again while it runs gets a fresh pending entry; if that entry is
# still waiting when the run is swept, the two merge and start over on a new tip.
# Exit: 0 done · 1 the push kept losing races · 2 usage · 3 nothing to claim.
set -uo pipefail
q=mutation-queue
stall_limit=3
usage() { sed -n '10,30p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
op="${1:-}"; [ -n "$op" ] || usage; shift
git rev-parse --git-dir >/dev/null 2>&1 || { echo "asst-mutation-queue: not in a git repo" >&2; exit 2; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export GIT_INDEX_FILE="$tmp/index"
export GIT_AUTHOR_NAME=asst-mutation-queue GIT_AUTHOR_EMAIL=asst-mutation-queue@localhost
export GIT_COMMITTER_NAME=asst-mutation-queue GIT_COMMITTER_EMAIL=asst-mutation-queue@localhost
now=$(date +%s)

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
putfile() { git update-index --add --cacheinfo "100644,$(git hash-object -w -- "$2"),$1"; }
del() { git update-index --force-remove "$1"; }
under() { git ls-files -- "$1/" | sed "s#^$1/##"; }
# An entry is `<key> <value>` lines: pr (one per PR), sha, claimed, beat, lines, stalls.
val() { sed -n "s/^$1 //p" | head -1; }
prs() { grep '^pr ' | cut -d' ' -f2 | paste -sd' ' -; }
nlines() { get "journal/$1" | grep -c .; }

# Run <fn> against the latest queue and push the result, retrying on a lost race.
# <fn> returning 3 means nothing to change. Output is collected per attempt and
# printed once the push lands, so a lost attempt prints nothing.
transact() {
  local fn=$1 msg=$2 i tree commit rc
  for i in 1 2 3 4 5 6 7 8; do
    fresh; : > "$tmp/out"; "$fn" > "$tmp/out"; rc=$?
    [ $rc = 0 ] || { cat "$tmp/out"; return $rc; }
    tree=$(git write-tree)
    if [ -n "$base" ] && [ "$tree" = "$(git rev-parse "$base^{tree}")" ]; then cat "$tmp/out"; return 0; fi
    commit=$(git commit-tree "$tree" ${base:+-p "$base"} -m "$msg")
    git push --quiet origin "$commit:refs/heads/$q" 2>/dev/null && { cat "$tmp/out"; return 0; }
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
    out_journal="${1:-}"
    default=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); default=${default#origin/}
    git fetch --quiet origin "${default:=main}" 2>/dev/null
    tip=$(git rev-parse "origin/$default" 2>/dev/null) || { echo "asst-mutation-queue: no origin/$default" >&2; exit 2; }
    claim() {
      local f e sha
      while IFS= read -r f; do
        # One run per file at a time: a file still running stays pending.
        has "running/$f" && continue
        e=$(get "pending/$f"); sha=$(val sha <<< "$e"); sha=${sha:-$tip}
        put "running/$f" "$(printf '%s\nsha %s\nclaimed %s\nbeat %s\nlines %s\nstalls %s' \
          "$(grep '^pr ' <<< "$e")" "$sha" "$now" "$now" "$(nlines "$f")" "$(val stalls <<< "$e" | grep . || echo 0)")"
        del "pending/$f"
        echo "$f $sha $(prs <<< "$e")"; return 0
      done < <(under pending)
      return 3
    }
    job=$(transact claim "claim") || exit $?
    if [ -n "$out_journal" ]; then
      rm -f "$out_journal"
      git show "refs/remotes/origin/$q:journal/${job%% *}" > "$out_journal" 2>/dev/null || rm -f "$out_journal"
    fi
    echo "$job" ;;
  save)
    file="${1:-}"; journal="${2:-}"; [ -n "$file" ] && [ -n "$journal" ] || usage
    save() {
      local e; has "running/$file" || { echo "asst-mutation-queue: $file is no longer running here — it was swept" >&2; return 1; }
      [ -s "$journal" ] && putfile "journal/$file" "$journal"
      e=$(get "running/$file"); put "running/$file" "$(grep -v '^beat ' <<< "$e"; echo "beat $now")"
    }
    transact save "save: $file" ;;
  done)
    file="${1:-}"; [ -n "$file" ] || usage
    finish() { has "running/$file" || return 3; del "running/$file"; has "journal/$file" && del "journal/$file"; return 0; }
    transact finish "done: $file"; rc=$?; [ $rc = 3 ] && rc=0; exit $rc ;;
  sweep)
    minutes="${1:-30}"; [[ $minutes =~ ^[0-9]+$ ]] || usage
    sweep() {
      local f e t stalls n=0
      while IFS= read -r f; do
        e=$(get "running/$f"); t=$(val beat <<< "$e")
        [ "${t:-0}" -lt $(( now - minutes * 60 )) ] || continue
        n=$((n + 1)); del "running/$f"
        stalls=$(val stalls <<< "$e"); stalls=${stalls:-0}
        if [ "$(nlines "$f")" -le "$(val lines <<< "$e" | grep . || echo 0)" ]; then stalls=$((stalls + 1)); else stalls=0; fi
        if [ "$stalls" -ge "$stall_limit" ]; then
          has "journal/$f" && del "journal/$f"
          echo "stuck: $f $(prs <<< "$e")"
        elif has "pending/$f"; then
          # Queued again while it ran: the new PRs need a newer tip, so the
          # pinned commit and its journal no longer apply.
          put "pending/$f" "$( { get "pending/$f"; grep '^pr ' <<< "$e"; } | sort -u)"
          has "journal/$f" && del "journal/$f"
          echo "requeued: $f (merged with a newer queue entry, starting over)"
        else
          put "pending/$f" "$(printf '%s\nsha %s\nstalls %s' "$(grep '^pr ' <<< "$e")" "$(val sha <<< "$e")" "$stalls")"
          echo "requeued: $f (resumes at $(val sha <<< "$e" | cut -c1-7), $(nlines "$f") journal line(s))"
        fi
      done < <(under running)
      [ $n -gt 0 ] || return 3
    }
    transact sweep "sweep"; rc=$?; [ $rc = 3 ] && rc=0; exit $rc ;;
  status)
    fresh
    echo "queue: $(under pending | grep -c .) pending, $(under running | grep -c .) running"
    under pending | while IFS= read -r f; do echo "pending $f · PR $(get "pending/$f" | prs)"; done
    under running | while IFS= read -r f; do
      echo "running $f · PR $(get "running/$f" | prs) · $(nlines "$f") journal line(s) · beat $(( (now - $(get "running/$f" | val beat)) / 60 )) min ago"
    done ;;
  *) usage ;;
esac
