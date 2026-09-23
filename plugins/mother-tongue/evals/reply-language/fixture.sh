#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh sets a session's conversation locale the way remind.sh stores it,
# then feeds stop.sh replies and prints what it says to each.
set -euo pipefail
mkdir -p t
printf 'zh-TW' > t/mother-tongue-zh
printf 'en' > t/mother-tongue-en
cat > check.sh <<'SH'
root=$1
run() { jq -n --arg s "$1" --arg m "$2" '{session_id:$s,stop_hook_active:false,last_assistant_message:$m}' \
  | TMPDIR="$PWD/t" bash "$root/hooks/stop.sh"; }
en='The verifier posted its report: last round of fixes all landed, but it flagged one new decision.'
out=$(run zh "$en")
echo "shape=$(printf '%s' "$out" | jq -c '[.decision, has("hookSpecificOutput")]')"
printf '%s' "$out" | jq -r .reason
echo "fenced=[$(run zh "$(printf '英文版的說明如下，直接貼進 PR 即可。\n```\n%s\n```' "$en")")]"
echo "en-session=[$(run en "$en")]"
echo "no-session=[$(run none "$en")]"
echo "zh-reply=[$(run en '驗證結果已經貼上去，上一輪的修正都生效了。')]"
SH
