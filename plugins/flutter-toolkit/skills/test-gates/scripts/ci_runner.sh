#!/usr/bin/env bash
# plan-ci-runner — run this repo's self-hosted Actions runner only while it
# has work, instead of as a login service that is always on.
#
# Usage: plan-ci-runner [--idle <minutes>]   (from inside the repo's clone)
#   Finds the runner registered for this repo's origin under
#   $PLAN_CI_RUNNERS (default ~/actions-runners: one directory per runner,
#   as `config.sh` leaves it), starts it, and stops it once the repo has had
#   no queued or running workflow for --idle minutes (default 5). Start it
#   with the Bash tool's `run_in_background: true` after pushing to a PR; the
#   session is woken when it exits. A runner already running for this repo
#   is left alone.
# Exit: 0 the runner ran and stopped, or was already running · 1 the runner
# failed · 2 usage, no runner registered for this repo, or gh can't see it.
set -uo pipefail
idle=5
while [ $# -gt 0 ]; do
  case "$1" in
    --idle) idle="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "plan-ci-runner: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
[[ $idle =~ ^[0-9]+$ ]] || { echo "plan-ci-runner: --idle needs a whole number of minutes" >&2; exit 2; }
poll=${PLAN_CI_RUNNER_POLL:-30}

url=$(git remote get-url origin 2>/dev/null) || { echo "plan-ci-runner: not in a clone with an origin" >&2; exit 2; }
repo=$(printf '%s' "$url" | sed -E 's#^(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')
base="${PLAN_CI_RUNNERS:-$HOME/actions-runners}"
dir=""
for f in "$base"/*/.runner; do
  [ -f "$f" ] || continue
  [ "$(jq -r .gitHubUrl "$f" 2>/dev/null)" = "https://github.com/$repo" ] && { dir=$(dirname "$f"); break; }
done
[ -n "$dir" ] || { echo "plan-ci-runner: no runner under $base is registered for $repo — register one first (flutter-toolkit references/pr-checks.md)" >&2; exit 2; }
# run.sh starts its listener by the physical path (`cd -P`), so match on that.
dir=$(cd -P "$dir" && pwd)

if pgrep -f "$dir/bin/Runner.Listener" >/dev/null 2>&1; then
  echo "plan-ci-runner: the runner in $dir is already running — leaving it be"
  exit 0
fi

# Queued plus in-progress runs; empty when gh can't answer.
pending() {
  local q r
  q=$(gh run list -R "$repo" --status queued --limit 20 --json databaseId --jq length 2>/dev/null) || return 1
  r=$(gh run list -R "$repo" --status in_progress --limit 20 --json databaseId --jq length 2>/dev/null) || return 1
  echo $((q + r))
}
pending >/dev/null || { echo "plan-ci-runner: gh can't list $repo's workflow runs" >&2; exit 2; }

log="$dir/_diag/plan-ci-runner.log"
mkdir -p "$dir/_diag"
"$dir/run.sh" >"$log" 2>&1 &
pid=$!
# TERM, not INT: a job started with `&` in a script ignores SIGINT, so the
# runner would never hear it. The runner finishes cleanly on TERM; one that is
# still up after the grace period is killed.
stop_runner() {
  local t=0
  pkill -TERM -P "$pid" 2>/dev/null; kill -TERM "$pid" 2>/dev/null
  while kill -0 "$pid" 2>/dev/null && [ $t -lt "${PLAN_CI_RUNNER_GRACE:-30}" ]; do sleep 1; t=$((t + 1)); done
  pkill -KILL -P "$pid" 2>/dev/null; kill -KILL "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
}
trap stop_runner EXIT
echo "plan-ci-runner: runner for $repo started ($dir, log $log); stops after ${idle} idle minute(s)"

quiet=0
while kill -0 "$pid" 2>/dev/null; do
  sleep "$poll"
  n=$(pending) || n=1   # unknown counts as busy: never stop under a job
  if [ "$n" -gt 0 ]; then quiet=0; else quiet=$((quiet + poll)); fi
  if [ "$quiet" -ge $((idle * 60)) ]; then
    echo "plan-ci-runner: no queued or running workflow for ${idle} minute(s) — stopping"
    exit 0
  fi
done
wait "$pid"; rc=$?
trap - EXIT
echo "plan-ci-runner: the runner exited on its own (exit $rc) — see $log" >&2
exit 1
