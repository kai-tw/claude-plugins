#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds remind.sh a Chinese prompt, an English one, and a Chinese one
# with MOTHER_TONGUE_CODE empty, and counts which rule sets each one attaches.
set -euo pipefail
cat > check.sh <<'SH'
root=$1
export TMPDIR=$PWD
run() {
  out=$(jq -n --arg p "$2" '{session_id:"eval",prompt:$p}' | bash "$root/hooks/remind.sh" | jq -r '.hookSpecificOutput.additionalContext // empty')
  echo "$1 zh=$(grep -c '^## 中文的寫法' <<<"$out") en=$(grep -c '^## Writing English' <<<"$out")"
}
run zh-prompt '把 worktree 的 cache 清掉，然後重新跑一次測試'
run en-prompt 'Please clear the worktree cache and run the tests again'
MOTHER_TONGUE_CODE= run zh-nocode '把 worktree 的 cache 清掉，然後重新跑一次測試'
SH
