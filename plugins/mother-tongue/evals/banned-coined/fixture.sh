#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds stop.sh two zh-TW replies and prints what it says to each.
set -euo pipefail
mkdir -p t
cat > check.sh <<'SH'
root=$1
run() { jq -n --arg m "$1" '{session_id:"s",stop_hook_active:false,last_assistant_message:$m}' \
  | TMPDIR="$PWD/t" bash "$root/hooks/stop.sh"; }
echo "used=[$(run '已經開工，builder 跑中。做法是去專案源碼找真實用法，抽出建法；按鈕的兩態也一樣，最後再出碼並註明出處。' | jq -r .reason)]"
echo "kept=[$(run '重整後我補跑中獎版的完整驗證。')]"
SH
