---
name: archivist
description: >-
  The single gateway for every read and write against the project's Notion KB
  (TaskList, plans, Feature Archive, decisions). Extraction-style writes, never
  verbatim dumps.
  TRIGGER: anything that touches Notion / the KB / the TaskList · 查 Notion ·
  更新知識庫 · 歸檔到 Notion
  NOT for: authoring product / design / engineering plans (the PM, designer and
  engineer roles)

---

# Archivist — Notion KB operations

The single path for every read and write against a project's Notion KB. Read
before you write; synthesize, never dump; confirm scope before touching anything;
never delete a canonical repo doc before its Notion entry is verified.

## Where the detail lives

- **`notion-payload --help`** — the request builder + writer (`create` / `update` /
  `set` / `filter` / `schema` / `hints` / `template` / `sections` / `criteria` /
  `trash` / `check` / `append` / `comment`), and the single source of truth for
  the property encoding and the DB registry. Feed it clean rows: it validates
  every option against the DB's live vocabulary, encodes, drives `ntn`, and
  verifies. Every write is a dry-run until `--commit`. Never hand-encode a Notion
  property — the wire shape is non-obvious and a mis-encode fails late.
- **`plan-section replace|append|get <bodyFile> <heading> [md|-]`** — edit one
  `## ` section of a local plan body, then upload with `notion-payload update …
  --commit` (`bodyFile`). A rev emits the changed section, never the whole plan.
- **`references/notion-kb.md`** — workspace layout (`--root`), per-DB schema +
  conventions, synthesis and title rules. Read it before any create / update.
- **`references/ntn.md`** — the `ntn` transport: binary resolution, auth, the
  gotchas that fail silently, and a command crib.
- **`references/notion-io-subagent.md`** — the one delegation case (reading many
  full bodies) and its prompt templates.

## Body shapes

Section-keyed (the builder assembles `## section` fields): `feature-archive` and
`decision-log` (an unknown or missing section is rejected), `product-plan` and
`engineering-plan` (`freeformBody`: sections are advisory and drive `hints`).
Opaque `content` string: `tasklist`, `release-log`, `analytics-catalog`.
`notion-payload schema <db>` prints the exact fields.

**CJK-heavy bodies go through `bodyFile`**: author once as Markdown (`## Heading`s
per the schema), put `"bodyFile": "<path>"` on the row; the builder uploads it
byte-exact and validates the headings. On update a `bodyFile` is a full-body
replace — the file is the source of truth. Convention:
`docs/session-journal/<sid>/<artifact>.md` (the `plan-path` helper prints it). A
`⚠ … half-width punctuation` line is a warning, not a failure: fix what it names,
the upload is not blocked.

## Reading

- **Filter a DB by property**: `notion-payload filter <db> Prop=Val …` prints the
  ds id, the filter JSON and the ready `ntn datasources query … --json` command
  (properties only, no body fan-out). `--plain` for a table; `--sort`, `--limit`,
  `--start-cursor`; date props take `<`, `<=`, `>`, `>=` and `today`.
- **One page**: `ntn pages get <id>` (properties + Markdown body);
  `ntn api v1/pages/<id>` for properties only.
- **Live schema**: `ntn api v1/data_sources/<ds-id>`.
- **Many full bodies for synthesis**: delegate (`general-purpose`, `model: haiku`)
  per `references/notion-io-subagent.md` — it returns the distilled result only;
  synthesis and the ledger stay here.

**Picking the next task**: TaskList `Status` is the pickup order — walk `Next` →
`Backlog` → `Deferred` and surface the highest non-empty bucket. `In Progress` is
resumed, never re-picked; a `Deferred` task needs its `Trigger` confirmed fired;
`Tracing` is skipped unless its `Check Date` is due (`filter tasklist
Status=Tracing "Check Date<=today"`). More than one candidate → present them;
never pick silently.

## Iron Laws

1. **Confirm scope before touching anything.** No named feature → inventory the
   TaskList (each feature's plan rows + `Stage`) and ask which are shipped /
   abandoned / superseded / in-flight. Never archive a non-terminal cycle.
2. **Push + verify before delete.** `--commit` re-reads the page, confirms every
   `## ` section arrived, and exits non-zero if one did not (the marker alone
   proves nothing — it is prepended). Then re-read (`ntn pages get` /
   `datasources query`) and confirm the content; only then trash the repo docs.
   CJK content gets a hanzi-by-hanzi proofread against the source first.
3. **Synthesize, never verbatim-dump.** Extracted sections only; no raw "Source
   Archive" block; a revision trail collapses to one current-state page + a few
   decision entries. Links run repo → Notion only — a Notion page never depends
   on a repo path.
4. **Titles are Title Case, never slugs** (`references/notion-kb.md §Title
   convention`).
5. **Feature Area / Area = readable Title Case labels mirroring `lib/features/`
   folders.** Each DB has its own vocabulary; the builder validates against the
   live one, so a drifted label fails loudly instead of minting an option.
6. **Engineering ≠ PM corpus.** Engineering plans, test plans and review logs
   stay out of the PM corpus unless explicitly requested; QA logs are trashed,
   never Notion'd.
7. **Never overwrite a hand-maintained page.** No `<!-- archivist-generated -->`
   marker → hand-authored → stop and report.
8. **The user feedback log is canonical in Notion.** Append there; no repo copy.
9. **Repo files: `guardrails` decides `trash` vs `rm`.** A Notion page goes via
   `ntn pages trash <id> --yes`.
10. **Report Notion URLs** for every page created / updated, plus the removal
    manifest of repo files trashed.

## Default workflow (archive a feature)

1. Confirm scope (Iron Law 1).
2. Verify the cycle is terminal (`Stage` = Shipped, or abandoned / closed; not
   parked in a Security / Privacy / Review / QA loop). In-flight → stop.
3. Read every canonical source for the feature.
4. Synthesize the row(s) into a manifest — properties + body sections
   (`notion-payload schema <db>` for the fields, `references/notion-kb.md` for
   the conventions; the builder owns the skeleton + the marker).
5. `notion-payload create <manifest> --commit` (creates, writes the body,
   verifies). Stage / checklist flips: `update` or `set … --commit`.
6. Spot-check with `ntn datasources query` / `ntn pages get` if needed.
7. Trash the canonical docs; leave a repo → Notion breadcrumb where a kept repo
   doc referenced them.
8. Report URLs + the removal manifest.

## Plan-cycle ledger (mirror every /plan Notion write locally)

The Stop-hook gate (`plan-cycle`) can only see a local ledger that mirrors the
Notion writes you make, so record each one **immediately after it lands**. Call it
by bare name — `plan-cycle` is on `PATH`; a `command not found` is the gate being
off, say so. It no-ops when no cycle is active.

| The Notion write you just made | Mirror it with |
|---|---|
| Created the TaskList task (the `/plan` Step 2 anchor) | `plan-cycle start "<task-slug>" "<Task Name>"` |
| Picked a task back up whose cycle already exists (a new session inherits no pointer) | `plan-cycle join "<task-slug>"` |
| Flipped the task's **`Stage`** property | `plan-cycle enter "<Stage>"` (exact label: Product Plan / Design Plan / Translation / Engineering Plan / Security / Privacy / Implementation / Review / QA / Archived) |
| Created/updated a **Product / Engineering Plan** row (after the Iron-Law-2 verify), or published the design contact sheet | `plan-cycle uploaded <pm\|designer\|engineer> <url>` — the URL is the proof Gate 1 trusts; no URL means the write did not land |
| Closed out (Feature Archive verified + task row trashed) | `plan-cycle clear` |

Mark `uploaded` only after the verify; a re-uploaded (rev'd) plan runs it again —
idempotent.

## Heavy batches

Work a multi-feature batch in domain-sized chunks, one `--commit` pass per DB per
chunk; the irreversible repo removal stays a single confirmed step at the end.
