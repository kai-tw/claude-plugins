#!/usr/bin/env bash
# path.sh — SessionStart: put this plugin's libexec/ on the Bash tool's PATH.
#
# WHY NOT bin/
#   Claude Code puts a plugin's top-level bin/ on PATH by itself, but claude.ai
#   refuses a plugin that has one ("Plugin contains a top-level bin/
#   directory"), so such a plugin never appears in Customize. libexec/ plus
#   this hook keeps every command callable by bare name either way.
#
# Lines appended to $CLAUDE_ENV_FILE are sourced before every Bash command of
# the session — measured to reach a sub-agent's Bash as well as the main one.
# Identical in every plugin that ships a libexec/.
[ -n "${CLAUDE_ENV_FILE:-}" ] && [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || exit 0
printf 'export PATH="%s/libexec:$PATH"\n' "$CLAUDE_PLUGIN_ROOT" >> "$CLAUDE_ENV_FILE"
exit 0
