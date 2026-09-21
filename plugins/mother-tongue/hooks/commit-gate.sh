#!/usr/bin/env bash
# commit-gate.sh — PreToolUse(Bash): deny `git commit` and `gh pr|issue
# create|edit|comment` whose text uses its locale's banned terms.
#
# The locale comes from the command text, not the conversation: the agent picks
# a commit's language per repo, and what gets checked is what gets written.
set -uo pipefail
[ "${MOTHER_TONGUE:-on}" = off ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
here=$(cd "$(dirname "$0")" && pwd)
cmd=$(jq -r '.tool_input.command // empty')
grep -qE '(^|[;&|[:space:]])(git[[:space:]]+commit|gh[[:space:]]+(pr|issue)[[:space:]]+(create|edit|comment))' <<<"$cmd" || exit 0

loc=$("$here/detect.sh" <<<"$cmd")
hits=$("$here/scan.sh" "$loc" <<<"$cmd")
[ -n "$hits" ] || exit 0

jq -n --arg h "$hits" --arg l "$loc" '{hookSpecificOutput:{hookEventName:"PreToolUse",
  permissionDecision:"deny",
  permissionDecisionReason:("The message uses terms that are not " + $l + " usage: " + $h + ". Rewrite it and run the command again.")}}'
