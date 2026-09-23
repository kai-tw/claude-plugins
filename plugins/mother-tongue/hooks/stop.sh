#!/usr/bin/env bash
# stop.sh — Stop: block a reply that uses its locale's banned terms, so the
# agent rewrites the offending sentences before the turn ends.
#
# The locale is detected from the reply itself, not the prompt: the terms that
# matter are the ones actually written. A reply too short to tell falls back to
# the session's locale from remind.sh.
#
# The rewrite is let through unchecked (stop_hook_active) — a second block could
# loop, and the rewrite has already been told exactly which terms to replace.
set -uo pipefail
[ "${MOTHER_TONGUE:-on}" = off ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
here=$(cd "$(dirname "$0")" && pwd)
input=$(cat)
[ "$(jq -r '.stop_hook_active // false' <<<"$input")" = true ] && exit 0

text=$(jq -r '.last_assistant_message // empty' <<<"$input")
if [ -z "$text" ]; then
  # Older hosts: the text blocks of every assistant entry after the last real
  # user prompt (tool results and injected meta entries are also type "user").
  tp=$(jq -r '.transcript_path // empty' <<<"$input")
  [ -f "$tp" ] || exit 0
  text=$(jq -rs '. as $a
    | ([range(length) | select($a[.].type == "user" and ($a[.].isMeta | not)
        and ($a[.].message.content | if type == "string" then true
             else (map(.type) | index("tool_result") | not) end))] | last // -1) as $u
    | $a[$u+1:][] | select(.type == "assistant")
    | .message.content[]? | select(.type == "text") | .text' "$tp" 2>/dev/null)
fi
[ -n "$text" ] || exit 0

session=$(jq -r '.session_id // empty' <<<"$input")
conv=$(cat "${TMPDIR:-/tmp}/mother-tongue-${session:-none}" 2>/dev/null)
loc=$("$here/detect.sh" <<<"$text")

# A reply that falls back to English in a non-English conversation is blocked
# whole. Only this direction: an unfenced English log pasted with a short
# question reads as an English prompt, and a reply in the user's language must
# not be blocked for it.
if [ "$loc" = en ] && [ -n "$conv" ] && [ "$conv" != en ]; then
  jq -n --arg c "$conv" '{decision:"block",reason:(
    "The conversation is in " + $c + ", but your last reply is in English. "
    + "Rewrite the reply in " + $c + ". Text the user asked for in English goes in a code block.")}'
  exit 0
fi

[ -z "$loc" ] && loc=$conv
hits=$("$here/scan.sh" "$loc" <<<"$text")
[ -n "$hits" ] || exit 0

jq -n --arg h "$hits" --arg l "$loc" '{decision:"block",reason:(
  "Your last reply uses terms that are not " + $l + " usage: " + $h + ". "
  + "Rewrite only the sentences that contain them, in " + $l + ", and post the corrected sentences. "
  + "If you were quoting a term itself, put it in backticks.")}'
