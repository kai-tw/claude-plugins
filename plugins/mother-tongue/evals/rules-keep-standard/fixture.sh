#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds remind.sh a Chinese prompt and prints the keep-in-English list.
set -euo pipefail
cat > check.sh <<'SH'
root=$1
export TMPDIR=$PWD
jq -n '{session_id:"eval",prompt:"把 worktree 的 cache 清掉，然後重新跑一次測試"}' | bash "$root/hooks/remind.sh" \
  | jq -r '.hookSpecificOutput.additionalContext // empty' | grep -A1 '`worktree`、`stack trace`' | tr -d '\n' | sed 's/^/keep=/'
SH
