#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh prints `<id>-<what>=…` for SKILL.md, references/inbox.md and the Inbox page.
set -euo pipefail
cat > check.sh <<'SH'
root=$1
a="$root/skills/assistant"
n() { tr -s ' \n' ' ' < "$1"; }
c() { grep -ciE -- "$2" <<<"$1"; }
# S16: SKILL.md never names AskUserQuestion and says questions go at the end of the turn.
s=$(n "$a/SKILL.md")
echo "s16-no-askuserquestion=$(grep -c 'AskUserQuestion' <<<"$s")"
echo "s16-turn-end=$(c "$s" 'end of (the|your) (turn|reply|message)|last message|turn.s end')"
# S17: references/inbox.md exists and covers each step.
f="$a/references/inbox.md"
if [ -f "$f" ]; then
  i=$(n "$f"); echo "s17-exists=1"
  echo "s17-when=$(c "$i" 'habit|away|break|rest|not (replied|answered)|unanswered')"
  echo "s17-find=$(c "$i" 'title')"
  echo "s17-publish=$(c "$i" 'publish')"
  echo "s17-same-url=$(c "$i" 'republish[^.]{0,160}(url|address|link)|same (url|address|link)')"
  echo "s17-db=$(c "$i" '\bdb\b')"
  echo "s17-project-task=$(c "$i" 'project[^.]{0,80}task|task[^.]{0,80}project')"
  echo "s17-wake=$(c "$i" 'wake|woke|woken')"
  echo "s17-read-answer=$(c "$i" '(read|reads|reading)[^.]{0,60}answer|answer[^.]{0,60}(read|db)')"
  echo "s17-notice=$(c "$i" 'notice')"
  echo "s17-no-button=$(c "$i" 'no button|without (a )?button|not (a )?button|never[^.]{0,20}button')"
else
  echo "s17-exists=0"
fi
# S18: the plugin ships an Inbox page (any inbox*.html under the plugin, outside evals/).
p=$(find "$root" -path "$root/evals" -prune -o -type f -iname 'inbox*.html' -print | head -1)
if [ -n "$p" ]; then
  h=$(n "$p"); echo "s18-page=1"
  echo "s18-send=$(grep -c 'comments\.sendToClaude' <<<"$h")"
  echo "s18-db=$(c "$h" '\bdb\b')"
  # a click or submit listener whose callback is, or calls, the function holding the sendToClaude call
  hit=0
  fns=$(grep -oE "addEventListener\( ?['\"](click|submit)['\"], ?(\([^)]*\) ?=> ?)?[A-Za-z_]+" <<<"$h" | grep -oE '[A-Za-z_]+$' | sort -u)
  for x in $fns; do grep -qE "function $x ?\([^)]*\) ?\{.*comments\.sendToClaude" <<<"$h" && hit=1; done
  grep -qE "(addEventListener\( ?['\"](click|submit)['\"]|onclick|onsubmit).*comments\.sendToClaude" <<<"$h" && hit=1
  echo "s18-send-in-handler=$hit"
  echo "s18-notice=$(c "$h" 'notice')"
else
  echo "s18-page=0"
fi
SH
