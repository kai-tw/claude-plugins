#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds stop.sh two zh-TW replies and prints what it says to each.
set -euo pipefail
mkdir -p t
cat > check.sh <<'SH'
root=$1
run() { jq -n --arg m "$1" '{session_id:"s",stop_hook_active:false,last_assistant_message:$m}' \
  | TMPDIR="$PWD/t" bash "$root/hooks/stop.sh"; }
echo "used=[$(run '先看目前的修改與出包流程，確認版本號已經更新，再決定要不要合併。' | jq -r .reason)]"
echo "screwup=[$(run '上週發版又出包了，這次先在測試機跑完整套流程再上線。')]"
SH
