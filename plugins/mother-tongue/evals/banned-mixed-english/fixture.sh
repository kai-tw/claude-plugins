#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds stop.sh two zh-TW replies and prints what it says to each.
set -euo pipefail
mkdir -p t
cat > check.sh <<'SH'
root=$1
run() { jq -n --arg m "$1" '{session_id:"s",stop_hook_active:false,last_assistant_message:$m}' \
  | TMPDIR="$PWD/t" bash "$root/hooks/stop.sh"; }
echo "mixed=[$(run '確認一下：board 上只有一個 live 任務時，就不另開 builder 嗎？' | jq -r .reason)]"
echo "quoted=[$(run '用 `asst-board list` 看任務板；那場 live stream 的錄影已經上傳完了。')]"
SH
