#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh prints what the case grades, among it the root README.md and the plugin's
# marketplace entry; hooks are read from hooks.json, never named, so the case checks
# any version's files rather than finding none.
set -euo pipefail
cat > check.sh <<'SH'
root=$1
pat='plan-test|plan_test|PLAN_TEST'
repo=$(cd "$root/../.." && pwd)
left=$( { grep -rIliE "$pat" "$root" --exclude-dir=evals
          find "$root" -iname '*plan*test*' -not -path '*/evals/*'
          grep -qiE "$pat" "$repo/README.md" && echo "$repo/README.md"
          jq -c '.plugins[] | select(.name == "flutter-toolkit")' "$repo/.claude-plugin/marketplace.json" \
            | grep -qiE "$pat" && echo "$repo/.claude-plugin/marketplace.json"; } | sort -u)
echo "repo-files=$(ls "$repo/README.md" "$repo/.claude-plugin/marketplace.json" 2>/dev/null | wc -l | tr -d ' ')"
printf '%s\n' "$left" | grep -v '^$' | sed 's/^/left: /'
echo "left-count=$(printf '%s\n' "$left" | grep -vc '^$')"
if [ -e "$root/bin/plan-test" ]; then echo "plan-test=present"; else echo "plan-test=gone"; fi
cmds=$(jq -r '.hooks.PreToolUse[]?.hooks[]?.command' "$root/hooks/hooks.json")
out=$(printf '%s\n' '{"tool_input":{"command":"cd x && flutter test -j 2 test/a/"}}' \
  | CLAUDE_PLUGIN_ROOT="$root" eval "$cmds" 2>&1)
case "$out" in *deny*) echo "bare-flutter-test=blocked" ;; *) echo "bare-flutter-test=allowed" ;; esac
SH
