#!/usr/bin/env bash
# UserPromptSubmit — in a project that has an assistant project config
# (`.claude/assistant.md`, found the way every asst-* script finds it), attach a
# reminder to every prompt that work here goes through the assistant skill's
# flow. Every turn, not once: a rule loaded at session start fades, and the agent
# drifts back to editing code itself. Anywhere else it prints nothing.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cwd=$(jq -r '.cwd // empty' 2>/dev/null) || exit 0
cd "${cwd:-.}" 2>/dev/null || exit 0
# shellcheck source=../skills/assistant/scripts/root.sh
. "$here/../skills/assistant/scripts/root.sh"
root=$(asst_root)
[ -f "$root/.claude/assistant.md" ] || exit 0

text="This project runs the assistant flow (its project config is ${root}/.claude/assistant.md). \
When the user asks for something to be built, fixed or changed here, load the \`assistant\` skill if it isn't loaded, \
then follow its flow: write the task statement with its tier, put the row in the project's tracker, \
and dispatch \`builder\`, \`tester\` and \`verifier\` agents. Don't edit the project's code yourself, whatever the tier. \
A question, a progress check or a decision the user hands back is answered from the tracker and the filed reports."
jq -n --arg t "$text" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$t}}'
