# Mid-Flow Divergence Procedure

Read from the `/plan` launcher's §Mid-flow divergence step, when an
artifact (product plan, design spec, or engineering plan) turns out
wrong, incomplete, or infeasible mid-implementation.

The single overriding principle: **do not silently ship a different
product, UI, or architecture than what was approved.** Every
divergence has to route back through the right authoring path
before code resumes.

## The procedure

When you discover the artifact is wrong:

1. **Stop.** Do not continue the diff. Do not "just fix it" inline.
2. **Identify which artifact is wrong.** Product scope? UI layout
   / token / state? Engineering decision (layer composition,
   library choice, data flow)?
3. **Route to the right author — each re-authors the artifact AND
   re-uploads it to Notion** (the plan IS a Notion DB row; an
   amendment that only lives locally or in chat does not exist —
   the launcher's Iron Law 6):
   - Product scope change → re-run the PM role in-thread; it amends the
     **Product Plan row** (invoking the `archivist` skill to write Notion).
   - UI change (any styling-token-level tweak counts) → re-run the
     designer role in-thread; it amends the **Design Plan row** (via the
     `archivist`).
   - Engineering decision change → re-run the engineer role in-thread; it
     amends the **Engineering Plan row body** (via the `archivist`)
     **and** updates the paired TaskCreate task list.
4. **Re-request user approval** for the delta. Approval to the
   original plan does not transfer to a changed plan.
5. **Resume implementation** once the updated artifact is approved
   **and re-uploaded to Notion** (the `archivist` write confirmed —
   the launcher's Iron Law 6). An amendment that changed only in chat or a local
   note, not in its Notion row, has not landed.

## "Just fix it" is not allowed

The pattern: you're three layers deep in implementation, you notice
the plan said feature A but actually you also need to do B for A to
work, and you're tempted to just add B. Don't.

- The user has no surface to push back on B if B never appears in
  the plan.
- Future readers (including future-you) can't reconstruct why B
  exists if its provenance is buried in a non-feature-titled
  commit.
- Scope creep via "while we're in here" is the most common way
  features balloon. Each individual decision feels small; the
  aggregate is unrecognizable from the original problem.

Always route. Even when the change feels minor.

## What counts as "diverging"

### Product plan divergence

- The plan's success metric no longer applies to what you're
  building.
- A non-goal turns out to be in scope.
- A scope item is genuinely impossible and needs to be cut or
  redefined.
- The target user is wrong — what you're building serves a
  different persona.
- A new sub-feature surfaces during implementation that was not
  in the plan's scope.

### Design spec divergence

- A breakpoint layout doesn't hold (cramped on `medium`, gappy on
  `expanded`).
- A token assignment is wrong (a `colorScheme.error` icon should
  have been `colorScheme.onSurfaceVariant`, padding `12` should
  have been `16`).
- A state is missing (empty case, loading case, error case, offline
  case).
- A shared component the spec named doesn't fit and a new widget
  is needed (push back to verify before introducing the new
  widget).
- Accessibility requirement can't be met as specified.

**Every styling change must be acknowledged by the designer.**
There is no inline-exemption escape hatch — token-level tweaks go
through the designer role and land in the spec before the diff ships.

### Engineering plan divergence

- A sketched class boundary doesn't compose with existing layers.
- A chosen library / SDK has a constraint that breaks the plan.
- A data flow has a race condition or ordering hazard that the
  initial sketch missed.
- A migration step needs sub-steps that weren't planned.
- A test seam doesn't exist where the plan assumed it.
- An exception class taxonomy needs a different shape than
  sketched.
- The implementation is drifting toward a **simpler stand-in** of the
  plan's specified mechanism (a view-side approximation of a
  repository-side judgment, a one-shot timer for a continuous
  threshold). Re-inventing the mechanism mid-iteration is a
  divergence, not an optimization — route it, or build to the plan
  verbatim. **Before writing a device-reported fix, re-read the plan**
  (`ntn pages get <eng-plan-id>` + design / product) and grep the exact
  mechanism, grounding both the action predicate and any
  button-disable predicate in the plan rather than intuition; if the
  plan is underspecified, write the precise state table INTO it first,
  then build to that. The plan's spec is itself a load-bearing claim
  and carries the same source-first bar as any other. *Measured:* a
  repository-side per-chapter threshold judgment was re-invented
  during device iterations as a view-side "nearest earlier chapter"
  plus a one-shot timer, breaking the restart-grace re-arm and the
  button-disable on three counts.

## What does NOT count as divergence

- **Naming refinements** that don't change the artifact's
  decisions. Renaming `FooManager` to `FooCoordinator` while the
  role is unchanged is just typing.
- **Sub-decisions inside an approved layer.** The plan said
  "add a `CloudSyncController`" — the exact private methods inside
  that controller are implementation, not divergence. **The exemption
  stops at named classes**: a new *class* (or top-level helper) is
  never a sub-decision, however deep inside an approved layer it
  lives — the commit gate's reconciliation leg (`plan-lint --diff`)
  blocks any class no §Classes NEW row names, so an internal
  subsystem that "grew" mid-implementation routes through here
  first or does not land.
- **Authoring the next phase of a just-in-time Phased plan.** A rev that
  fills in a phase §Later phases already named is planned work arriving on
  schedule, not a scope change — the founder approved the cut when the plan
  was phased (`engineer/SKILL.md` §Right-size the plan). Dropping or
  growing what that line promised is divergence; route it.
- **Bug-fix exemptions discovered along the way.** Finding a real
  bug while implementing a feature, fixing it inline (no flow
  change), and noting it in the commit is fine — the bug fix is
  exempt from the plan gate.

When in doubt: would a future reader, reading the artifact alone,
predict what shipped? If yes, no divergence. If no, divergence —
route.

## The cost of routing

Routing back to the PM role or the designer role costs a turn or two. That is
the intended cost. The alternative — silent scope drift — costs
the product. Every time.
