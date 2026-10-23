#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds stop.sh two zh-TW replies and prints what it says to each.
set -euo pipefail
mkdir -p t
cat > check.sh <<'SH'
root=$1
run() { jq -n --arg m "$1" '{session_id:"s",stop_hook_active:false,last_assistant_message:$m}' \
  | TMPDIR="$PWD/t" bash "$root/hooks/stop.sh"; }
echo "used=[$(run '這個 nonce 是為了擋重播攻擊，防重播紀錄存在本機。' | jq -r .reason)]"
echo "rerun=[$(run '這集週末晚上會重播，錯過的話可以再看一次。')]"
SH
