---
name: ui-text-pack
description: >-
  The founder's cross-project 使用者可見文字撰寫法 — 母法 U1–U5 (`rules/index.md`)
  plus zh-Hant / ja / en locale files. `ui-text-pack --paths <changed locale files>`
  prints the rules a string change is graded against; reviewers cite `U<N>.k`
  verbatim. To add or change a rule, read `rules/CONVENTIONS.md` first
  (立法程序與體例).
  TRIGGER: which UI text rule · 文字撰寫法 · U3 · add a UI text rule · 翻譯規則
allowed-tools:
  - Bash
  - Read
---

# UI text pack

- `ui-text-pack --paths <file…>` — 母法 + the locales those ARB filenames carry
  (`app_zh_Hant.arb` → zh-Hant). `ui-text-pack zh-Hant ja en` names them directly.
  A locale with no file is not an error: the 母法 alone binds, and the tag is
  named on stderr.
- `§位階` in `rules/index.md` is the one version of how the three layers rank:
  憲法 (母法) · 法律 (語系層) · 命令 (a project's own string canon).
- What this pack does **not** carry: anything a script can decide (term
  blocklists, punctuation width, 第二人稱, missing translations) — that belongs to
  each project's string checker, per `rules/CONVENTIONS.md` 入庫要件.
- Legislating: `${CLAUDE_PLUGIN_ROOT}/skills/ui-text-pack/rules/CONVENTIONS.md`.
