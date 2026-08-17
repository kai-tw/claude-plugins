# Archivist — Notion KB reference

Detailed lookup for the `/archivist` skill: workspace ids, per-database
schemas, page-content formats, and the synthesis + title conventions.
`SKILL.md` holds the principles; this file holds the structure you write into.
The request-body encoding + the synthesis body skeleton are owned by
`notion-payload` — run `notion-payload schema` to
print every builder-managed DB's exact fields. All Notion I/O goes through the
official `ntn` CLI (`ntn datasources query` to read, the builder's `--commit` to
write); `SKILL.md §Reading` + `§Build request bodies` hold the flow.

## Contents

- [Notion Workspace Layout](#notion-workspace-layout-canonical)
- [Title convention](#title-convention)
- [Synthesis — what to extract per source type](#synthesis--what-to-extract-per-source-type)
- [Request bodies — use the builder](#request-bodies--use-the-builder-never-hand-encode)
- [Feature Archive](#feature-archive--schema--format)
- [Feature KB](#feature-kb--schema--format)
- [Decision Log](#decision-log--schema--format)
- [TaskList](#tasklist--schema--format)
- [Broad reference material → KB pages](#broad-reference-material--kb-pages)

## Notion Workspace Layout (canonical)

Every project keeps its own KB: one **root page** holding the databases below as
direct children. **No id is written down anywhere in this plugin.** The builder
resolves them at startup from the root page id, matching each database by its
title, so a project configures exactly one value and eight ids cannot silently
rot out of sync.

The project states its root page id in its own `CLAUDE.md`; pass it through on
every call:

```
node <plugin>/skills/archivist/scripts/notion_payload.mjs <cmd> … --root <page-id>
```

Omit `--root` and the builder aborts. That is deliberate: a default root would
not produce a harmless error, it would write this project's plans into another
project's workspace.

| Database (title must match exactly) | Holds |
|---|---|
| Feature Archive | One row per **shipped / abandoned / superseded** feature **cycle** (immutable history) |
| Feature KB | One **living** row per feature — its current mechanism; the synthesis counterpart to Feature Archive |
| Decision Log | One row per notable cross-feature / likely-to-resurface **decision** (ADR) |
| TaskList | One row per **in-flight / deferred** task; each task page carries its own Product Plan + Design Plan + Engineering Plan |
| Product Plan | One row per product plan doc; relates to TaskList via **Task** property (back-ref on TaskList: **Product Plans**) |
| Design Plan | One row per design spec doc; relates to TaskList via **Task** property (back-ref on TaskList: **Design Plans**) |
| Engineering Plan | One row per engineering plan doc; relates to TaskList via **Task** property (back-ref on TaskList: **Engineering Plans**) |
| Release Log | One row per app release (Version · Type · Status · Platform · Release Date · Highlights) |
| Analytics Event Catalog | One row per analytics event emitted by the app (Event · Feature · Status · Kind · Weekly Review · Payload · Rationale) |

A project needs only the databases it uses. Any absent from the root are dropped
from the registry, so `unknown db "x". Valid: …` lists exactly what that project
has — an accurate error rather than a promise the workspace cannot keep.

**Which vocabularies are yours.** `Status` and `Stage` are the plan cycle's own
contract and stay fixed in the builder's registry — a typo fails locally, before
any network call. `Area` / `Feature Area` / `Feature` mirror each project's
modules, so those are read live from the database itself. Run
`schema --live [db] --root <id>` to check the two halves still agree; it reports
every option present on one side and not the other.

The KB is extraction-style, not a file dump — never create a page that
verbatim-mirrors the repo.

## No repo pointers

Notion entries describe **intent, behavior, decisions, and rationale only**.
They must NOT contain:

- File paths of any kind (`lib/…`, `docs/…`, `tool/…`, `test/…`, `ios/…`,
  `android/…`, `renderer/…`, or any subfolder thereof)
- Bare filenames or extensions (`.dart`, `.kt`, `.swift`, `.md`, `foo.dart`,
  `bar.md`)
- Line-number references (`:1145`, `line 42`)
- Commit hashes (short or long)
- Navigational pointer lines (`Source plan: docs/…`, `Source spec: …`,
  `see docs/…`, `Parent plan: …`, `Full plan source: …`)

The KB is self-contained knowledge — repo navigation lives in the repo and
git, not in the KB.

**One exemption: the Engineering Plan DB.** Its rows are read by engineers
and reviewers, not browsed as knowledge, and its own body schema mandates
the pointers — §Classes is a file inventory (`File (NEW/MOD/DEL)` is a
column), §Data flow's graph nodes are `Class.method`, §Error policy's evidence
is `file:symbol`. Scrubbing them there would delete the section's content,
not its navigation. The exemption covers **that DB only** — Feature
Archive, Decision Log, TaskList, Product Plan, and Design Plan rows are
bound by the list above, because their reader is the founder browsing
intent, not an engineer following a trail.

**When a path or symbol carried meaning, restate the concept in plain
language.** Examples:

| Instead of… | Write… |
|---|---|
| `SyncConflictResolveUseCase` in `lib/features/cloud_sync/…` | the cloud-sync conflict-resolution use case |
| Source plan: `docs/engineering-plans/…/foo.md` | *(omit — the Notion row IS the plan record)* |
| commits `51929e4a` → `8492a7e2` | shipped May 2026 |
| `ios/Runner/AppDelegate.swift` | the iOS app entry point |

**Keep:** feature/concept names, engineering decisions, data-flow logic
described conceptually, trade-offs, risks, outcomes, dates, and — where the
package or framework name IS the decision (e.g. choosing `google_mlkit_translation`
over a hand-rolled bridge) — the technology label in prose (not as a code path).

## Title convention

Every page / row `Name` is **Title Case, readable by a non-engineer** — never a
kebab-case slug, never a filename.

- Feature → its product name: `collection-viewer-sort-modes` →
  **"Collection Viewer Sort Modes"**; `toc-progress-exposure` →
  **"TOC Progress Exposure"**; `file-association-refactor` →
  **"File Association Refactor"**; `cloud-sync` → **"Cloud Sync (v1–v4)"**;
  `acquisition` → **"Acquisition (Diagnostic)"**.
- Decision → a readable sentence-fragment (sentence case, not all-caps Title
  Case): `on-device-only-translation-no-cloud-fallback` →
  **"On-device-only translation (no cloud fallback)"**.
- Keep load-bearing acronyms (TOC, UI, HLC, OAuth, PDF, MOBI) and code literals
  (`entry.author`, `_mapResult`, `ReaderScaffold.build`) verbatim; de-slug
  everything else. Add a short qualifier only where it genuinely aids a
  non-engineer.

The matching repo slug, when useful for grep, goes in a property/text field —
never in the title.

## Synthesis — what to extract per source type

Extract the signal; do not paste raw markdown. Synthesis sections ARE the
value-add.

- **Product plans → Product Decisions / Problem / Final Approach.** Feature
  motivation (why, one sentence); scope decisions (in vs out); key product
  calls (pivots, trade-offs, rulings); items deferred to future cycles.
- **Design specs → Design Decisions.** UX / visual patterns introduced or
  changed; accessibility / i18n choices; deferred design items + rationale.
- **Security reviews → Security Notes.** Gate decision (approved / approved
  with conditions / blocked); findings (title, severity, status); key
  remediations; accepted open risk. Set the row's Security Review checkbox.

## Request bodies — use the builder, never hand-encode

`notion-payload` is the source of truth for how a synthesized row
becomes a Notion request — and (with `--commit`) it drives `ntn` to write it. It
emits standard Notion REST property JSON and validates the option vocabulary per
DB (each DB has its OWN list; a drifted label fails loudly):

- dates → `{ "date": { "start": …, "end": null } }`
- checkbox → `{ "checkbox": true|false }`
- multi-select → `{ "multi_select": [ { "name": … } ] }`; relation → `{ "relation": [ { "id": … } ] }`
- url-type props → `{ "url": … }` under the property's LITERAL name (one prop is
  live-named `userDefined:Linked Archive`, an MCP-era artifact; the builder maps
  the friendly `Linked Archive` key onto it via `notionName`)
- title / text → `{ "title" | "rich_text": [ { "text": { "content": … } } ] }`
- the page body stays Markdown (written via `ntn pages edit`); the page title
  lives only in the title property, never as an `# H1` in the body

Feed it `{ "db": "<key>", "rows": [ … ] }`. Without `--commit` it prints the per-row
plan (api body + body Markdown) for review; with `--commit` it creates each page
(`ntn api v1/pages` POST) + writes the body (`ntn pages edit`) + verifies, or in
`update` mode PATCHes properties (`ntn api v1/pages/<id>`), one row at a time.
`notion-payload schema [db]` prints the
field contract for any DB; the eight keys are `feature-archive`, `decision-log`,
`tasklist`, `product-plan`, `design-plan`, `engineering-plan`, `release-log`,
`analytics-catalog`. **Feature KB is not among them** — it has no builder schema;
its row + hand-synthesized body are created directly (`ntn pages create --parent
data-source:<id>` for the Markdown body, `ntn api v1/pages` for properties), and
its two live views via `ntn api v1/views` (see §Feature KB; run `ntn api v1/views
--docs` for the body shape).

## Feature Archive — schema + format

Properties: **Name** (title — Title Case) · **Status** (Shipped / Abandoned /
Superseded) · **Feature Area** (multi-select, Title Case labels mirroring
`lib/features/`) · **Shipped Date** (date) · **Security Review** (checkbox). The
exact, current Feature Area vocabulary is whatever `node
notion-payload schema feature-archive` prints — and it is *narrower*
than TaskList's Area (no "Preference"), which is exactly why the
builder validates per DB.

Body sections, assembled by the builder in this order, passed as row fields:
Overview → Problem → Final Approach → Key Decisions → Deferred Items (optional,
omitted when empty). The builder inserts the `<!-- archivist-generated -->`
marker. There is no "Commit Reference" section — commit hashes are repo pointers
barred by §No repo pointers; the Shipped Date property carries the "when".
Feature Archive is the **immutable per-cycle history**; the feature's *current*
mechanism lives in its **Feature KB** entry (see §Feature KB), which the archive
is never back-copied into.

## Decision Log — schema + format

Properties: **Name** (title — readable sentence-fragment) · **Area**
(multi-select: Reader / Library / i18n / Auth / Sync / Infra / Other — note this
is an OLDER, coarser taxonomy, NOT the `lib/features/` mirror) · **Status**
(Active / Superseded / Deferred) · **Feature** (text — the feature slug, for
filtering) · **Decided** (date).

Body sections, assembled by the builder: Context → Decision → Consequence.
Create an entry only for a decision that is cross-feature or likely to resurface
— not every trade-off. Join to Feature Archive via the `Feature` slug text.

## TaskList — schema + format

Properties: **Name** (title — readable) · **Status** (select: In Progress ·
Next · Backlog · Deferred · Tracing — *Tracing* = an ongoing-observation task
(e.g. a growth / content-marketing initiative measured over weeks) that is
neither actively worked nor parked, but periodically checked) · **Stage** (select:
Product Plan · Design Plan · Translation · Engineering Plan · Security ·
Privacy · Implementation · Review · QA · Shipped · Archived · Blocked — the
lifecycle phase, advanced by the `/plan` launcher after each phase; see
§Progress tracking) · **Area** (multi-select —
Title Case labels mirroring `lib/features/`; its own vocabulary, *wider* than
Feature Archive's Feature Area — it adds "Preference" — which is why
the builder validates per DB) · **Trigger** (text —
for Deferred items, the condition that should fire them) · **Linked Archive**
(url type — to the Feature Archive row, for shipped-adjacent items) ·
**GitHub Issue** (url type — the cycle's git-side anchor, opened alongside the
task by `/plan` Step 2 whenever the cycle will produce a PR, and closed by that
PR's `Fixes #N`; empty for plan-only and Tracing rows) ·
**Check Date** (date —
檢核日, for Tracing items: the next date to observe/review the task) ·
**Check Target** (text — 檢核目標, for Tracing items: the goal or metric to
evaluate against on the Check Date).

The TaskList is the **"what's not done yet"** board: it holds in-flight +
deferred work only. **Shipped items are NOT duplicated here** — they live in
Feature Archive; link via Linked Archive if a pointer helps, otherwise omit.

**Tracing tasks** (`Status` = Tracing) are the exception to the pickup-priority
walk: they are neither actively worked (`In Progress`) nor a one-shot backlog
item, but an **ongoing-observation** thread revisited on a cadence — a growth /
content-marketing initiative, a metric to watch, a post-ship soak. They carry
**Check Date** (檢核日 — when to next look) + **Check Target** (檢核目標 — what
outcome to check for). On the Check Date, review against the target, then either
push the Check Date forward (still tracking) or graduate the task into the normal
`Next`/`Backlog` flow (act on it) or close it out. They are skipped by the
`Next → Backlog → Deferred` pickup walk — surface a Tracing task only when its
Check Date is due.

**Each task links to its plans via relation — not inline sections.** A task's
product plan, design plan, and engineering plan each live as a row in the
**Product Plan DB** / **Design Plan DB** / **Engineering Plan DB** (see below),
related to the task via the **Task** relation. The synced back-references on
TaskList — **Product Plans** / **Design Plans** / **Engineering Plans** —
surface a task's full plan trail on the task page.

The planning flow: **`/plan` creates the task** → the PM role adds the Product Plan
row (linked) → the designer role adds the Design Plan row (linked) → the engineer role adds
the Engineering Plan row (linked) → `/plan` gates on all three. All three plan
types are Notion rows related to the one task — including in-flight / in-progress
work; there are no local plan files.

### Progress tracking — Stage + Implementation checklist

The **Stage** property is the at-a-glance "where is this now". The **`/plan`
launcher advances Stage when each phase finishes**, by invoking the `archivist`
skill to set it on the task:

| Phase / event | sets Stage → |
|---|---|
| `/plan` creates the task | **Product Plan** |
| PM plan finalized | **Design Plan** (if UI) / **Translation** (copy, non-UI) / **Engineering Plan** |
| designer plan finalized | **Translation** (if copy) / **Engineering Plan** |
| translator phase finalized | **Engineering Plan** |
| engineer plan finalized + task list approved | **Implementation** |
| in a security / privacy review loop (cross-cutting) | **Security** / **Privacy** |
| implementation + code review | **Review** |
| QA phase (tests authored) | **QA** |
| close-out: Feature Archive created + verified | **Shipped**, then the task row is **trashed** |

`Blocked` is set by hand when the work stalls on an external dependency.
`Security` / `Privacy` are cross-cutting review loops that run at the PM,
engineer, and code points — Stage shows them only while the task is actively
parked in that review loop.

### Close-out / archive flow

When a task is complete, the `/plan` launcher (or a manual archive request)
invokes the `archivist` skill to:

1. **Create the Feature Archive row** — a synthesis (problem / final approach /
   key decisions / outcome), never a verbatim dump (see §Feature Archive). Tag its
   **Feature Area** correctly (the feature(s) it belongs to — multi-select for a
   cross-cutting cycle); the feature's Feature KB auto-views key on this tag.
2. **Refresh the feature's Feature KB entry — only if the cycle materially changed
   how the feature works.** Most bug-fix cycles do not; the Feature KB *Cycle
   History* auto-view already surfaces the new cycle with no edit. When the
   mechanism did change, update the affected body section in place and bump
   **Last Reviewed**. Feature KB is the living current-state synthesis; Feature
   Archive is the immutable history — **never batch-copy Archive into KB** (see
   §Feature KB). Event-driven on material change, not a periodic bulk sync.
3. **Trash the task row** — once the Feature Archive row above is created **and
   verified** (Iron Law 2), trash the task:
   `notion-payload trash <task-id> --commit`
   (marker-guarded — it refuses a page lacking the `<!-- archivist-generated -->`
   marker). The plan rows (Product / Design / Engineering Plan) are **kept** as the
   detailed record — the Engineering Plan re-points to the Feature Archive row, and
   the Product / Design `Task` relation simply goes empty (cosmetic). `Stage =
   Archived` is a **manual-only** label for a soft park, never the close signal.
4. **Report to the user** the Feature Archive URL, that the task row was trashed,
   and any remaining local drafts safe to delete.

The **Implementation checklist** lives in the task PAGE BODY under a
`## Implementation` heading — one `- [ ]` line per engineering phase / task,
**mirrored from the engineer role's TaskCreate task list** when that list is
approved. As each phase lands (a commit), its box is ticked block-level via
`notion-payload check <task-id> "<phase text>" --commit`
(toggles the single `to_do`, no full-body re-send) — so the task reads
"Phase A ✓ · Phase B in progress · …" at a glance. the engineer role's close-out
does the final check and flips Stage to **Review**.

## Feature KB — schema + format

The **living current-state** counterpart to Feature Archive. One row per
`lib/features/` feature; the row body answers "how does this feature work
**now**", refreshed in place — never a new row per cycle.

Properties: **Name** (title — the feature, e.g. "Cloud Sync") · **Status**
(select: Active / Deprecated / Planned) · **Domain** (select: Reading /
Library / Sync & Storage / Discovery / Infra — for view grouping) ·
**Last Reviewed** (date — freshness of the mechanism prose).

Body sections (hand-synthesized prose, founder-facing, **no repo pointers**):
**Purpose** → **Current Mechanism** → **Key Contracts / Invariants** →
**State Ownership** → **What It's NOT**. Ground them in the feature's
`lib/features/<x>/CLAUDE.md` (translate code-level → product-mechanism level).

**No manual relation to Archive / TaskList.** Each entry embeds two **filtered
live views** (zero ongoing maintenance), created via `ntn api v1/views` with the
entry as the parent (run `ntn api v1/views --docs` for the exact body shape):

- *Active Work* — TaskList, `FILTER "Area" = "<feature>"`.
- *Cycle History* — Feature Archive, `FILTER "Feature Area" = "<feature>"`,
  `SORT BY "Shipped Date" DESC`.

The `=` filter on a multi-select compiles to **contains**, so a cross-cutting
cycle tagged with several features shows under each. The views auto-populate
from the existing Area / Feature Area tag — a cycle appears here the moment it
is archived **with the right tag**, no linking. Keeping that tag correct at
archive time is the only upkeep.

Relationship to Feature Archive: Archive = immutable per-cycle **history**
(evidence); Feature KB = living **synthesis** of current state. Never batch-copy
Archive into KB — refresh the KB prose only when a cycle materially changes the
mechanism (see §Close-out / archive flow).

## Product Plan DB — schema + format

Properties: **Name** (title — Title Case, e.g. "App Typography — Product Plan") ·
**Status** (select: Draft · Approved · Superseded) · **Type** (select: one-pager ·
prd · prfaq · strategy · roadmap · opportunity-tree · discovery-brief) ·
**Task** (relation → TaskList, back-ref "Product Plans") · **Date** (date).

Relation property on this DB is **Task**; the synced back-reference on TaskList
is **Product Plans**. One row per product plan document. Title convention:
"`<Feature / Initiative> — Product Plan`", e.g. "Conflict Resolution — Product Plan".
The **row body** is the product plan, structured by Type — run
`notion-payload hints product-plan <type>` for the questionnaire.

## Design Plan DB — schema + format

Properties: **Name** (title — Title Case, e.g. "App Typography — Design Plan") ·
**Status** (select: Draft · Approved · Superseded) · **Mode** (select: full ·
delta · single-breakpoint) · **Task** (relation → TaskList, back-ref "Design Plans") ·
**Date** (date).

Relation property on this DB is **Task**; the synced back-reference on TaskList
is **Design Plans**. One row per design spec document. Title convention:
"`<Feature / Initiative> — Design Plan`", e.g. "Conflict Resolution — Design Plan".
The **row body** is the design spec, structured as the `design-plan` body sections — run
`notion-payload hints design-plan` for the questionnaire.
Its last section, **`## Renders`** (kind `images`), embeds the Phase-7 renders of
the shipped widgets: set the row's `Renders` field to the `build/design-mockups/<slug>/`
directory (or an explicit path array); on `… create … --commit` the builder uploads
every PNG (single-part file upload) and appends them as captioned image blocks
(caption derived from the `screen__size__state__theme__locale` filename).

## Engineering Plan DB — schema + format

Properties: **Name** (title — Title Case, e.g. "App Typography — Engineering Plan") ·
**Status** (select: Draft · In Progress · Shipped · Superseded · Approved) ·
**Task** (relation → TaskList, back-ref "Engineering Plans") ·
**Feature Archive** (relation → Feature Archive DB) · **Date** (date).

Relation properties: **Task** (in-flight plans link here; synced back-reference on
TaskList is **Engineering Plans**) and **Feature Archive** (shipped plans link to
their archived feature row). One row per engineering plan document. Title convention:
"`<Feature / Initiative> — Engineering Plan`", e.g. "Conflict Resolution — Engineering Plan".
The engineer role is the natural producer — one row per approved engineering plan,
linked to its TaskList task. The **row body** is the engineering plan, structured
as the `engineering-plan` body sections — run
`notion-payload hints engineering-plan` for the questionnaire.

## 版本紀錄 (Release Log) — schema

The founder's release log — one row per app release. Properties: **Version**
(title) · **Type** (select: Major · Minor · Patch · Hotfix) · **Status**
(select: In Dev · RC · Released · Yanked) · **Platform** (multi-select:
Android · iOS · TestFlight) · **Release Date** (date) · **Highlights** (text).
It is a living operational log (founder-maintained; the `/release` skill is the
natural producer — one row per shipped version), **not** synthesized KB content.

## Broad reference material → KB pages or databases

Cross-cutting catalogs / schemas with no single feature owner land as
standalone **pages** under the root (mark them `<!-- archivist-generated -->`)
or as **databases** when the data is tabular and benefits from filtering /
grouping (e.g. the Analytics Event Catalog DB — one row per event, grouped
by Feature, with Status · Kind · Weekly Review properties that make the
catalog actionable rather than just readable).
