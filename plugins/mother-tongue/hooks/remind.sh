#!/usr/bin/env bash
# remind.sh — UserPromptSubmit: attach the conversation locale's rules.md to
# every prompt.
#
# WHY EVERY TURN AND NOT SESSION START
#   Rules loaded once at the top of a session fade as the conversation grows;
#   the agent drifts back to its default wording within the same session. Next
#   to the latest prompt is the only position that does not decay.
#
# A prompt with no detectable language ("ok", "1", a pasted path) keeps the
# locale of the last one that had it; the choice is stored per session so the
# Stop hook can fall back to the same answer.
set -uo pipefail
[ "${MOTHER_TONGUE:-on}" = off ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
here=$(cd "$(dirname "$0")" && pwd)
input=$(cat)
session=$(jq -r '.session_id // empty' <<<"$input")
state="${TMPDIR:-/tmp}/mother-tongue-${session:-none}"

loc=$(jq -r '.prompt // empty' <<<"$input" | "$here/detect.sh")
if [ -n "$loc" ]; then
  printf '%s' "$loc" > "$state" 2>/dev/null || true
else
  loc=$(cat "$state" 2>/dev/null)
fi

rules="$here/../locales/$loc/rules.md"
[ -n "$loc" ] && [ -r "$rules" ] || exit 0
jq -n --rawfile r "$rules" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$r}}'
