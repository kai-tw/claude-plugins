#!/usr/bin/env bash
# commit-gate.sh — PreToolUse(Bash): deny `git commit` and `gh pr|issue
# create|edit|comment` whose text uses its locale's banned terms.
#
# The locale comes from the message, not the conversation: the agent picks a
# commit's language per repo, and what gets checked is what gets written.
#
# Only the message is judged — heredoc bodies, quoted strings, and files named by
# -F/--file/--body-file — minus `…-by:` trailers and the Claude Code footer. The
# command words and a Co-Authored-By line outnumber a short Chinese subject and
# would otherwise make it `en`, which is never scanned.
set -uo pipefail
[ "${MOTHER_TONGUE:-on}" = off ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
here=$(cd "$(dirname "$0")" && pwd)
input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
grep -qE '(^|[;&|[:space:]])(git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+commit|gh[[:space:]]+(pr|issue)[[:space:]]+(create|edit|comment))' <<<"$cmd" || exit 0

msg=$(perl -0777 -ne '
  my @out;
  push @out, $3 while s/<<-?[ \t]*(["\x27]?)(\w+)\1[^\n]*\n(.*?)\n[ \t]*\2(?=\W|$)//s;
  push @out, $1 // $2 while /"((?:[^"\\]|\\.)*)"|\x27([^\x27]*)\x27/gs;
  print join "\n", @out;
' <<<"$cmd")
while IFS= read -r f; do
  f=${f#[\"\']}; f=${f%[\"\']}
  [ "$f" = - ] && continue
  case $f in /*) ;; *) f="${cwd:-.}/$f" ;; esac
  [ -r "$f" ] && msg+=$'\n'$(cat "$f")
done < <(grep -oE '(^|[[:space:]])(-F|--file|--body-file)(=|[[:space:]]+)[^[:space:];&|]+' <<<"$cmd" \
         | sed -E 's/^[[:space:]]*(-F|--file|--body-file)(=|[[:space:]]+)//')
msg=$(perl -CSD -pe 's/^.*-by:.*$//i; s/^.*Generated with \[Claude Code\].*$//' <<<"$msg")

loc=$("$here/detect.sh" <<<"$msg")
hits=$("$here/scan.sh" "$loc" <<<"$msg")
[ -n "$hits" ] || exit 0

jq -n --arg h "$hits" --arg l "$loc" '{hookSpecificOutput:{hookEventName:"PreToolUse",
  permissionDecision:"deny",
  permissionDecisionReason:("The message uses terms that are not " + $l + " usage: " + $h + ". Rewrite it and run the command again.")}}'
