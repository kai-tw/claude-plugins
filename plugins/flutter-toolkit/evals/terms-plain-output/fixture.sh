#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh prints what the model reads from this plugin: every skill and reference
# file, the plugin description, and the block message of whichever hook hooks.json
# registers for PreToolUse. Paths are globbed and read from hooks.json, never
# named, so the case checks any version's files rather than finding none.
set -euo pipefail
cat > check.sh <<'SH'
root=$1
n=0
for f in "$root"/skills/*/SKILL.md "$root"/skills/*/references/*.md; do
  [ -f "$f" ] || continue
  cat "$f"; n=$((n + 1))
done
echo "skill-files=$n"
jq -r .description "$root/.claude-plugin/plugin.json"
cmd=$(jq -r '.hooks.PreToolUse[].hooks[].command' "$root/hooks/hooks.json")
printf '%s\n' '{"tool_input":{"command":"flutter test"}}' \
  | CLAUDE_PLUGIN_ROOT="$root" eval "$cmd" | jq -r .hookSpecificOutput.permissionDecisionReason
SH
