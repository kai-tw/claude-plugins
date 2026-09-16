# ntn — Notion CLI operational notes (the archivist's transport)

All KB I/O runs through Notion's official `ntn` CLI (`github.com/makenotion/cli`,
install per `https://ntn.dev`). It is self-documenting — prefer these over memory:
`ntn api ls` (every endpoint), `ntn api <path> --help | --docs | --spec`,
`ntn <command> --help`. `SKILL.md` holds the read / write flow; this file holds
what the CLI does not tell you.

## Binary + auth

- The builder resolves the binary itself (`$NTN_BIN` → `$NTN_INSTALL_DIR/ntn` →
  `PATH`), so `notion-payload …` works from a non-interactive shell even when
  `ntn` is on `PATH` only via the interactive one; an ad-hoc call uses the same
  resolution.
- `ntn login` saves credentials (a bot user in the workspace); same-user
  subprocesses reuse them. Headless: `NOTION_API_TOKEN` (takes precedence) or
  `NOTION_KEYRING=0` (file auth at `~/.config/notion/auth.json`). `ntn whoami`
  confirms. `NOTION_API_VERSION` pins the header — pin only when a version change
  breaks a call.

## Gotchas

These are the things that don't fail loudly — each one cost a debugging cycle.

- **`ntn api … -X POST|PATCH` HANGS unless stdin is closed.** A raw write call
  (`ntn api v1/pages -X POST -d '<json>'`, `… -X PATCH …`, `v1/search`, etc.)
  blocks reading stdin even though `-d` supplies the body — it never returns and
  hits the timeout. **Redirect stdin: `</dev/null`** in a shell, or spawn with
  `stdio: ['ignore','pipe','pipe']` in node. Reads (`-X GET`, `datasources
  query`, `pages get`) don't hang. Masking trap: piping to `head`/`grep` closes
  the pipe → SIGPIPE kills ntn early, so a write call *looks* fine; only
  redirecting to a file or fully consuming the output exposes the hang. The
  builder spawns ntn with stdin ignored, so it never hits this — but ad-hoc
  `ntn api` writes must. (macOS has no `timeout`/`gtimeout` to bound a stuck
  call — wrap with `perl -e 'alarm shift; exec @ARGV' <secs> <cmd…>`.)
- **`ntn pages trash <id>` needs `--yes`** in a non-interactive shell, otherwise it
  errors `Cannot confirm in a non-interactive environment`. The builder's `trash`
  command already passes it.
- **The `<!-- archivist-generated -->` marker round-trips, but escaped.**
  `ntn pages edit` stores it correctly, but `ntn pages get` prints it
  backslash-escaped (`\<!-- … --\>`). When you check for the marker (Iron Law 7 —
  never overwrite/trash an un-marked, hand-authored page), **strip backslashes
  first** or match the bare substring `archivist-generated`. The builder's `trash`
  and create-verify already do this.
- **File upload MUST be single-part.** `ntn files create` stages a *multi-part*
  upload, which this workspace's plan rejects with `400 … does not support
  multipart uploads`. Use the single-part REST flow instead:
  `ntn api v1/file_uploads -X POST -d '{"filename":"…","content_type":"image/png"}'`
  (default `single_part`, returns an `id`) → `ntn api v1/file_uploads/<id>/send -X
  POST --file <path>` (status becomes `uploaded`) → reference `{file_upload:{id}}`
  in an `image` block. The builder's mockup embed already does exactly this.
- **No batch create.** `ntn api v1/pages` creates **one** page per call — the
  builder loops per row. (The old claude.ai MCP's ≤100-row batch is gone; this is
  why archive runs are per-row, not one payload.)
- **Reverse-relations are not builder-written.** A DB's synced back-reference
  relations (e.g. TaskList's `Product Plans` / `Engineering
  Plans`) are Notion-managed; the builder never sets them and `schema --live`
  ignores them when reporting drift.
- **Block-append children take block JSON, not Markdown.** `ntn pages edit`
  replaces a body from Markdown; appending *without* a full re-send goes through
  `PATCH v1/blocks/<id>/children`, which wants Notion block objects. The builder's
  `append` converts a bounded Markdown subset for you — don't hand-build block JSON.

## Command crib

All `notion-payload` write commands are **dry-run** until `--commit`. Reads go
straight through `ntn`.

| Need | Command |
|---|---|
| Read a DB by property | `ntn datasources query <ds> --filter '<json>' --sort '<prop> [asc\|desc]' --json` — build `<json>` + ds with `notion-payload filter <db> Prop=Val` |
| Read one page (body) | `ntn pages get <id>` |
| Read a DB's live schema | `ntn api v1/data_sources/<ds>` (or `notion-payload schema --live [db]`) |
| Create rows + body | `notion-payload create <manifest> --commit` |
| Update properties / replace a body from its `bodyFile` | `notion-payload update <manifest> --commit` |
| Edit one section of the local body first | `plan-section replace\|append <bodyFile> <heading> [md\|-]` |
| Flip props on ONE page (no manifest) | `notion-payload set <db> <page-id> Prop=Val … --commit` |
| Tick a checklist box | `notion-payload check <id> "<text>" --commit` |
| Append blocks to a body | `notion-payload append <id> <md-file\|-> --commit` |
| Post a comment | `notion-payload comment <id> "<text>" --commit` |
| Trash a page | `notion-payload trash <id> --commit` |
