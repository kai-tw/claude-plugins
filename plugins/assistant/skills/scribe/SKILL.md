---
name: scribe
description: >-
  The assistant's Notion toolbelt: `asst-notion` (the Notion request builder +
  writer) and `asst-section` (edit one `## ` section of a local Markdown body).
  Used by the assistant; not a user entry point.
---

# Scribe toolbelt

- `asst-notion <cmd> … --root <page-id>` — `node` builder over Notion's `ntn` CLI;
  the root id is the one the project's CLAUDE.md gives.
  Property encoding, DB registry, option validation, verify-after-write live in
  the script; `asst-notion --help` lists the commands. Writes are dry-run until
  `--commit`. A project that names its databases or properties in its own
  language maps them in `.claude/kb-databases.txt`, one per line:
  `decision-log = <title>`; `asst-notion schema <db>` shows the names in use.
  Spec pages (`kb-pages`) are read-only: any write aimed at one exits non-zero.
- A Notion tracker: a task is a `tasklist` row (`asst-notion create`, its page id kept
  in `.claude/.assistant/tasks/<slug>/page`), `Blocked by` and `Parent item` taking
  page ids; the brief goes in with `append`; each decision is one `decision-log` row
  (Name = the question, Context · Decision · Consequence, `Task` = the task row, `Status=Active`, `Decided` = today); Close is `trash`.
  Read rows with `query tasklist`, one row with `get <page-id> [--body]`.
- `asst-section replace|append|get <file> <heading> [md|-]` — edit one section of
  a body file; upload afterwards with `asst-notion update`.
- `ntn` gotchas the CLI does not tell you: any `ntn` call hangs or eats a loop's
  input unless stdin is closed (`</dev/null`); `ntn pages trash` needs `--yes`;
  `ntn pages get` prints the generated marker backslash-escaped.
- **`ntn api` lies about table blocks.** On a live page every `table` reports
  `in_trash: true`, and `v1/blocks/<table-id>/children` returns an empty list
  even for intact ones. Read tables from the parent page's block listing.
- **Escape `|` inside a table cell as `\|`.** `ntn pages edit` sizes a table by
  its widest row, and each stray pipe adds a column — measured, one row of 901
  pipes under a 4-column header produced a 905-column table. It is lossless and
  it does not affect what follows, but it bloats the page ~7×.
- **Never verify a write against `ntn pages get`.** It is a re-rendering, not a
  copy — tables come back as HTML, a 133 KB body read back as 998 KB — and it
  flattens table text in with the headings, so a cell quoting `## Foo` makes a
  missing `## Foo` section look present. Read blocks back instead
  (`v1/blocks/<id>/children`, paginated); `asst-notion` does.
