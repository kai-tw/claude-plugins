#!/usr/bin/env bash
# asst_root — the project root every asst-* script keys its state on: the nearest
# ancestor holding `.claude/assistant.md` (the adapter), else the git toplevel,
# else cwd. Source it, or run it to print the root.
asst_root() {
  local d=$PWD
  while [ "$d" != / ]; do [ -f "$d/.claude/assistant.md" ] && { echo "$d"; return; }; d=$(dirname "$d"); done
  git rev-parse --show-toplevel 2>/dev/null || pwd
}
[ "${BASH_SOURCE[0]}" = "$0" ] && asst_root
