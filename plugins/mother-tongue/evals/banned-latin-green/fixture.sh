#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds stop.sh two zh-TW replies and prints what it says to each.
set -euo pipefail
mkdir -p t
cat > check.sh <<'SH'
root=$1
run() { jq -n --arg m "$1" '{session_id:"s",stop_hook_active:false,last_assistant_message:$m}' \
  | TMPDIR="$PWD/t" bash "$root/hooks/stop.sh"; }
echo "used=[$(run '按鈕圖換好了，eslint 綠，部署前的 gate 綠，可以合併。' | jq -r .reason)]"
echo "colour=[$(run 'CI 亮綠燈了；debug 綠框的大小就是武器實際佔的範圍。')]"
SH
