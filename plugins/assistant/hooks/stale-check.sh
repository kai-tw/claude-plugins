#!/usr/bin/env bash
# Stop — when the copy of this plugin this session runs is behind the marketplace
# index, update it, then tell the agent so it can tell the user.
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
# The update is the one `consumers.mjs` runs: `claude plugin update` in the
# install record's own directory, with that record's scope, after installing any
# `dependencies` the new version declares (`update` does not install them, and
# one missing dependency fails the load). No `-y`: a marketplace-declared command
# is never accepted on the user's behalf; the update then fails and the user gets
# the command to run. Several plugins carry this hook and Stop hooks run in
# parallel, so updates take a lock — concurrent writers of installed_plugins.json
# lose records.
#
# Blocks the stop so the notice reaches the model, at most ONCE per session
# (Claude Code also caps consecutive Stop blocks on its own). A Stop block is
# top-level `decision` / `reason`; `hookSpecificOutput.permissionDecision` is
# PreToolUse's shape and is silently ignored here (measured: the hook ran, the
# model never saw the notice). Everything here degrades to exit 0: a missing jq,
# an unexpected install layout, or a marketplace that is not a clone means no
# notice, never a stuck session.
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

id="$name@$mkt"
registry="$HOME/.claude/plugins/installed_plugins.json"

# The install this session runs from: a project record whose projectPath holds
# cwd (a worktree inside the project counts, and so does one elsewhere through
# git's common dir), else a user record.
main=""
[ -n "$cwd" ] && main=$(cd "$cwd" 2>/dev/null && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's#/\.git$##')
record=$(jq -c --arg id "$id" --arg cwd "$cwd" --arg main "$main" '
  (.plugins[$id] // []) as $all
  | ([$all[] | .projectPath as $p | select($p and ($p == $main
       or $cwd == $p or ($cwd | startswith($p + "/"))))]
     + [$all[] | select(.scope == "user")])[0] // empty' "$registry" 2>/dev/null)
scope=$(printf '%s' "$record" | jq -r '.scope' 2>/dev/null)
[ -n "$scope" ] || scope=project
dir=$(printf '%s' "$record" | jq -r '.projectPath // empty' 2>/dev/null)
[ -n "$dir" ] || { [ "$scope" = user ] && dir=$HOME || dir=$cwd; }

# Dependencies the new version declares that this install's scope lacks.
missing=$(jq -r --arg mkt "$mkt" '.dependencies[]? | "\(.name)@\(.marketplace // $mkt)"' "$index" 2>/dev/null \
  | while read -r dep; do
      jq -e --arg d "$dep" --arg s "$scope" --arg p "$dir" \
        '(.plugins[$d] // [])[] | select(.scope == $s and ($s == "user" or .projectPath == $p))' \
        "$registry" >/dev/null 2>&1 || printf '%s ' "$dep"
    done)

update() {
  [ -n "$record" ] || { echo "no install record of $id for ${cwd:-this project}"; return 1; }
  command -v claude >/dev/null 2>&1 || { echo "claude is not on the hook's PATH"; return 1; }
  cd "$dir" 2>/dev/null || { echo "cannot enter $dir"; return 1; }

  local lock="$HOME/.claude/plugins/.stale-check.lock" n=0
  until mkdir "$lock" 2>/dev/null; do
    # A lock older than five minutes belongs to a hook that was killed.
    [ -n "$(find "$lock" -maxdepth 0 -mmin +5 2>/dev/null)" ] && rmdir "$lock" 2>/dev/null && continue
    n=$((n + 1)); [ "$n" -ge 30 ] && { echo "another plugin update held the lock for 30s"; return 1; }
    sleep 1
  done
  trap 'rmdir "$lock" 2>/dev/null' RETURN

  local dep out
  for dep in $missing; do
    out=$(claude plugin install "$dep" --scope "$scope" </dev/null 2>&1) \
      || { echo "installing dependency $dep failed: $(printf '%s' "$out" | tail -1)"; return 1; }
  done
  out=$(claude plugin update "$id" --scope "$scope" </dev/null 2>&1) \
    || { echo "$(printf '%s' "$out" | tail -1)"; return 1; }

  # Read the result back from the registry, not from the exit code.
  jq -e --arg id "$id" --arg s "$scope" --arg p "$dir" --arg v "$latest" \
    '(.plugins[$id] // [])[] | select(.scope == $s and ($s == "user" or .projectPath == $p) and .version == $v)' \
    "$registry" >/dev/null 2>&1 || { echo "the install record still is not at $latest"; return 1; }
}

# How a running session picks up an update changes with Claude Code releases, so
# the agent looks it up instead of being told one fixed way.
apply="This session keeps running ${running} until it loads the update. Find out how \
this Claude Code version loads an updated plugin into a running session (its docs, \
its slash commands, or the claude-code-guide agent), and tell the user that way."
if why=$(update); then
  reason="The ${name} plugin running in this session was ${running}; ${mkt} publishes ${latest}, \
and the ${scope}-scope install for ${dir} has just been updated to ${latest} automatically. \
${apply} Tell them now, plainly, in one or two sentences."
else
  install=""
  for dep in $missing; do install+="claude plugin install ${dep} --scope ${scope} && "; done
  reason="The ${name} plugin running in this session is ${running}, but ${mkt} publishes ${latest}. \
Updating it automatically failed: ${why}. \
Tell the user now, plainly, and give them this command to run:

    cd ${dir:-<project>} && ${install}claude plugin update ${id} --scope ${scope}

Once it's installed: ${apply} Do not run the command yourself."
fi

jq -n --arg r "$reason" '{decision: "block", reason: $r}'
exit 0
