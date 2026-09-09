---
name: archivist
description: >-
  THE single gateway for EVERY operation against this project's Notion KB —
  reads AND writes. If a request touches that workspace in any way,
  it belongs here, so reads share one query path and writes stay consistent and
  founder-readable. Writes are extraction-style, never verbatim dumps; the body
  carries the page-title, Feature Area and verify-before-delete conventions.
  TRIGGER — any read, query, lookup, create, update or rename against the KB:
  what's in the TaskList · which tasks are Next / In Progress · pick up a task
  from Notion · show the backlog · show the roadmap · find the Notion page for X
  · look up X in the KB · what did we decide about X · what's shipped · archive
  X to Notion · move docs to Notion · update the KB · add to Feature Archive ·
  log a decision in Notion · update the TaskList · rename the Notion pages ·
  categorize the Feature Archive · build a Notion database · sync the feedback
  log · 查一下 Notion · Notion 上有哪些 X · 看一下 TaskList · 待辦事項 ·
  接一個 Next 的任務 · 挑一個任務 · Notion 裡 X 的決策是什麼 · 整理 Notion ·
  搬到 Notion · 更新知識庫 · 歸檔到 Notion
  NOT for: rollback · repo-side draft cleanup · speculative tidying · authoring
  product / design / engineering plans (those are the PM, designer and engineer
  roles)
---

# Archivist — Notion KB operations

This skill is the **single source of truth** for how a project **reads from
and writes to** its Notion knowledge base. Every Notion
KB action — query or mutation — routes through here and obeys these
conventions, so reads use one consistent path and writes stay **stable,
consistent, and non-engineer-readable**: a KB a founder browses, not a slug
dump.

You read before you write. You synthesize, you don't dump. You confirm scope
before touching anything. You never delete a canonical repo doc before its
Notion entry is verified.

## Where the detail lives

SKILL.md holds the principles + decisions. The lookup detail lives in the
skill folder — read the relevant file before a create/update so you don't
improvise structure:

- **`references/notion-kb.md`** — the canonical workspace layout (root + the
  DB ids), the per-database schema + conventions (Feature Archive · Decision
  Log · TaskList · the plan DBs · Release Log · Analytics), the
  KB-reference-page rule, and the synthesis + title conventions with worked
  examples. Read it before any create/update.
- **`notion-payload`** — the request builder
  + writer, and the SINGLE SOURCE OF TRUTH for the property encoding (standard
  Notion REST JSON: dates, checkboxes, multi-select, relations, url props) AND the
  synthesis body skeleton (Feature Archive + Decision Log). You feed it clean
  synthesized rows; without `--commit` it prints the per-row plan, with `--commit`
  it drives `ntn` to create/update + write the Markdown body + verify — validating
  every option against the DB's vocabulary. NEVER hand-encode a Notion property —
  run the builder. `notion-payload schema [db]`
  prints the exact fields per DB; it covers all seven DBs, split by body shape —
  run `schema <db>` to confirm. FOUR take a **section-keyed body** (the builder assembles
  each `## section` field and rejects a raw `content` string): `feature-archive`,
  `decision-log`, `product-plan`, `engineering-plan`. Of those, the
  **two plan DBs carry `freeformBody`** — their section arrays are ADVISORY
  (they drive `hints`; any `## heading` is legal and none is mandatory), so the
  author owns the plan's shape. `feature-archive` and `decision-log` are still
  **validated and rejected** on an unknown or missing section — their
  extraction-style discipline is the point. THREE take an opaque `content` string the authoring role
  already produced: `tasklist`, `release-log`, `analytics-catalog`. The split is
  **per-DB, NOT "synthesis vs plan/log"** — `decision-log` (a log) and all three
  plan DBs are section-keyed, so don't assume a plan/log DB accepts opaque
  `content`. **For a CJK-heavy body, prefer `bodyFile`** — author the body ONCE
  into a Markdown file (`## Heading`s matching the schema) and put
  `"bodyFile": "<path>"` on the row instead of inline section fields; the builder
  uploads it byte-exact (never re-typed into a JSON manifest, so a rare hanzi
  can't be silently mis-typed at upload — the CJK-safe path for Iron Law 2) and
  validates the headings. On UPDATE a `bodyFile` does a safe full-body replace
  (the file is the source of truth); inline body edits on update stay refused.
  Convention: `docs/session-journal/<sid>/<artifact>.md` — the /plan draft,
  co-located with the session journal (its `plan-path` helper prints that path).
  The same script also does: `set <db> <page-id> Prop=Val … --commit`
  (one-row property flip WITHOUT a manifest file — the common TaskList
  Status/Stage flip; same registry validation as `update`; multi_select takes
  comma-separated values); `filter <db> Prop=Val …` (read-query filter
  + ds id — see §Reading); `trash <page-id> --commit` (marker-guarded, close-out);
  `check <page-id> <text> --commit` (toggle one checklist box) + `append <page-id>`
  (block-level body append) — edits without a full re-send; `comment <page-id>
  <text> --commit` (post a comment, e.g. review findings); `schema --live [db]`
  (drift vs the registry).
- **`references/notion-io-subagent.md`** — most KB ops now stay inline (`ntn`
  reads return only properties; the builder's `--commit` returns only distilled
  results). Delegate to a disposable subagent only the bulk case: reading many
  full page **bodies** for synthesis. Holds the READ-BODIES and (large-batch)
  WRITE templates. See §Delegating heavy I/O.
- **`references/ntn.md`** — the transport layer: how to invoke the `ntn` binary
  (it's not on a non-interactive `PATH`), auth (saved login + headless token
  fallback), the **gotchas that fail silently** (`pages trash` needs `--yes`; the
  generated marker comes back backslash-escaped; file upload must be single-part;
  no batch create), and a command crib. Read it before driving `ntn` by hand or
  when a raw call misbehaves.

## Reading / querying the KB

Reads route through here too — same DB ids, same conventions. The Notion REST API
(via `ntn`) supports **server-side property filters + sorts**, so a read is one
command:

- **Inventory / filter a DB by property** (every TaskList row whose `Status` =
  Next, a feature's plan trail, the whole-board distribution) — one call:

  ```
  # build the filter from the registry (picks the right operator per type):
  notion-payload filter tasklist Status=Next
  # → prints the ds id + filter JSON + the ready ntn command, e.g.:
  ntn datasources query <ds> --filter '{"property":"Status","select":{"equals":"Next"}}' --json
  ```

  It returns only the matching rows' **properties** — no page-body fan-out. Use
  `--plain` for a quick human table instead of `--json`; `--sort '<prop> [asc|desc]'`,
  `--limit`, `--start-cursor` for ordering / paging. Multiple `Prop=Val` AND-compound.
  **Date properties** also take the comparison operators `<`, `<=`, `>`, `>=` and
  the literal `today` — e.g. `filter tasklist Status=Tracing "Check Date<=today"`
  builds the overdue-or-due list (`<today` = strictly overdue, `=today` = due today).
- **One known page** → `ntn pages get <id>` (frontmatter properties + Markdown
  body) for the body, or `ntn api v1/pages/<id>` for just the property JSON.
- **A DB's live schema** (property names + option vocab) →
  `ntn api v1/data_sources/<ds-id>`.

DB ids + their data-source ids live in `references/notion-kb.md`. `ntn` is
authenticated via the saved `ntn login` credentials (reused by same-user runs) and
the builder resolves the binary itself — but the binary is **not** on a
non-interactive `PATH`, and several `ntn` behaviours bite silently. Full auth /
binary-resolution / gotchas (single-part upload, `trash --yes`, marker escaping)
live in **`references/ntn.md`** — read it before driving `ntn` by hand.

Reading many full **bodies** for synthesis is the one case worth a disposable
subagent (§Delegating heavy I/O) — `ntn pages get` returns whole bodies.

Scope first (Iron Law 1): a broad read → inventory + present, don't guess.
**Picking the next task to work on** is the canonical case — TaskList `Status`
*is* the pickup-priority order: query the board (a `Status`-sorted query, or one
filtered query per bucket), then walk **`Next` → `Backlog` → `Deferred`** and
surface the highest-priority non-empty bucket as the candidate(s). `In Progress` is already-active work
(offer to *resume* it — never a fresh pickup); a `Deferred` candidate is parked
behind a `Trigger`, so confirm that condition has actually fired before
recommending it. `Tracing` is an ongoing-observation task, **not** a pickup
bucket — skip it in the walk; surface a Tracing task only when its `Check Date`
is due (`filter tasklist Status=Tracing "Check Date<=today"`), to review it
against its `Check Target`. If the chosen bucket holds more
than one task, present them and let the user choose — `Status` is the only
ranking key, so never silently pick one.

## Delegating heavy I/O to a disposable subagent

With `ntn`, reads return only **properties** (server-side filter) and the
builder's `--commit` returns only distilled results — both stay **inline**. The
one transaction still worth a disposable subagent (`general-purpose`,
`model: haiku`) is reading **many full page bodies** for synthesis (e.g. archiving
a feature → reading every plan's body): `ntn pages get` returns whole Markdown
bodies, which would otherwise linger in this context all session.

- **The contract is the point:** the subagent returns ONLY the distilled result
  (the notes, or URLs + verdict) — it never pastes a raw page body back. Pass a
  write a **manifest file PATH**, never the body inline.
- **Synthesis stays here.** Turn sources into clean rows / a manifest *before*
  you spawn — the subagent only reads, encodes, calls, and verifies; it does not
  judge.
- **The plan-cycle ledger stays here.** The subagent reports PASS with URLs;
  YOU (main tree) then run the matching `plan-cycle.sh` mirror (§Plan-cycle
  ledger). The subagent never touches the ledger.
- **Templates:** `references/notion-io-subagent.md` holds the ready READ-BODIES
  and (large-batch) WRITE prompts — fill in the page set / manifest path.

## Core principles

**Extraction-style, not a file mirror.** A KB holds evergreen, synthesized
truth a future (often non-engineer) reader browses — not a copy of the repo's
dated markdown. Synthesize the value (problem / approach / decisions /
outcome); never verbatim-dump, never append a "Source Archive" raw block (git
is the verbatim record). Collapse a revision trail into one current-state page
+ a few decision entries — not eleven dated rows. Only evergreen content
enters; process exhaust (review logs, superseded drafts, per-day revisions)
stays in git or is trashed.

**Link direction is repo → Notion only.** A repo doc may link to a Notion page;
a Notion page must not depend on repo paths the reader can't open. When you
remove a canonical doc that a *kept* repo doc referenced, leave the Notion URL
as the breadcrumb in the repo.

**Titles are human-readable Title Case, never slugs** —
`collection-viewer-sort-modes` → "Collection Viewer Sort Modes". The full rule
+ examples are in `references/notion-kb.md §Title convention`.

**Feature Area / Area = readable Title Case labels, one per `lib/features/`
folder** ("Cloud Sync", "Book Storage", "Reader", …; plus "Infra" /
"Growth (non-feature)") — the taxonomy mirrors `lib/features/`, the labels
read cleanly. Not ad-hoc tags, not raw folder slugs. Each DB carries its OWN
option vocabulary (Feature Archive's list ≠ TaskList's ≠ Decision Log's) — the
builder validates against the live one per DB, so a drifted label fails loudly
instead of silently minting a new option. Schemas in `references/notion-kb.md`.

**Build request bodies with the script.** Never hand-encode a Notion property map
— the encoding is non-obvious (dates as `{start,end}`, checkboxes as bools,
multi-select as `[{name}]`, relations as `[{id}]`, url props under the property's
literal name) and a silent mis-encode costs a failed write + a slow retry.
Synthesize clean rows, then run `notion-payload
<create|update> <manifest> --commit` — it validates, encodes, drives `ntn` per row
(create = POST properties + `ntn pages edit` body + verify every `## ` section
landed; update = PATCH properties), and prints the resulting URLs. **A non-zero
exit means a body did not land whole — re-write it; never mark `plan-cycle
uploaded` or trash a source off a failed verify.** A `⚠ … half-width punctuation`
line is a **warning, not a failure** — 繁體中文 prose wants `，。：；！？（）`
(`plan/founder-corrections.md` §Communication & scope); fix what it names in the bodyFile, but the
upload is not blocked and the exit code is unaffected. Run it without `--commit` first
to review the per-row plan.

## Iron Laws

1. **Confirm scope before touching anything.** If the user did not name a
   specific feature, produce a candidate inventory from the TaskList DB (which
   holds each feature's Product / Design / Engineering Plan rows + its `Stage`)
   and ask which are shipped / abandoned / superseded / in-flight. Never archive
   a feature whose cycle is not terminal.
2. **Push + verify before delete.** Create/update the Notion entry — the builder's
   `--commit` re-reads the page, confirms **every `## ` section arrived**, and
   exits non-zero if any did not (the marker alone proves nothing: it is
   *prepended*, so a write that drops the tail keeps it and reports ✓). Then
   re-read it via `ntn pages get` /
   `ntn datasources query`, confirm the synthesized content is present — only then
   `trash` the canonical repo docs. Never delete first. **For CJK-heavy content the
   verify is a character-level proofread against the source** — synthesis /
   re-authoring silently mis-types rare hanzi, so eyeball the Notion copy
   hanzi-by-hanzi vs the local before trashing it.
3. **Synthesize, never verbatim-dump.** Every page has the extracted sections;
   no raw-markdown Source Archive block.
4. **Titles are Title Case, never slugs.**
5. **Feature Area / Area = readable Title Case labels mirroring `lib/features/`
   folders** ("Cloud Sync", "Book Storage", …), not ad-hoc tags or raw slugs.
6. **Engineering ≠ PM corpus.** Engineering plans, test plans, and review logs
   stay out of the Notion PM corpus — inventory/archive them only on explicit
   request. Test plans + QA logs are trashed, never Notion'd.
7. **Never overwrite hand-maintained Notion pages.** A page without an
   `<!-- archivist-generated -->` marker is hand-authored — stop and report.
8. **The user feedback log is canonical in Notion.** Append new entries to the
   Notion page; never create a repo-side copy — two canonical copies is exactly
   the problem this shape avoids.
9. **Repo files: `guardrails` decides `trash` vs `rm`** — it denies whichever
   one this machine cannot use, so just delete. To remove a Notion page use
   `ntn pages trash <id> --yes`.
10. **Report Notion URLs** for every page created / updated, plus the removal
    manifest of repo files trashed.

## Default workflow (archive a feature)

1. Confirm scope (Iron Law 1). Broad request → inventory + ask.
2. Verify the cycle is terminal (`Stage` = Shipped, or the task reads
   abandoned/closed; not parked in a Security / Privacy / Review / QA loop).
   In-flight → stop and report; it is not archived.
3. Read every canonical source for the feature.
4. Synthesize the row(s) into a clean manifest — properties + body sections
   (Title Case names; Feature Area from the DB's own vocabulary). The builder
   owns the body skeleton + the `<!-- archivist-generated -->` marker; see
   `references/notion-kb.md` for conventions and `notion-payload
   schema <db>` for the exact fields.
5. Run `notion-payload create <manifest> --commit`
   (it creates each row via `ntn`, writes the body, and verifies). Stage flips /
   checklist property updates: `… update <manifest> --commit`.
6. The `--commit` run already verified each row; spot-check with `ntn datasources
   query` / `ntn pages get` if needed.
7. `trash` the canonical docs; leave a repo→Notion breadcrumb where a kept repo
   doc referenced them.
8. Report URLs + removal manifest.

## Plan-cycle ledger (mirror every /plan Notion write locally)

`/plan`'s upload obligation (its Iron Law 6) decays out of context over a long
cycle, so a deterministic Stop-hook gate (`plan-cycle`) enforces
it instead — but the hook can only see a **local ledger that mirrors the Notion
writes you make**. So whenever a write you perform is part of a `/plan` cycle,
record it with the matching one-liner **immediately after the write lands**. The
script is the single source of truth for the path (it resolves one shared ledger
in the main tree, so it works identically from a worktree); it **no-ops when no
cycle is active**, so these calls are safe to run unconditionally.

**Call it by bare name — `plan-cycle`, which the plugin puts on `PATH`.** Never
`bash <some>/plan-cycle.sh`: a project-relative path is not knowable from here
and the plugin does not install one, so such a call fails with
`No such file or directory` — which looks exactly like the harmless idle-cycle
no-op and leaves the gate with an empty ledger to check. **A `command not found`
here is not a no-op, it is the gate being off**: say so plainly in your report
rather than continuing as if the write were mirrored.

| The Notion write you just made | Mirror it with |
|---|---|
| Created the TaskList task (the `/plan` Step 2 anchor) | `plan-cycle start "<task-slug>" "<Task Name>"` |
| Flipped the task's **`Stage`** property | `plan-cycle enter "<Stage>"` (exact label: Product Plan / Design Plan / Translation / Engineering Plan / Security / Privacy / Implementation / Review / QA / Archived) |
| Created/updated a **Product / Engineering Plan** row (after the Iron-Law-2 verify confirms it), or published the design phase's contact sheet | `plan-cycle uploaded <pm\|designer\|engineer> <url>` — **the URL is required**: it is the proof Gate 1 trusts, and you already have it from the fetch-back (for `designer`, from the publish, and it is also what goes into the task's `Design Sheet`). No URL means the write didn't land, so redo the write instead of marking it done. |
| Closed out (Feature Archive verified + task row trashed) | `plan-cycle clear` |

Mark `uploaded` only **after** the verify (Iron Law 2) — a conservative
ledger never produces a false "all clear". A re-uploaded (rev'd) plan just runs
`uploaded` again — idempotent. This adds no judgment to your job: it is a
mechanical echo of the Notion op you already performed.

## Heavy batches

For a large multi-feature batch, work it in domain-sized chunks to keep each
focused — give each chunk the DB ids + the conventions + "extract only, report
URLs + removal manifest, DO NOT delete repo files" so the irreversible removal
stays a single confirmed step. Each chunk still runs through the builder in ONE
`--commit` pass per DB (the builder loops its rows), and reports URLs + the
removal manifest.

## Anti-patterns you refuse

- Verbatim-dumping raw markdown / appending a "Source Archive" block.
- Hand-encoding a property map, or hand-driving `ntn` per row, instead of running `notion-payload … --commit` (silent date / checkbox / multi-select / relation mis-encodes).
- Re-typing a CJK-heavy body inline into the manifest (or round-tripping it through `ntn pages get`→`edit`) instead of authoring it ONCE in a `bodyFile` and uploading byte-exact — both invite silent hanzi / markdown-escape drift.
- Reaching for read scaffolding (semantic search saturation, a local property filter, a mirror cache) instead of one `ntn datasources query --filter`.
- Slug titles (`collection-viewer-sort-modes`) instead of readable ones.
- Ad-hoc Feature Area tags, or raw folder slugs (`cloud_sync`), instead of readable Title Case mirroring `lib/features/`.
- Deleting a canonical doc before its Notion entry is re-read-verified (`ntn pages get` / `datasources query`).
- Archiving an in-flight cycle, or mixing engineering artifacts into the PM corpus.
- Overwriting a hand-authored (un-marked) Notion page.
- Duplicating a shipped feature into the TaskList instead of linking Feature Archive.
- Inventing new Notion DBs/structure without confirming scope.

## Tone

Mechanical, careful, concise. Confirm scope → synthesize → push → verify →
remove → report. Push back only when an Iron Law would be violated.
