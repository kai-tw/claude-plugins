#!/usr/bin/env bash
# asst-watch — wake the assistant when one of its PRs merges or closes, by push,
# not polling: GitHub's webhook forwarder (`gh webhook forward`, the cli/gh-webhook
# extension) streams each pull_request event over a websocket. Run it with the Bash
# tool's `run_in_background: true`; it exits on the first event that closes a
# listed PR, and the exit wakes the session.
#
# Usage: asst-watch <worktree> [<worktree> …]   (each on a branch with an open PR)
# Output, one line, then exit 0:  merged <owner/repo>#<n>  ·  closed <owner/repo>#<n>
# A PR already merged or closed once the forwarders are connected is reported at
# once, so a merge while nothing watched is not lost. Exit 1: a forwarder could not
# start or stopped (its reason on stderr; `Hook already exists` = another forwarder
# holds that repo) · 2 usage.
set -uo pipefail
usage() { sed -n '8,13p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "asst-watch: $1" >&2; exit 1; }
[ $# -gt 0 ] || usage
command -v jq >/dev/null || die "jq not installed"
gh webhook --help >/dev/null 2>&1 || die "gh webhook not installed — gh extension install cli/gh-webhook"

prs=() repos=()
for wt in "$@"; do
  [ -d "$wt" ] || usage
  branch=$(git -C "$wt" symbolic-ref --quiet --short HEAD) || die "$wt is not on a branch"
  ref=$(cd "$wt" && gh pr view "$branch" --json number,url --jq '(.url | sub("https://[^/]+/"; "") | sub("/pull/[0-9]+$"; "")) + "#" + (.number | tostring)') \
    || die "no PR for $branch in $wt"
  prs+=("$ref"); repos+=("${ref%#*}")
done
repos=($(printf '%s\n' "${repos[@]}" | sort -u))

tmp=$(mktemp -d)
mkfifo "$tmp/events"
exec 3<>"$tmp/events"   # read-write, so the reader never sees EOF between writers
stop() {
  # Stop the extension itself: killing only the `gh` in front of it leaves it running.
  for r in "${repos[@]}"; do pkill -TERM -f "webhook forward --events=pull_request --repo=$r" 2>/dev/null; done
  { wait; } 2>/dev/null   # reap them without bash's `Terminated` notices
  rm -rf "$tmp"
}
trap stop EXIT

# One forwarder per repo; each ends its stream with `stopped <repo>`, so a dead
# forwarder is an event too, never silence.
for r in "${repos[@]}"; do
  log="$tmp/${r//\//_}.log"
  { gh webhook forward --events=pull_request --repo="$r" 2>"$log" \
      | jq --unbuffered -r 'select(.action == "closed")
          | "\(if .pull_request.merged then "merged" else "closed" end) \(.repository.full_name)#\(.number)"'
    echo "stopped $r"
  } >&3 &
done

# Connected first, then the state check: a PR that closes in between sends an event.
for r in "${repos[@]}"; do
  log="$tmp/${r//\//_}.log"
  until grep -q '^Forwarding' "$log" 2>/dev/null; do
    pgrep -f "webhook forward --events=pull_request --repo=$r" >/dev/null \
      || die "forwarder for $r did not start — $(tr '\n' ' ' < "$log")"
    sleep 0.2
  done
done
for ref in "${prs[@]}"; do
  state=$(gh pr view "${ref#*#}" -R "${ref%#*}" --json state --jq .state) || continue
  case $state in
    MERGED) echo "merged $ref"; exit 0 ;;
    CLOSED) echo "closed $ref"; exit 0 ;;
  esac
done

while IFS= read -r line <&3; do
  case $line in
    stopped\ *) r=${line#stopped }; die "forwarder for $r stopped — $(tr '\n' ' ' < "$tmp/${r//\//_}.log")" ;;
  esac
  for ref in "${prs[@]}"; do
    [ "${line#* }" = "$ref" ] && { echo "$line"; exit 0; }
  done
done
