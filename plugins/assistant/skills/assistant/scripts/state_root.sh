# Sourced. Sets $state to the task-state directory shared by every worktree of the
# project: the MAIN checkout's .claude/.assistant — a worktree-local path would
# split one task's counters and reports between the assistant and its agents.
if common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
  state="$(dirname "$common")/.claude/.assistant"
else
  state="$PWD/.claude/.assistant"
fi
