---
name: style-pack
description: >-
  The founder's cross-project style code — charter S1–S16 (`rules/index.md`) with Dart /
  C# / JS language files. `style-pack --paths <changed files>` prints the rules a diff
  is graded against; reviewers cite `S<N>.k` verbatim. To add or change a rule,
  read `rules/CONVENTIONS.md` first (legislative procedure and drafting form).
  TRIGGER: which style rule · style code · 撰寫法 · S6 · add a style rule
allowed-tools:
  - Bash
  - Read
---

# Style pack

- `style-pack --paths <file…>` — the charter + the language files those extensions map
  to (the map lives in the script). `style-pack dart csharp js` names them directly.
- `§Precedence` in `rules/index.md` is the one version of how the three ranks order:
  constitution (the charter) · statute (language files) · regulation (a project's
  `.claude/rules/`).
- Legislating: `${CLAUDE_PLUGIN_ROOT}/skills/style-pack/rules/CONVENTIONS.md`.
