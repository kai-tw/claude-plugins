#!/bin/bash
# cloud-ci-runner <owner/repo> [--idle <minutes>]
#
# Runs <owner/repo>'s queued self-hosted Actions jobs in this cloud container,
# then exits. Installed as /usr/local/bin/cloud-ci-runner by
# scripts/cloud-runner-setup.sh, in the runner environment only, where each
# repo's routine runs it. A change here reaches that environment only after
# its snapshot rebuilds.
#
# Each job gets its own just-in-time runner (labels self-hosted, flutter, linux,
# cloud): GitHub hands it one job and removes it afterwards, so nothing stays
# registered when the container goes away. A new one is registered while a
# self-hosted job is still queued; with none for --idle minutes (default 5) it
# exits. A runner stopped before it took a job is deleted.
#
# Registering a runner needs administration write on the repo. It uses the
# session's own GitHub credentials, unless the environment's Environment
# variables set CI_RUNNER_TOKEN_<OWNER> (owner upper-cased, anything not a
# letter or digit as _, e.g. CI_RUNNER_TOKEN_NOVELGLIDE) or CI_RUNNER_TOKEN.
#
# Exit: 0 no work left · 1 a runner failed · 2 usage, no runner
# unpacked, or GitHub refused.
set -uo pipefail
repo="" idle=5
while [ $# -gt 0 ]; do
  case "$1" in
    --idle) idle="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    */*) repo="$1"; shift ;;
    *) echo "cloud-ci-runner: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
[ -n "$repo" ] || { echo "cloud-ci-runner: usage: cloud-ci-runner <owner/repo> [--idle <minutes>]" >&2; exit 2; }
[[ $idle =~ ^[0-9]+$ ]] || { echo "cloud-ci-runner: --idle needs a whole number of minutes" >&2; exit 2; }
poll=${CLOUD_CI_RUNNER_POLL:-30}

var="CI_RUNNER_TOKEN_$(printf '%s' "${repo%%/*}" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9\n' '_')"
token="${!var:-${CI_RUNNER_TOKEN:-}}"
[ -n "$token" ] && export GH_TOKEN="$token"
dir=${CLOUD_CI_RUNNER_HOME:-/opt/actions-runner}
[ -x "$dir/run.sh" ] || { echo "cloud-ci-runner: no runner unpacked at $dir — the environment's setup script installs it; rebuild its snapshot" >&2; exit 2; }
# The runner refuses to start as root unless told it may; a container runs as root.
export RUNNER_ALLOW_RUNASROOT=1

# Queued jobs, in queued or running workflows, that ask for a self-hosted
# runner, plus 1 while this runner is busy. Fails when gh can't answer.
agent=""
pending() {
  local n=0 busy id k status
  if [ -n "$agent" ]; then
    busy=$(gh api "repos/$repo/actions/runners" --jq ".runners[] | select(.name == \"$agent\") | .busy" 2>/dev/null) || return 1
    [ "$busy" = true ] && n=1
  fi
  for status in queued in_progress; do
    for id in $(gh run list -R "$repo" --status "$status" --limit 20 --json databaseId --jq '.[].databaseId' 2>/dev/null); do
      k=$(gh api "repos/$repo/actions/runs/$id/jobs" \
        --jq '[.jobs[] | select(.status == "queued" and (.labels | index("self-hosted")))] | length' 2>/dev/null) || return 1
      n=$((n + k))
    done
  done
  echo "$n"
}
pending >/dev/null || { echo "cloud-ci-runner: gh can't list $repo's workflow runs with these credentials" >&2; exit 2; }

log="$dir/_diag/cloud-ci-runner.log"
mkdir -p "$dir/_diag"
pid="" rid=""
descendants() {
  local c
  for c in $(pgrep -P "$1" 2>/dev/null); do echo "$c"; descendants "$c"; done
}
# The whole tree (run.sh → run-helper.sh → Runner.Listener → Runner.Worker),
# listed before anything is signalled, then killed after a grace period; a
# runner that never took a job is still registered, so it is deleted.
stop_runner() {
  local t=0 tree alive
  [ -n "$pid" ] || return 0
  tree="$pid $(descendants "$pid") $(pgrep -f "$dir/bin/Runner\." 2>/dev/null)"
  # shellcheck disable=SC2086
  kill -TERM $tree 2>/dev/null
  while [ $t -lt 30 ]; do
    # shellcheck disable=SC2086
    alive=$(for p in $tree; do kill -0 "$p" 2>/dev/null && echo "$p"; done)
    [ -n "$alive" ] || break
    sleep 1; t=$((t + 1))
  done
  # shellcheck disable=SC2086
  kill -KILL $tree 2>/dev/null
  wait "$pid" 2>/dev/null
  [ -n "$rid" ] && gh api -X DELETE "repos/$repo/actions/runners/$rid" >/dev/null 2>&1
  pid="" rid=""
}
trap stop_runner EXIT

done_jobs=0 quiet=0
while :; do
  n=$(pending) || n=1   # unknown counts as work: never give up under a queued job
  if [ "$n" -eq 0 ]; then
    if [ "$quiet" -ge $((idle * 60)) ]; then
      echo "cloud-ci-runner: no self-hosted job queued on $repo for ${idle} minute(s) — done after $done_jobs job(s)"
      exit 0
    fi
    sleep "$poll"; quiet=$((quiet + poll)); continue
  fi
  quiet=0
  agent="cloud-$(hostname -s 2>/dev/null || echo host)-$$-$((done_jobs + 1))"
  out=$(gh api -X POST "repos/$repo/actions/runners/generate-jitconfig" \
        -f name="$agent" -F runner_group_id=1 -f work_folder=_work \
        -f 'labels[]=self-hosted' -f 'labels[]=flutter' -f 'labels[]=linux' -f 'labels[]=cloud' 2>&1) || {
    echo "cloud-ci-runner: GitHub refused a runner for $repo — ${out##*$'\n'} (the credentials need administration write on $repo: set CI_RUNNER_TOKEN)" >&2
    exit 2
  }
  rid=$(printf '%s' "$out" | jq -r '.runner.id')
  "$dir/run.sh" --jitconfig "$(printf '%s' "$out" | jq -r '.encoded_jit_config')" >>"$log" 2>&1 &
  pid=$!
  echo "cloud-ci-runner: runner $agent started for $repo (log $log)"
  # Wait for its one job. A runner GitHub never hands a job — another runner
  # took it — is stopped once nothing has been queued for --idle minutes.
  idle_for=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep "$poll"
    m=$(pending) || m=1
    if [ "$m" -gt 0 ]; then idle_for=0; continue; fi
    idle_for=$((idle_for + poll))
    if [ "$idle_for" -ge $((idle * 60)) ]; then
      echo "cloud-ci-runner: runner $agent got no job for ${idle} minute(s) — stopping"
      stop_runner
      exit 0
    fi
  done
  wait "$pid"; rc=$?
  pid="" rid=""
  [ "$rc" -eq 0 ] || { echo "cloud-ci-runner: runner $agent exited with $rc — see $log" >&2; exit 1; }
  done_jobs=$((done_jobs + 1))
  echo "cloud-ci-runner: runner $agent finished its job"
done
