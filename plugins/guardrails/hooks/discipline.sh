#!/usr/bin/env bash
# discipline.sh — SessionStart: carry the rules that no command pattern can catch.
#
# WHY A SEPARATE LAYER FROM intercept.sh
#   `intercept.sh` fires on a command, so it needs no trigger judgment. These
#   rules have no command to fire on — they govern how a claim is worded and
#   whether work is dispatched at all — so the only option is to be present.
#   That makes this the weaker layer.
#
# KEEP rules/discipline.md TO A SCREENFUL
#   It is read at the top of every session in every project that installs this
#   plugin. Past a screenful it stops being read and becomes wallpaper, which is
#   worse than absent because wallpaper trains dismissal. Fuse before adding.
#   The file is emitted verbatim: no stripping, no formatting, so what is in it
#   is exactly what is paid for.
set -uo pipefail
[ "${GUARDRAILS:-on}" = "off" ] && exit 0
f="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/rules/discipline.md"
[ -r "$f" ] && cat "$f"
exit 0
