#!/bin/bash
# SessionStart hook -> inject the session journal so task / plan / worktree state
# survives context compaction, /clear, resume, and fresh startup.
#
# Fires on sources startup | resume | clear | compact. Auto-compaction and
# --resume keep the SAME session_id (so this session's detail file is found);
# /clear and a new session get a NEW id (empty detail) but still receive the
# cross-session index _active.md. Injecting here is DETERMINISTIC — it does not
# rely on the model remembering to read the file, which is the failure mode this
# system prevents.
#
# Thin by design: all journal logic lives in the plugin's scripts/journal.sh;
# this file only handles the SessionStart I/O contract. Stay fast, silent, and
# never fail the session — exit 0 on every path.

input=$(cat)

# Every output path below goes through jq, so without it this hook emits nothing
# and still exits 0 — the journal silently stops working while the plugin looks
# installed and healthy. That is the exact failure class this plugin exists to
# prevent, so say it out loud on the one channel that still works: a hand-built
# JSON literal (fixed text, nothing to escape). Still exit 0 — a missing
# dependency must not stop the session from starting.
if ! command -v jq >/dev/null 2>&1; then
  # Without jq we cannot parse agent_type, so match the raw payload instead;
  # otherwise every spawned subagent would repeat this warning.
  case "$input" in *'"agent_type"'*) exit 0 ;; esac
  printf '%s' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"session-journal is installed but its required dependency jq is not on PATH, so NOTHING is being journaled and no state will survive compaction or /clear. Tell the user this now, plainly, before doing anything else: they should install jq (brew install jq, apt install jq) and restart the session."}}'
  exit 0
fi

# Subagents fire SessionStart too, carrying an agent_type. The journal is the
# MAIN session's continuity surface — don't inject it into every spawned
# sub-agent (noise + tokens). agent_type is only present in subagent contexts.
agent_type=$(printf '%s' "$input" | jq -r '.agent_type // empty' 2>/dev/null)
[ -n "$agent_type" ] && exit 0

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)

script="$(dirname "$0")/../scripts/journal.sh"
body=""
if [ -x "$script" ]; then
  # Self-maintain: trash stale orphan detail files (default 14d, chain-aware).
  # Passing $sid keeps the current session exempt even on a fresh startup.
  bash "$script" gc "" "$sid" >/dev/null 2>&1
  # The project's current branch (resolved from the hook's cwd = the project
  # root, NEVER the script's own dir — as a plugin this file lives under
  # ~/.claude/plugins/, outside the project repo entirely, so `git -C
  # "$(dirname "$0")"` would report the plugin's branch or nothing) lets inject
  # auto-identify which thread this tree is, so a /clear'd worktree session
  # resumes the right one.
  branch="$(git branch --show-current 2>/dev/null || true)"
  body="$(bash "$script" inject "$sid" "$branch" 2>/dev/null)"
fi

if [ -z "$body" ]; then
  ctx="No session journal yet (docs/session-journal/). When you pick up or start a task, use the session-journal skill to record it — task / plan / where it lives (worktree, branch, PR, issue or tracker link) / next step — so it survives context compaction and /clear."
else
  ctx="Persistent session journal (in-repo, gitignored; survives compaction / clear / resume). Read it to recover which task threads are in flight and WHERE each one lives (worktree / branch / PR# / issue or tracker link) before acting; keep it current via the session-journal skill.

$body"
fi

printf '%s' "$ctx" | jq -Rs '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: .}}'
exit 0
