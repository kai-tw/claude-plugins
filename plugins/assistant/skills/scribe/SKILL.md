---
name: scribe
description: >-
  The assistant's persistence toolbelt: `asst-board` (task rows, brief, decisions —
  Notion or a local board file, per the adapter), `asst-notion` (the Notion
  request builder + writer behind it), `asst-section` (edit one `## ` section of a
  local Markdown body). Used by the assistant and the `builder` agent; not a user
  entry point.
---

# Scribe toolbelt

- `asst-board create|set|brief|decide|trash|list … [--dry-run]` — the board behind one
  op vocabulary; the adapter's `board:` picks Notion (via `asst-notion`) or
  `.claude/.assistant/board.md`. A row's properties are Name · Status · Stage ·
  `Blocked by` (the rows it waits for); what the row is goes in its body
  (`create … --body <file>`). `asst-board --help` has the decisions shape.
- `asst-notion <cmd> … --root <page-id>` — `node` builder over Notion's `ntn` CLI.
  Property encoding, DB registry, option validation, verify-after-write live in
  the script; `asst-notion --help` lists the commands. Writes are dry-run until
  `--commit`. A project that names its databases or properties in its own
  language maps them in `.claude/kb-databases.txt`, one per line:
  `decision-log = <title>`, `decision-log.Feature = <property name>`;
  `asst-notion schema <db>` shows the names in use.
- `asst-section replace|append|get <file> <heading> [md|-]` — edit one section of
  a body file; upload afterwards with `asst-notion update`.
- `ntn` gotchas the CLI does not tell you: any `ntn` call hangs or eats a loop's
  input unless stdin is closed (`</dev/null`); `ntn pages trash` needs `--yes`;
  `ntn pages get` prints the generated marker backslash-escaped.
- **`ntn api` lies about table blocks.** On a live page every `table` reports
  `in_trash: true`, and `v1/blocks/<table-id>/children` returns an empty list
  even for healthy ones. Read tables from the parent page's block listing.
- **Escape `|` inside a table cell as `\|`.** `ntn pages edit` sizes a table by
  its widest row, and each stray pipe adds a column — measured, one row of 901
  pipes under a 4-column header produced a 905-column table. It is lossless and
  it does not affect what follows, but it bloats the page ~7×.
- **Never verify a write against `ntn pages get`.** It is a re-rendering, not a
  copy — tables come back as HTML, a 133 KB body read back as 998 KB — and it
  flattens table text in with the headings, so a cell quoting `## Foo` makes a
  missing `## Foo` section look present. Read blocks back instead
  (`v1/blocks/<id>/children`, paginated); `asst-notion` does.
