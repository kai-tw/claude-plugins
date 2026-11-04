---
name: ui-text-pack
description: >-
  The user's cross-project rules for writing user-visible text — core rules U1–U5
  (`rules/index.md`) plus zh-Hant / ja / en locale rules. `ui-text-pack --paths
  <changed locale files>` prints the rules a string change is checked against;
  reviewers cite `U<N>.k` verbatim. To add or change a rule, read
  `rules/CONVENTIONS.md` first (how to add a rule, and the rule format).
  TRIGGER: which UI text rule · 文案撰寫規範 · UI 文字規範 · UI text writing rules · U3 ·
  add a UI text rule · 翻譯規則 · translation rules
allowed-tools:
  - Bash
  - Read
---

# UI text pack

- `ui-text-pack --paths <file…>` — core rules + the locales those ARB filenames carry
  (`app_zh_Hant.arb` → zh-Hant). `ui-text-pack zh-Hant ja en` names them directly.
  A locale with no file is not an error: the core rules alone apply, and the tag is
  named on stderr.
- `§Precedence` in `rules/index.md` is the one version of how the three levels rank:
  core rules (`index.md`) · locale rules (`zh-Hant.md` / `ja.md` / `en.md`) · project
  rules (a project's `.claude/rules/` and its glossary, `strings_glossary:`).
- What this pack does **not** carry: anything a script can decide (term
  blocklists, punctuation width, second person, missing translations) — that
  belongs to each project's string checker, per the inclusion criteria in
  `rules/CONVENTIONS.md`.
- `examples/<locale>.tsv` — the user's rewrites that hold in every project, as
  draft → final pairs; `asst-strings examples` prints them after the project's own.
  A rewrite goes here as an example, never into a rule: language doesn't fit rules.
- Adding or changing a rule: `${CLAUDE_PLUGIN_ROOT}/skills/ui-text-pack/rules/CONVENTIONS.md`.
