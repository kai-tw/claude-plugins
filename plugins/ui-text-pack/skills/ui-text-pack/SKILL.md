---
name: ui-text-pack
description: >-
  The founder's cross-project rules for writing user-visible text — charter U1–U5
  (`rules/index.md`) plus zh-Hant / ja / en locale files. `ui-text-pack --paths
  <changed locale files>` prints the rules a string change is graded against;
  reviewers cite `U<N>.k` verbatim. To add or change a rule, read
  `rules/CONVENTIONS.md` first (legislative procedure and format).
  TRIGGER: which UI text rule · 文字撰寫法 · UI text writing rules · U3 · add a UI
  text rule · 翻譯規則 · translation rules
allowed-tools:
  - Bash
  - Read
---

# UI text pack

- `ui-text-pack --paths <file…>` — charter + the locales those ARB filenames carry
  (`app_zh_Hant.arb` → zh-Hant). `ui-text-pack zh-Hant ja en` names them directly.
  A locale with no file is not an error: the charter alone binds, and the tag is
  named on stderr.
- `§Precedence` in `rules/index.md` is the one version of how the three layers rank:
  Constitution (charter) · Statute (locale layer) · Regulation (a project's own
  string canon).
- What this pack does **not** carry: anything a script can decide (term
  blocklists, punctuation width, second person, missing translations) — that
  belongs to each project's string checker, per the admission criteria in
  `rules/CONVENTIONS.md`.
- Legislating: `${CLAUDE_PLUGIN_ROOT}/skills/ui-text-pack/rules/CONVENTIONS.md`.
