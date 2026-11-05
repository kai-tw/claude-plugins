#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh puts a fake `uname` first on PATH (Darwin or Linux) so the macOS gate is
# testable on any host, then feeds intercept.sh commands and prints whether each rule fired.
set -euo pipefail
cat > check.sh <<'SH'
root=$1; mkdir -p flags fakebin/Darwin fakebin/Linux
for os in Darwin Linux; do printf '#!/bin/sh\necho %s\n' "$os" > "fakebin/$os/uname"; chmod +x "fakebin/$os/uname"; done
# fire OS SID CMD [ROOT]: the rule ids intercept warns about, "-" when quiet
fire() {
  local ids
  ids=$(jq -n --arg c "$3" --arg s "$2" '{session_id:$s,tool_input:{command:$c}}' \
    | env -u CLAUDE_PLUGIN_ROOT ${4:+CLAUDE_PLUGIN_ROOT="$4"} PATH="$PWD/fakebin/$1:$PATH" TMPDIR=$PWD/flags bash "$root/hooks/checks/intercept.sh" 2>/dev/null \
    | jq -r '.hookSpecificOutput.additionalContext // empty' | grep -oE '⚠️  [a-z-]+' | cut -d' ' -f3 | sort -u | tr "\n" " ")
  ids=${ids% }; echo "${ids:--}"
}
sed_cmd="sed 's/\\bx\\b/y/' lib/a.dart"
echo "mac-sed=$(fire Darwin m1 "$sed_cmd")"
echo "mac-sed-again=$(fire Darwin m1 "$sed_cmd")"
jq -n '{session_id:"m1"}' | env -u CLAUDE_PLUGIN_ROOT TMPDIR=$PWD/flags bash "$root/hooks/checks/intercept.sh" --reset
echo "mac-sed-reset=$(fire Darwin m1 "$sed_cmd")"
echo "linux-sed=$(fire Linux l1 "$sed_cmd")"
echo "mac-dash=$(fire Darwin m2 'ls -Users-kai-proj')"
echo "linux-dash=$(fire Linux l2 'ls -Users-kai-proj')"
echo "mac-pipe=$(fire Darwin m3 'flutter test 2>&1 | tail -25')"
echo "linux-pipe=$(fire Linux l3 'flutter test 2>&1 | tail -25')"
echo "pipe-both=$([ "$(fire Darwin m5 "flutter test | tail -3")" = "pipe-exit" ] && [ "$(fire Linux l5 "flutter test | tail -3")" = "pipe-exit" ] && echo yes || echo no)"
# a four-column row (no os column) is `any`
mkdir -p fakeroot/hooks/checks
printf 'zz-legacy\tqqmarker\tlegacy row\tnone\n' > fakeroot/hooks/checks/tool.tsv
echo "legacy-mac=$(fire Darwin m4 'echo qqmarker' "$PWD/fakeroot")"
echo "legacy-linux=$(fire Linux l4 'echo qqmarker' "$PWD/fakeroot")"
# the per-session flag files carry the asst- prefix
ls flags | grep -q '^asst-m1-bsd-sed-b\.flag$' && echo flag=asst || echo flag=other
echo done=1
SH
