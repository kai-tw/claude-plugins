#!/usr/bin/env bash
# asst_root — the project root every asst-* script keys its state on: the nearest
# ancestor holding `.claude/assistant.md` (the project config), searched from cwd (from
# its place in the main checkout when cwd is in a linked worktree); else the main checkout;
# else cwd. Never a linked worktree, even one holding a copy of a committed config: agents
# run in worktrees, and a worktree-local root would split one task's counters and reports
# between them and the assistant.
# Source it, or run it to print the root.
asst_root() {
  local d=$PWD main="" common
  common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && main=$(dirname "$common")
  # A linked worktree's git dir differs from the common one: search from the main checkout.
  [ -z "$main" ] || [ "$(git rev-parse --path-format=absolute --git-dir)" = "$common" ] ||
    { d=$(git rev-parse --show-prefix); d="$main/${d%/}"; d=${d%/}; }
  while [ "$d" != / ]; do [ -f "$d/.claude/assistant.md" ] && { echo "$d"; return; }; d=$(dirname "$d"); done
  [ -n "$main" ] && echo "$main" || pwd
}
# asst_field <config> <name> — the value of `<name>:` in a project config, its comment
# dropped; empty when the line or the file is missing.
asst_field() { sed -nE "s/^$2:[[:space:]]*([^#]*[^#[:space:]]).*/\1/p" "$1" 2>/dev/null | head -1; }
[ "${BASH_SOURCE[0]}" = "$0" ] && asst_root
