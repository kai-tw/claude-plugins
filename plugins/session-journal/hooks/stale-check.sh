#!/usr/bin/env bash
# Stop — tell the agent when the copy of this plugin it is running is behind the
# marketplace index.
#
# The version a session actually resolved to cannot be determined from outside
# (see .claude/rules/releasing.md): install records say what was installed, not
# what a given session loaded. From INSIDE it is not an inference — this script
# ships in the install it is reporting on, so `$here/..` IS the running copy and
# its plugin.json IS the running version. That is the whole reason this check
# lives in the plugin rather than in some cross-plugin scanner.
#
# Compared against the local marketplace clone, NOT the network: `release.mjs`
# refreshes that clone as step 6, so it is already current by the time you move
# to a consumer project — which is exactly when the drift matters. A clone that
# was never refreshed produces silence, never a wrong answer.
#
# Blocks the stop so the reason reaches the model as a system message, at most
# ONCE per session (Claude Code independently caps Stop blocks at 10
# consecutive). Everything here degrades to exit 0: a missing jq, an unexpected
# install layout, or a marketplace that is not a clone means no notice, never a
# stuck session.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"

# Re-entry guard: we are the reason this stop is being re-evaluated.
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = true ] && exit 0

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$here/.." && pwd)

running=$(jq -r '.version // empty' "$root/.claude-plugin/plugin.json" 2>/dev/null) || exit 0
[ -n "$running" ] || exit 0

# …/cache/<marketplace>/<name>/<version> — anything else (a skills-dir plugin, a
# directory marketplace, a checkout run in place) has no index to compare with.
name=$(basename "$(dirname "$root")")
mkt=$(basename "$(dirname "$(dirname "$root")")")
index="$HOME/.claude/plugins/marketplaces/$mkt/plugins/$name/.claude-plugin/plugin.json"
[ -f "$index" ] || exit 0

latest=$(jq -r '.version // empty' "$index" 2>/dev/null) || exit 0
[ -n "$latest" ] && [ "$latest" != "$running" ] || exit 0

# Only speak up when the index is AHEAD. Behind means a local checkout newer
# than what is published — the author's own working state, not a stale install.
[ "$(printf '%s\n%s\n' "$running" "$latest" | sort -V | tail -1)" = "$latest" ] || exit 0

session=$(printf '%s' "$input" | jq -r '.session_id // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')

# Once per session. Keyed by plugin as well as session so two plugins carrying
# this hook do not silence each other.
if [ -n "$session" ]; then
  stamp="${TMPDIR:-/tmp}/claude-stale-$name-$session"
  [ -e "$stamp" ] && exit 0
  : > "$stamp" 2>/dev/null || true
fi

reason="The ${name} plugin running in this session is ${running}, but ${mkt} publishes ${latest}. \
You are working against an outdated copy of its skills, hooks and scripts. \
Tell the user now, plainly, and give them this command to run:

    cd ${cwd:-<project>} && claude plugin update ${name}@${mkt} --scope project

Then say that the update only takes effect in a NEW session, so this one keeps \
running ${running} regardless. Do not run the command yourself."

jq -n --arg r "$reason" '{
  hookSpecificOutput: {
    hookEventName: "Stop",
    permissionDecision: "block",
    permissionDecisionReason: $r
  }
}'
exit 0
