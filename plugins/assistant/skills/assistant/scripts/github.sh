#!/usr/bin/env bash
# run_bounded <seconds> <command…> — runs <command>, killed after <seconds>. No
# `timeout` here: macOS ships without it, and gh ignores the SIGALRM a perl
# `alarm` would send.
run_bounded() {
  local s=$1 pid dog rc
  shift
  "$@" & pid=$!
  # Its output goes to /dev/null so a caller's $(…) does not wait out the sleep.
  ( sleep "$s"; kill "$pid" ) >/dev/null 2>&1 & dog=$!
  wait "$pid"; rc=$?
  kill "$dog" 2>/dev/null
  return "$rc"
}

# gh_run <dir> <gh args…> — gh run in <dir>, killed after $GH_TIMEOUT seconds
# (10 by default) so a dead network cannot hang the caller.
gh_run() {
  local d=$1
  shift
  (cd "$d" && run_bounded "${GH_TIMEOUT:-10}" gh "$@")
}

# gh_unusable <dir> — why no PR can be read or written from <dir>, or nothing
# when gh can. A missing binary must never read as a missing PR: that sends a
# row back to a step that did run.
gh_unusable() {
  if ! command -v gh >/dev/null; then echo "gh not installed"
  elif ! gh_run "$1" auth status >/dev/null 2>&1; then echo "gh not authenticated, or GitHub unreachable"
  elif ! gh_run "$1" repo view --json name >/dev/null 2>&1; then echo "no GitHub remote, or GitHub unreachable"
  fi
}

# gh_visibility <dir> — PUBLIC, PRIVATE or INTERNAL for <dir>'s repo; fails when
# GitHub gives no answer.
gh_visibility() {
  local v
  v=$(gh_run "$1" repo view --json visibility --jq .visibility 2>/dev/null) || return 1
  case "$v" in PUBLIC|PRIVATE|INTERNAL) echo "$v" ;; *) return 1 ;; esac
}

# gh_private <dir> — succeeds only when GitHub reports <dir>'s repo private or
# internal. An unknown answer counts as public: a leak cannot be taken back.
gh_private() {
  case "$(gh_visibility "$1")" in
    PRIVATE|INTERNAL) return 0 ;;
    *) return 1 ;;
  esac
}
