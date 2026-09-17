---
name: scribe
description: >-
  The assistant's persistence toolbelt: `asst-board` (task rows, brief, archive —
  Notion or a local board file, per the adapter), `asst-notion` (the Notion
  request builder + writer behind it), `asst-section` (edit one `## ` section of a
  local Markdown body). Used by the `scribe` and `builder` agents; not a user
  entry point.
tools:
  - Bash
---

# Scribe toolbelt

- `asst-board create|set|brief|archive|list … [--dry-run]` — the board behind one
  op vocabulary; the adapter's `board:` picks Notion (via `asst-notion`) or
  `.claude/.assistant/board.md`. `asst-board --help` has the archive shape.
- `asst-notion <cmd> … --root <page-id>` — `node` builder over Notion's `ntn` CLI.
  Property encoding, DB registry, option validation, verify-after-write live in
  the script; `asst-notion --help` lists the commands. Writes are dry-run until
  `--commit`. The TaskList / plan / archive schemas are `schemas/*.mjs`.
- `asst-section replace|append|get <file> <heading> [md|-]` — edit one section of
  a body file; upload afterwards with `asst-notion update`.
- `ntn` gotchas the CLI does not tell you: raw `ntn api -X POST|PATCH` hangs
  unless stdin is closed (`</dev/null`); `ntn pages trash` needs `--yes`;
  `ntn pages get` prints the generated marker backslash-escaped.
