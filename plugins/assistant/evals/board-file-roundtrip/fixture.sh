#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
mkdir -p .claude
printf 'vcs: svn\nboard: file\nkb: docs/kb\ngate: npm test\n' > .claude/assistant.md
printf '# Trash restore — 決策簡報\n\n## 意圖\n- 需要你 restore to the original place or the inbox — A original place / B inbox · 選 A\n' > brief.md
printf '# Trash restore\n\n### restore target\n**Context** two candidate places\n**Decision** original place\n**Consequence** inbox option dropped: needs one more UI layer\n' > decisions.md
printf '### undo window\n**Context** c\n**Decision** d\n**Consequence** e\n' > decisions2.md
