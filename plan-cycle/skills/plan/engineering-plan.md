# Engineering Plan — Gate-Side Required Contents

`Read` this file in Phase 4 of the `/plan` skill to know what an
approved engineering plan must contain. The gate verifies the
plan's existence and contents; **authoring** lives in the engineer role (`${CLAUDE_PLUGIN_ROOT}/skills/engineer/SKILL.md`), which
this file mirrors at the gate-side level.

The engineering plan converts product and design artifacts into
concrete implementation decisions. Without it, architectural
choices get made under typing pressure mid-diff, the first
reviewer of those choices is `git diff`, and the user has no
surface to push back on engineering trade-offs that change the
cost of the feature.

## Two parallel artifacts

The engineering plan exists in two places at once:

1. **Engineering Plan DB row** in the Notion KB — canonical for
   content. The row relates to the feature's TaskList task via the
   **Task** relation (back-ref "Engineering Plans") and its **body**
   is structured as the `engineering-plan` body sections — run
   `notion-payload hints engineering-plan`
   for the section questionnaire (description, hints, criteria per section).
2. **TaskCreate task list** in the conversation — canonical for
   live status. Tasks 1..N mirror the plan's `## Tasks` list, with
   task 1 being the engineering review itself.

At plan creation both are seeded from the same content by
the engineer role. **Status lives only in TaskCreate** (plus the Notion
task's `## Implementation` mirror for founder visibility) — the plan's
`## Tasks` is a plain list of what was planned and carries no checkboxes,
because a plan re-uploaded only on a rev cannot stay honest about progress.

## Required contents

The gate verifies the engineering plan covers, at a minimum:

- **Engineering review of the product plan and design spec** —
  what is internally consistent, what is ambiguous, what
  conflicts with existing constraints, what has been silently
  pushed onto engineering.
- **Affected layers and modules** — concrete file / package /
  feature paths that change, are added, or are removed.
- **Class / interface / data-shape sketch** — names and roles of
  new classes, new fields on existing entities, new use cases,
  new exception classes. Conformance with `architecture.md` and
  `naming.md` + `error-handling.md` noted per
  affected module.
- **Data flow** — sequence of who-calls-whom across layers for
  each user-facing scenario named in the product plan.
- **Migration / backward compat** — impact on existing state,
  persisted data, in-flight users, and pre-existing callers of
  any API being changed.
- **Testing strategy** — what is unit-tested, what needs
  integration coverage, what relies on manual QA, and what test
  seams must exist before the first line of production code is
  written. Per `/qa` ownership the test code itself is
  authored under `/qa`; the engineering plan only
  names the seams and coverage targets.
- **Risk table** — engineering risks (not product risks):
  library surprises, platform divergence, performance ceilings,
  race conditions, ordering hazards. With named mitigations.
- **Sequencing** — phased rollout if applicable. Pre-phase
  audit / verification tasks for risky phases.

A plan missing any of the above is **incomplete** and the gate
routes the user back to the engineer role for the missing section.
The plan carries **no** `## Memory Audit` section — grading is external
(`blueprint-reviewer` for judgment, `engineer/scripts/plan_lint.sh` for the
mechanical comparisons), not a section the author writes.

## Approval gate

After the engineer role seeds the TaskCreate task list, it presents a
short summary in chat and explicitly requests approval before
code is written. The gate's job is to **verify the user did
approve** — not to re-request approval itself.

Do not treat "looks good" or "ok" on a one-line summary as
approval — the user must approve the task list **as enumerated**.
Approval is sticky: subsequent implementation steps run against
the approved list.

## Divergence

If during implementation an engineering decision in the task
list turns out wrong, the gate does **not** rewrite the plan —
it routes back to the engineer role Phase 11 (mid-flow divergence),
which updates the affected tasks, mirrors the change into the
plan's revision history, and re-requests user approval for
the delta.

Do not silently choose a different architecture mid-diff. See
`divergence.md` for the full procedure.

## Language

The engineering plan row body defaults to 繁體中文 (Taiwan terminology)
prose, with English reserved for technical acronyms, product /
technology names, and cross-reference anchors — the same discipline as
product plans and design specs. The full, artifact-tailored rule lives
in the **§Language section of the engineer role** (and its siblings in the PM role
and the designer role); there is no shared rule file. Per the "No repo
pointers" convention, file paths / class / method names are scrubbed
from the body, not kept in English.

## Body structure — no duplicated property fields

Date, Status, Type / Mode, the Task + Feature Archive relations, and
Author live as **Notion DB properties + relations** on the Engineering
Plan row — the body must not repeat them. The gate flags a body that
opens with a `**Status:** …` / `**Author:** …` / `**Date:** …` /
`**Source plan:** …` / `**Source spec:** …` header block; the body
starts at the actual content (the `## Engineering review` section per
the template).

## Exemptions

Mirror the top-level exemption list: typo fixes, refactors that
preserve behavior, lint fixes, and isolated bug fixes. A bug fix
does not need a fresh engineering plan; a flow change, new
screen, new data source, or scope shift does.
