#!/usr/bin/env bash
# gh_unusable <dir> — why no PR can be read or written from <dir>, or nothing
# when gh can. Sourced by asst-pr and asst-report. A missing binary must never
# read as a missing PR: that sends a row back to a step that did run.
gh_unusable() {
  if ! command -v gh >/dev/null; then echo "gh not installed"
  elif ! (cd "$1" && gh auth status >/dev/null 2>&1); then echo "gh not authenticated"
  elif ! (cd "$1" && gh repo view --json name >/dev/null 2>&1); then echo "no GitHub remote"
  fi
}
