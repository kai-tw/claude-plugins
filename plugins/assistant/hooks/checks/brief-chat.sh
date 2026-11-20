#!/usr/bin/env bash
# brief-chat.sh — PreToolUse(any tool): a chat message
# followed by a tool call is at most 120 characters. When the assistant text written
# since the last user line (prompt or tool result) is longer, attach a reminder to
# the tool call. Never a permission decision; never blocks.
#
# Silent in a subagent, in a project without `.claude/assistant.md`, without jq, and
# when the transcript is missing, unreadable or not JSON lines. Characters are
# counted as Unicode characters in node, because the shell's own counters count
# bytes without a UTF-8 locale. Only the transcript's tail is read: this runs on
# every tool call.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
command -v node >/dev/null 2>&1 || exit 0
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
payload=$(cat 2>/dev/null)
field() { printf '%s' "$payload" | jq -r "$1 // empty" 2>/dev/null; }
[ -z "$(field .agent_id)" ] || exit 0
cwd=$(field .cwd)
transcript=$(field .transcript_path)
[ -n "$transcript" ] || exit 0
cd "${cwd:-.}" 2>/dev/null || exit 0
# shellcheck source=../../skills/assistant/scripts/root.sh
. "$here/../../skills/assistant/scripts/root.sh"
[ -f "$(asst_root)/.claude/assistant.md" ] || exit 0

count=$(node -e '
const fs = require("fs");
try {
  const fd = fs.openSync(process.argv[1], "r");
  const size = fs.fstatSync(fd).size;
  let n = Math.min(size, 262144), total, found = false;
  for (;;) {
    const buf = Buffer.alloc(n);
    fs.readSync(fd, buf, 0, n, size - n);
    const lines = buf.toString("utf8").split("\n");
    if (n < size) lines.shift();
    total = 0;
    found = false;
    for (let i = lines.length - 1; i >= 0; i--) {
      let e;
      try { e = JSON.parse(lines[i]); } catch { continue; }
      if (e.type === "user") { found = true; break; }
      if (e.type !== "assistant") continue;
      const c = e.message && e.message.content;
      if (typeof c === "string") total += [...c].length;
      else if (Array.isArray(c)) for (const b of c) if (b && b.type === "text" && typeof b.text === "string") total += [...b.text].length;
    }
    if (found || n >= size) break;
    n = Math.min(size, n * 4);
  }
  process.stdout.write(String(total));
} catch { process.exit(1); }
' "$transcript" 2>/dev/null) || exit 0
case $count in ''|*[!0-9]*) exit 0 ;; esac
[ "$count" -gt 120 ] || exit 0

text="The text before this tool call was ${count} characters; a message followed by a tool call is at most 120 characters."
jq -n --arg t "$text" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$t}}'
