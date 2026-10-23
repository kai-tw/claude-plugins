#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh sends remind.sh a Chinese prompt and then a second prompt, and feeds
# stop.sh an English reply in the same session.
set -euo pipefail
mkdir -p t
cat > check.sh <<'SH'
root=$1
prompt() { jq -n --arg s "$1" --arg p "$2" '{session_id:$s,prompt:$p}' \
  | TMPDIR="$PWD/t" bash "$root/hooks/remind.sh" >/dev/null; }
stop() { jq -n --arg s "$1" --arg m "$2" '{session_id:$s,stop_hook_active:false,last_assistant_message:$m}' \
  | TMPDIR="$PWD/t" bash "$root/hooks/stop.sh"; }
en='The reviewer finished: all three findings are fixed and the branch is ready for another look.'
note=$(printf '<task-notification>\n<task-id>a1</task-id>\n<status>completed</status>\n<result>%s</result>\n</task-notification>' "$en")
prompt n '幫我把這個 PR 再檢查一次。'; prompt n "$note"
echo "notification=[$(stop n "$en" | jq -r .decision)]"
prompt u '幫我把這個 PR 再檢查一次。'; prompt u 'Please answer in English from now on, thanks.'
echo "user-en=[$(stop u "$en")]"
SH
