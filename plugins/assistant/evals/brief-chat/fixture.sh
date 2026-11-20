#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# `proj` has an assistant project config, `other` doesn't. check.sh writes a
# transcript per case (text of N CJK characters, `R` = a tool result, `U` = a
# user message, then a tool_use line), feeds hooks/checks/brief-chat.sh the hook
# input and prints what it says and its exit code.
set -euo pipefail
mkdir -p proj/.claude other
echo 'rules: none' > proj/.claude/assistant.md
cat > check.sh <<'SH'
root=$1
cjk() { node -e 'process.stdout.write("字".repeat(+process.argv[1]))' "$1"; }
# mk <file> <part>...: a part is a number (text of that many characters), R or U
mk() {
  local f=$1 p; shift; : > "$f"
  for p in "$@"; do
    case $p in
      R) echo '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t","content":"ok"}]}}' >> "$f" ;;
      U) echo '{"type":"user","message":{"content":[{"type":"text","text":"go"}]}}' >> "$f" ;;
      *) jq -nc --arg t "$(cjk "$p")" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}' >> "$f" ;;
    esac
  done
  echo '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t","name":"Bash","input":{"command":"ls"}}]}}' >> "$f"
}
# hook <name> <cwd> <transcript> <extra input object> <count the reminder names>
hook() {
  local out rc
  out=$(jq -nc --arg c "$2" --arg t "$3" --argjson x "$4" '{session_id:"s",cwd:$c,transcript_path:$t,tool_name:"Bash",tool_input:{command:"ls"}} + $x' \
    | bash "$root/hooks/checks/brief-chat.sh" 2>/dev/null); rc=$?
  if [ -z "$out" ]; then echo "$1=silent rc=$rc"
  else echo "$1=$(printf '%s' "$out" | jq -c --arg n "$5" '[.hookSpecificOutput.hookEventName, (.hookSpecificOutput.additionalContext | (contains($n) and contains("120"))), (.hookSpecificOutput.permissionDecision // "none")]' 2>/dev/null || echo unparsable) rc=$rc"; fi
}
p=$PWD/proj; o=$PWD/other; t=$PWD/t.jsonl; e='{}'
mk $t 300;        hook s1-long        $p $t "$e" 300
mk $t 121;        hook b-121          $p $t "$e" 121
mk $t 120;        hook b-120          $p $t "$e" 120
mk $t 40;         hook s2-short       $p $t "$e" 40
mk $t;            hook s2-none        $p $t "$e" 0
mk $t 300 R 40;   hook s4-after-result $p $t "$e" 300
mk $t 300 U 40;   hook s4-after-user  $p $t "$e" 300
mk $t 70 70;      hook s5-sum         $p $t "$e" 140
mk $t 60 60;      hook s5-under       $p $t "$e" 120
mk $t 300;        hook s6-noconfig    $o $t "$e" 300
mk $t 300;        hook s7-subagent    $p $t '{"agent_id":"a1"}' 300
hook s8-missing $p $PWD/nope.jsonl "$e" 300
printf 'not json\n{' > $t; hook s8-garbage $p $t "$e" 300
mk $t 300; chmod 000 $t; hook s8-unreadable $p $t "$e" 300; chmod 644 $t
mkdir -p nojq; for b in bash cat node dirname sed grep tr head tail awk; do ln -sf "$(command -v $b)" nojq/$b; done
out=$(jq -nc --arg c "$p" --arg t "$t" '{cwd:$c,transcript_path:$t,tool_name:"Bash"}' | env PATH="$PWD/nojq" "$(command -v bash)" "$root/hooks/checks/brief-chat.sh" 2>/dev/null); rc=$?
echo "s8-nojq=[$out] rc=$rc"
SH
