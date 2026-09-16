---
name: scribe
description: >-
  The assistant's Notion and file persistence toolbelt: `asst-notion` (request
  builder + writer, `--help` for commands), `asst-section` (edit one `## ` section
  of a local Markdown body). Used by the `scribe` and `builder` agents; not a user
  entry point.
tools:
  - Bash
---

# Scribe toolbelt

- `asst-notion <cmd> … --root <page-id>` — `node` builder over Notion's `ntn` CLI.
  Property encoding, DB registry, option validation, verify-after-write live in
  the script; `asst-notion --help` lists the commands. Writes are dry-run until
  `--commit`. The TaskList / plan / archive schemas are `schemas/*.mjs`.
- `asst-section replace|append|get <file> <heading> [md|-]` — edit one section of
  a body file; upload afterwards with `asst-notion update`.
- `ntn` gotchas the CLI does not tell you: raw `ntn api -X POST|PATCH` hangs
  unless stdin is closed (`</dev/null`); `ntn pages trash` needs `--yes`;
  `ntn pages get` prints the generated marker backslash-escaped.
