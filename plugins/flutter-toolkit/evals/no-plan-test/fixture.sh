#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# home/ holds the slot directory an older version left behind, with a holder that
# is long dead. fake_test.sh stands in for `flutter test`: it records what it can
# see while it runs, then writes a fully executed lcov. check.sh prints what the
# case grades, among it the root README.md and the plugin's marketplace entry; hooks
# are read from hooks.json, never named, so the case checks any version's files
# rather than finding none.
set -euo pipefail
git init -q
mkdir -p lib home/.claude/.flutter-toolkit/slots/slot-9
printf 'int a() => 1;\n' > lib/a.dart
printf 'pid=999999\n' > home/.claude/.flutter-toolkit/slots/slot-9/meta
cat > fake_test.sh <<'SH'
{
  echo "ran=1"
  echo "slot-env=${PLAN_TEST_SLOT_HELD:-unset}"
  echo "slots-during=$(ls "$HOME/.claude/.flutter-toolkit/slots" | paste -sd, -)"
} > during.txt
mkdir -p coverage
printf 'SF:lib/a.dart\nDA:1,1\nend_of_record\n' > coverage/lcov.info
SH
cat > check.sh <<'SH'
root=$1
pat='plan-test|plan_test|PLAN_TEST|test slots?'
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
HOME="$PWD/home" PLAN_QA_REPORT_DIR="$PWD/report" plan-coverage --files lib/a.dart -- bash fake_test.sh >out.txt 2>&1
echo "rc=$?"
cat during.txt 2>/dev/null || echo "ran=0"
echo "legacy-after=$(ls home/.claude/.flutter-toolkit/slots | paste -sd, -) $(cat home/.claude/.flutter-toolkit/slots/slot-9/meta 2>/dev/null)"
SH
