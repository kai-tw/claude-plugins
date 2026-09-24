#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds stop.sh three zh-TW replies and prints what it says to each.
set -euo pipefail
mkdir -p t
cat > check.sh <<'SH'
root=$1
run() { jq -n --arg m "$1" '{session_id:"s",stop_hook_active:false,last_assistant_message:$m}' \
  | TMPDIR="$PWD/t" bash "$root/hooks/stop.sh"; }
echo "used=[$(run '這個設定會影響所有專案，需要先跟你（使用者）確認再動手修改。' | jq -r .reason)]"
echo "label=[$(run '決策紀錄：**（使用者）** 架構方向改為先做本地資料庫，雲端同步延後處理。')]"
echo "formal=[$(run '本案經核實後撥付補助款，申請人會在十個工作天內收到通知信。')]"
SH
