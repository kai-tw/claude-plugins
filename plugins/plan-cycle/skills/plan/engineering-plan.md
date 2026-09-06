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
   `notion-payload template engineering-plan` for the skeleton to fill
   (shape + where `I4` decision notes go) and
   `notion-payload hints engineering-plan`
   for the section questionnaire (description, hints, criteria per section).
2. **TaskCreate task list** in the conversation — **the only task list**,
   canonical for both content and live status, with task 1 being the
   engineering review itself.

The engineer role enumerates the tasks straight into TaskCreate from §Classes
and §Conformance. **The plan body carries no task list** — a copy re-uploaded
only on a rev cannot stay honest about what was resequenced or shipped.

## Required contents

The gate verifies the engineering plan covers, at a minimum:

- **Engineering review of the product plan and design spec** —
  what is internally consistent, what is ambiguous, what
  conflicts with existing constraints, what has been silently
  pushed onto engineering.
- **Facts ledger (§事實帳)** — every load-bearing claim about existing
  behavior as a typed-evidence row (`file:line` / `實驗：指令 → 觀察` /
  `未讀` / `只能實測：<how>` / `今天成立：<失效事件>`); prose cites F-ids
  and never restates. A plan whose existing-behavior claims live only in
  prose is the measured top cause of review bounces.
- **Affected layers and modules** — concrete file / package /
  feature paths that change, are added, or are removed.
- **Class / interface / data-shape sketch (§Classes)** — a summary
  table where every touched class carries a real file path marked
  `NEW` / `MOD` / `DEL`, and **every NEW row answers `為何要新增`** in
  one of the schema's evidence-bearing forms (框架/平台：<查過什麼 →
  結論> / canonical home：grep <什麼> → <為何 reuse 不了> /
  套件 <名>@<版>：<contract clause> → <source>) — this column is the
  cycle's only landing spot for "should this exist at all", and the
  gate treats a blank one as an unasked question, not a formality.
  Per-class contract tables carry `既有方法夠嗎` as typed evidence
  (same vocabulary as §事實帳). `plan-lint` hard-checks all three:
  the file markers against the repo, the NEW-row justifications, and
  the evidence typing. Conformance with `architecture.md` and
  `naming.md` + `error-handling.md` noted per affected module.
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
(`engineer-plan-reviewer` for judgment, `engineer/scripts/plan_lint.sh` for the
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
`divergence.md` for the full procedure. This is not left to
self-report alone: the commit gate's reconciliation leg
(`plan-lint <plan> --diff`, `commit-gate` leg 3) blocks any
diff that adds a file or class no §Classes NEW row names, so a
subsystem invented mid-implementation must pass back through this
divergence route — or be deleted — before it can land.

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
