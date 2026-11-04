#!/usr/bin/env bash
# working-rules.sh — SessionStart: carry the rules that no command pattern can catch.
#
# WHY A SEPARATE LAYER FROM intercept.sh
#   `intercept.sh` fires on a command, so it doesn't rely on the model deciding
#   to look it up. These rules have no command to fire on — they govern how a
#   claim is worded and whether work is dispatched at all — so the only option
#   is to be present. That makes this the weaker layer.
#
# KEEP rules/working-rules.md TO A SCREENFUL
#   It is read at the top of every session in every project that installs this
#   plugin. Past a screenful it stops being read and becomes noise that gets
#   ignored, which is worse than absent because it teaches people to ignore
#   warnings. Merge into an existing rule before adding one.
#   The file is emitted verbatim: no stripping, no formatting, so what is in it
#   is exactly what is paid for.
set -uo pipefail
[ "${GUARDRAILS:-on}" = "off" ] && exit 0
f="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/rules/working-rules.md"
[ -r "$f" ] && cat "$f"
exit 0
