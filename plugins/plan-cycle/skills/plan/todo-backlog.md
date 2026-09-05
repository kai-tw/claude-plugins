# Deferred Work — the Notion **TaskList DB**

Read when a follow-up surfaces during plan / spec / engineering-plan
authoring (or mid-implementation) that is explicitly **out of scope**
for the current cycle, or when a plan amendment introduces new deferred
items.

The backlog is the Notion **TaskList DB** (see
`${CLAUDE_PLUGIN_ROOT}/skills/archivist/references/notion-kb.md`): a deferred item is a
TaskList task with Status `Deferred` + a **Trigger** (the condition that
should fire it). Invoke the `archivist` skill to add/update it. Plans do
not maintain their own `§Follow-ups` section.

> **Legacy:** `docs/TODO.md` was the previous file-based backlog,
> **removed 2026-06-08**. The Notion **TaskList DB** is the sole
> backlog now; the old file survives only in `git log` for
> historical context.

## Why centralize, not per-plan

A `§Follow-ups` block inside each plan creates two problems:

1. **Discoverability.** A future session looking at "what's pending
   across the project?" has to open every plan to find buried
   follow-up lists. They never appear in a single place.
2. **Lifecycle drift.** Each plan's `§Follow-ups` is frozen at
   plan-write time. Trigger signals, priorities, and status updates
   have nowhere to live without re-revving the plan.

The **Notion TaskList DB** gives one board to scan, a live
Status/Trigger per task without re-revving plans, and
filter-by-Area so all of a feature's deferred work surfaces
together.

## Format

Each backlog entry is a **TaskList task** (Status `Deferred` + a
Trigger), authored via the **`archivist` skill** — skills never
write Notion directly. The task carries:

- **Name** — what the work is, as a short readable title.
- **Status** `Deferred`.
- **Trigger** — the condition that would promote it to active
  planning (user-feedback class, instrumentation threshold,
  dependency landing, plugin upgrade, etc.).
- **Area** — the feature, Title Case mirroring `lib/features/`,
  so the task filters under its feature's deferred work.
- **Body** — 2–4 sentences in any natural-prose order: why it was
  deferred (one-line rationale tied to the source plan's context),
  and a reference back to the source plan.

Schema source of truth:
`${CLAUDE_PLUGIN_ROOT}/skills/archivist/references/notion-kb.md` §TaskList.

## When the rule applies

When a plan's cycle ships (or terminates) and items remain
deferred:

1. Add each deferred item as a **TaskList task** (Status
   `Deferred` + a Trigger, Area = the feature), via the
   **`archivist` skill**.
2. Cite the source plan in the task body.
3. The plan documents what's in scope (`§Scope`) and what's
   explicitly **not** in scope (`§Non-goals` / `§Out of scope`) —
   that's the decision artifact. It does **not** maintain a
   forward-looking `§Follow-ups` section.

## Promotion to a real plan

When a backlog item is selected for active work, the TaskList
task's **Status** moves `Deferred` → `In Progress` / `Next`, and
`/plan` links its plan rows (Product Plan / Design Plan /
Engineering Plan) to the task as they're authored.

This preserves the lineage — the same task carries its Trigger
history and its plan relations, so the backlog → plan transition
stays on one board.

**A sibling task from a PM split** (`pm/SKILL.md` §Split into sibling tasks)
is the mechanical case of "dependency landing": its Trigger names the
specific sibling it waits on, and `/plan` checks it automatically at that
sibling's close-out (`plan/SKILL.md` §Step 6.4a) — the one Trigger case that
doesn't wait on the founder noticing it by hand.

## Migration of existing plans

Plans authored before this rule was codified may still have a
`§Follow-ups` section. They are not retroactively migrated
wholesale. But: when a plan is amended (a new `revN` lands), the
amendment **must open a TaskList task** (Status `Deferred` + a
Trigger) for any newly-added follow-up instead of appending to
`§Follow-ups`. Pre-existing entries can be migrated in the same
edit if the touch is already there; otherwise leave them in place
— the plan remains an honest record of "this is what was deferred
at that time".

## Exemptions

Hyper-localized tech-debt notes that exist purely as inline code
TODO comments (`// TODO(short): ...`) are not subject to this rule
— those are short-lived implementation hints attached to specific
lines, not deferred features worth tracking at the project level.
