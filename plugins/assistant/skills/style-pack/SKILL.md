---
name: style-pack
description: >-
  The user's cross-project code style guide — core rules S1–S16 (`rules/index.md`) with
  Dart / C# / JS language rules. `style-pack --paths <changed files>` prints the rules a
  diff is checked against; reviewers cite `S<N>.k` verbatim. To add or change a rule,
  read `rules/CONVENTIONS.md` first (how to add a rule, and the rule format).
  TRIGGER: which style rule · style guide · 程式碼風格規範 · 撰寫規範 · S6 · add a style rule
allowed-tools:
  - Bash
  - Read
---

# Style pack

- `style-pack --paths <file…>` — the core rules + the language rules those extensions map
  to (the map lives in the script) + `./.claude/.assistant/style-rules/*.md`.
  `style-pack dart csharp js` names the languages directly.
- `§Precedence` in `rules/index.md` is the one version of how the three levels rank:
  core rules (`index.md`) · language rules (`dart.md` / `csharp.md` / `js.md`) · project
  rules (a project's `.claude/rules/` and `.claude/.assistant/style-rules/`).
- Adding or changing a rule: `${CLAUDE_PLUGIN_ROOT}/skills/style-pack/rules/CONVENTIONS.md`.
