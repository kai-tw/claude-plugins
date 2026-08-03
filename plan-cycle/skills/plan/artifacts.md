# Artifact Locations and Citation

Read when the location for a plan / spec / engineering plan is
ambiguous, or when writing the PR / commit citation block.

Planning artifacts live in the project's **Notion KB**, linked to one
**TaskList task** per feature. Each project names its own workspace and owns
its DB ids + schema — they live in that project's `archivist` reference, the
single source of truth. The skills write Notion by invoking the `archivist`
skill; they never hard-code a workspace or DB id.

## Product plans — Notion **Product Plan DB**

A product plan is a row in the Product Plan DB, related to the feature's
TaskList task via the **Task** relation. the PM role authors it.

- **Name** — Title Case, e.g. "Cloud Sync — Product Plan".
- **Type** — `one-pager` / `prd` / `prfaq` / `strategy` / `roadmap` /
  `opportunity-tree` / `discovery-brief`.
- One row per feature; **revisions update the same row** (revision
  history inside the body). The Task relation is the join — a task shows
  its linked Product Plan.
- The **row body** is structured as the `product-plan` body sections for
  the chosen Type — run
  `node .claude/skills/archivist/scripts/notion_payload.mjs hints product-plan <type>`
  for the section questionnaire.

## Design specs — Notion **Design Plan DB**

A design spec is a row in the Design Plan DB, related to the same
TaskList task. the designer role authors it.

- **Name** — "<Feature> — Design Plan". **Mode** — `full` / `delta` /
  `single-breakpoint`.
- One row per feature, linked to the same task as the product plan;
  revisions update the same row.
- The **row body** is structured as the `design-plan` body sections — run
  `node .claude/skills/archivist/scripts/notion_payload.mjs hints design-plan`
  for the section questionnaire (descriptions, hints per section).

## Engineering plans — Notion **Engineering Plan DB**

An engineering plan is a row in the Engineering Plan DB, related to the
same TaskList task via the **Task** relation (back-ref "Engineering
Plans"). the engineer role authors it.

- One row per feature, linked to the same task as the product + design
  plans; revisions update the same row.
- The **row body** is structured as the `engineering-plan` body sections
  defined in `.claude/skills/archivist/scripts/notion_payload.mjs` — run
  `node .claude/skills/archivist/scripts/notion_payload.mjs hints engineering-plan`
  to print the section questionnaire. Paired with a TaskCreate task list
  in the conversation (row body canonical for content, task list
  canonical for live status).

## Citation in the diff

The PR description or the initial feature commit message cites the
**Notion task URL**, which reaches all three linked plan rows (Product
Plan + Design Plan + Engineering Plan). Skip the design leg for non-UI
work:

```
Implements <Notion task URL>   (Product Plan + Design Plan + Engineering Plan rows)
```

Each subsequent commit landing a slice may cite only the Notion task URL —
but the initial feature commit (or the PR body) carries the full trail.
The citation is what makes the trail recoverable from `git log` + the
task.

## Plan-spec language

Product plan, design plan, and engineering plan **row bodies** default
to 繁體中文 (Taiwan terminology) for prose, with English reserved for
technical acronyms, product / technology names, cross-reference
anchors, verbatim quoted data, CLI / code
blocks, and metric values + units. The full rule lives in the
**§Language section of the PM role, the designer role, and the engineer role** — each
tailored to its own artifact. There is no shared rule file.

Per the "No repo pointers" convention in
`.claude/skills/archivist/references/notion-kb.md`, repo pointers
(file paths, class / method names, line numbers) are **scrubbed from
bodies entirely** — they are not "kept in English", they are removed.
**The Engineering Plan DB is exempt** (see that section's carve-out): its
schema mandates the pointers, so scrubbing them would delete the content
rather than the navigation. Product and design plans are not exempt.

## Notion properties, not body fields

Date, Status, Type / Mode, the Task + Feature Archive relations, and
Author are **Notion DB properties + relations** on the plan row — never
repeated in the row body. The body starts at the actual content (e.g.
`## Problem` / `## Engineering review`). Do not
open a body with a `**Status:** …` / `**Author:** …` / `**Date:** …` /
`**Source plan:** …` / `**Source spec:** …` header block.

## Out of scope

A product plan is **not** a vehicle for unrelated cleanup. A one-pager
about search does not authorize refactoring the library. Out-of-scope
cleanup needs its own plan or a separate refactor PR.

Likewise, a design spec is not a vehicle for unrelated visual rework. A
spec for a new settings screen does not authorize restyling the library.
Visual debt cleanup needs its own spec or a dedicated visual-polish PR.

If a follow-up surfaces during plan / spec authoring that is explicitly
out of scope, route it to the feature's **TaskList task** (Status
`Deferred` + a Trigger) — the TaskList DB is the backlog. See
`todo-backlog.md`.
