#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds the Write/Edit hook the plugin registers a set of edits and
# prints, for each, the block reason or "allowed".
set -euo pipefail
cat > check.sh <<'SH'
root=$1
cmd=$(jq -r '.hooks.PreToolUse[] | select(.matcher | test("Edit")) | .hooks[0].command' "$root/hooks/hooks.json" 2>/dev/null \
  | sed "s|\"\${CLAUDE_PLUGIN_ROOT}\"|$root|")
t() {
  local out
  out=$(jq -n --arg tool "$2" --arg p "$3" --arg n "$4" --arg o "${5:-}" \
    '{tool_name:$tool,tool_input:{file_path:$p,content:$n,new_string:$n,old_string:$o}}' \
    | { [ -n "$cmd" ] && bash $cmd || cat >/dev/null; } | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)
  echo "$1=[${out:-allowed}]"
}
t dart-comment Edit /x/a.dart $'final gate = 1; // the push-gate waits for CI'
t dart-code    Edit /x/a.dart $'final gate = 1; // waits for CI'
t dart-zh      Edit /x/a.dart $'// 這個 gate 會先擋下\nfinal board = 1;'
t dart-block   Edit /x/a.dart $'/**\n * The push-gate waits.\n */'
t dart-string  Edit /x/a.dart $'final url = "http://x/push-gate";'
t kept-old     Edit /x/a.dart $'// the push-gate waits, now longer' $'// the push-gate waits'
t sh-comment   Edit /x/a.sh   $'echo "push-gate" # CI graded green'
t md-prose     Write /x/a.md  $'The push-gate blocks it.'
t md-quoted    Write /x/a.md  $'Use the `push-gate` name. Watergate was a scandal.'
t json         Edit /x/a.json $'{"push-gate": 1}'
SH
