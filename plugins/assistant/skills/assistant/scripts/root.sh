#!/usr/bin/env bash
# asst_root — the project root every asst-* script keys its state on: the nearest
# ancestor holding `.claude/assistant.md` (the adapter), searched from cwd and then
# from the main checkout; else the main checkout; else cwd. The main checkout, not
# the git toplevel, because agents run in worktrees and a worktree-local root
# would split one task's counters and reports between them and the assistant.
# Source it, or run it to print the root.
asst_root() {
  local d start main=""
  local common
  common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && main=$(dirname "$common")
  for start in "$PWD" ${main:+"$main"}; do
    d=$start
    while [ "$d" != / ]; do [ -f "$d/.claude/assistant.md" ] && { echo "$d"; return; }; d=$(dirname "$d"); done
  done
  [ -n "$main" ] && echo "$main" || pwd
}
[ "${BASH_SOURCE[0]}" = "$0" ] && asst_root
