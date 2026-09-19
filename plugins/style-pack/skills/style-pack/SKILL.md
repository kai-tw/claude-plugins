---
name: style-pack
description: >-
  The founder's cross-project 撰寫法 — 母法 S1–S16 (`rules/index.md`) with Dart /
  C# / JS language files. `style-pack --paths <changed files>` prints the rules a diff
  is graded against; reviewers cite `S<N>.k` verbatim. To add or change a rule,
  read `rules/CONVENTIONS.md` first (立法程序與體例).
  TRIGGER: which style rule · 撰寫法 · S6 · add a style rule
allowed-tools:
  - Bash
  - Read
---

# Style pack

- `style-pack --paths <file…>` — 母法 + the language files those extensions map
  to (the map lives in the script). `style-pack dart csharp js` names them directly.
- `§位階` in `rules/index.md` is the one version of how the three layers rank:
  憲法 (母法) · 法律 (language files) · 命令 (a project's `.claude/rules/`).
- Legislating: `${CLAUDE_PLUGIN_ROOT}/skills/style-pack/rules/CONVENTIONS.md`.
