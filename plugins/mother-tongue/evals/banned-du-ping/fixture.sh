#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds stop.sh three zh-TW replies and prints what it says to each.
set -euo pipefail
mkdir -p t
cat > check.sh <<'SH'
root=$1
run() { jq -n --arg m "$1" '{session_id:"s",stop_hook_active:false,last_assistant_message:$m}' \
  | TMPDIR="$PWD/t" bash "$root/hooks/stop.sh"; }
echo "used=[$(run '這個按鈕要補上讀屏說明，不然視障使用者聽不到它的用途。' | jq -r .reason)]"
echo "place=[$(run '週末去閱讀屏東的地方誌，順便整理這份文件的段落與標題。')]"
echo "quoted=[$(run '`讀屏` 是中國用語，台灣說螢幕閱讀器，這份文件要全部改掉。')]"
SH
