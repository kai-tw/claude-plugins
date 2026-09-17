#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
mkdir -p .claude
printf 'vcs: svn\nboard: file\nkb: docs/decisions\ngate: npm test\n' > .claude/assistant.md
printf '# Trash restore — 決策簡報\n\n## 意圖\n- 需要你 restore 到原位或收件匣 — A 原位 / B 收件匣 · 選 A\n' > brief.md
printf '# Trash restore\n\n## Overview\nrestore from trash.\n## Problem\nno way back.\n## Final Approach\nA.\n## Key Decisions\n- 原位\n## Deferred Items\n- 無\n\n## Decisions\n### restore 位置\n**Context** 兩個候選位置\n**Decision** 原位\n**Consequence** 收件匣方案放棄：需多一層 UI\n' > archive.md
