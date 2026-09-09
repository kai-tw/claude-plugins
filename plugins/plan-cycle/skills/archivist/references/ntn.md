# ntn — Notion CLI operational notes (the archivist's transport)

All KB I/O runs through the official `ntn` CLI (a thin wrapper over the Notion REST
API). `SKILL.md` covers the read / write *flow*; this file holds the operational
detail and the **gotchas that fail silently or surprisingly** — read it before
driving `ntn` by hand, and whenever a raw `ntn` call behaves unexpectedly.

## Installing

`ntn` is Notion's official first-party CLI (Beta) — `github.com/makenotion/cli`,
installer served from `https://ntn.dev` (302s to the docs in a browser; a bare
`curl` gets the install script). On a fresh machine:

    curl -fsSL https://ntn.dev | NTN_INSTALL_DIR="$HOME/development/ntn" bash

`NTN_INSTALL_DIR` MUST sit on `bash`, not `curl` — a `VAR=… curl | bash` prefix
scopes the var to curl and the piped `bash` never sees it, dropping the binary in
the default `~/.local/bin` instead. Either dir is fine; if you take the default,
update `.zshrc`'s `NTN_INSTALL_DIR` export + the paths in §Invoking the binary to
match. Then `ntn --version` to verify, and `ntn login` (§Auth). Alternatives:
`npm install --global ntn`, or `winget install Notion.ntn` (Windows).

## Invoking the binary

- `ntn` is installed at `~/development/ntn`, and is on `PATH` **only** via the
  user's interactive shell (`.zshrc` exports `NTN_INSTALL_DIR`). A non-interactive
  tool shell does **not** have it on `PATH` — a bare `ntn …` returns "command not
  found". This bites every ad-hoc call.
- The builder resolves the binary itself (`$NTN_BIN` → `$NTN_INSTALL_DIR/ntn` →
  `~/development/ntn/ntn` → `PATH`), so `node notion_payload.mjs …` always works
  regardless of `PATH`.
- For an **ad-hoc** `ntn` call, first `export PATH="$HOME/development/ntn:$PATH"`,
  or invoke the absolute path `"${NTN_INSTALL_DIR:-$HOME/development/ntn}/ntn"`.

## Auth

- Authenticated via `ntn login` — saved credentials under `~/.config/notion` (a
  bot user in the workspace). Same-user subprocesses (including Agent-tool
  subagents on this machine) reuse it; nothing to pass through.
- `ntn whoami` / `ntn doctor` confirm the session is live (look for "Public API
  authenticated").
- **Headless / cron** (no interactive keychain unlock): export `$NOTION_API_TOKEN`
  (a personal access token — it takes precedence over the keychain), or set
  `$NOTION_KEYRING=0` to use file-based auth at `~/.config/notion/auth.json`.
- `$NOTION_API_VERSION` pins the `Notion-Version` header; the default auto-resolves
  to the latest (which supports the data-source model the registry relies on). Pin
  it only if a version change actually breaks a call — a wrong pin can only error a
  request, never corrupt data.

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

All `notion_payload.mjs` write commands are **dry-run** until `--commit`. Reads go
straight through `ntn`. (See `SKILL.md §Reading` and `§Build request bodies` for
the full flow; this is the quick lookup.)

| Need | Command |
|---|---|
| Read a DB by property | `ntn datasources query <ds> --filter '<json>' --sort '<prop> [asc\|desc]' --json` — build `<json>`+ds with `notion_payload.mjs filter <db> Prop=Val` |
| Read one page (body) | `ntn pages get <id>` |
| Read a DB's live schema | `ntn api v1/data_sources/<ds>` (or `notion_payload.mjs schema --live [db]`) |
| Create rows + body | `notion_payload.mjs create <manifest> --commit` |
| Update properties | `notion_payload.mjs update <manifest> --commit` |
| Flip props on ONE page (no manifest) | `notion_payload.mjs set <db> <page-id> Prop=Val … --commit` — the Status/Stage flip |
| Tick a checklist box | `notion_payload.mjs check <id> "<text>" --commit` |
| Append blocks to a body | `notion_payload.mjs append <id> <md-file\|-> --commit` |
| Post a comment | `notion_payload.mjs comment <id> "<text>" --commit` |
| Trash a page | `notion_payload.mjs trash <id> --commit` |
