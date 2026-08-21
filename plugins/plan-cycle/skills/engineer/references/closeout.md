# Mid-flow divergence, exception discovery, post-implementation review & close-out (Phases 11 / 11.5 / 12 / 13 detail)

This file carries the four post-approval protocols in full — everything
that happens once implementation has started, as distinct from Phases
1–10's plan-authoring work. engineer/SKILL.md keeps a short summary of each;
read here for the step-by-step.

## Contents

- **Phase 11 — Mid-flow divergence**
  - The six-step resolution
  - Routing by divergence kind
- **Phase 11.5 — Exception discovery**
  - Route it the moment you find it (a)–(e)
- **Phase 12 — Post-implementation review & fix loop**
  - Step 1 — Invoke `/review`
  - Step 2 — Verdict per finding
  - Step 3 — Apply FIX changes
  - Step 4 — Land DISMISS / DEFER rationale
  - Step 5 — Re-invoke `/review` when CRITICALs existed
  - Step 5.5 — Commit gate (Iron Law 10)
  - Step 6 — Close out
  - What Phase 12 does NOT do
- **Phase 13 — Close flow (per-cycle + per-feature-line)**
  - Stage 1 — Per-cycle close (mandatory, runs after Phase 12)
  - Stage 2 — Per-feature-line close (judgment, owner confirms)
  - What Phase 13 does NOT do

---

# Phase 11 — Mid-flow divergence

If during implementation an engineering decision in the task list
turns out wrong — a layer doesn't compose, a chosen library fails a
constraint, a sketched data flow has a race — resolve it, don't
silently route around it.

## The six-step resolution

1. **Stop.**
2. Update the affected tasks via `TaskUpdate` (or `TaskCreate` new ones).
3. **Write the change into the Notion Engineering Plan row body's task
   checklist and `## Revision history`** — invoke the `archivist` skill
   (launcher's Iron Law 6); the row body is canonical for content, so
   silent drift between it and the task list breaks the audit.
4. **Re-audit the rev'd plan (Phase 9) — `plan_lint.sh` clean, then
   `blueprint-reviewer` on what changed plus its blast radius, *before*
   re-approval** (a divergence rev is a plan change like any other;
   `/plan` §Re-audit every plan
   change). This is exactly where a new
   violation the original audit never saw (e.g. a P1 terminal-collapse
   refactor that silently changes user-facing behavior) slips in — so
   the rev never reaches code unaudited.
5. Re-request user approval for the delta.
6. Resume.

## Routing by divergence kind

If the divergence is **scope** (product plan didn't authorize this),
route to the PM role. If **UI** (design spec didn't cover this state /
surface / token), route to the designer role. If **security** (new
attack surface), route to the `security-reviewer`. Read
`${CLAUDE_PLUGIN_ROOT}/skills/engineer/references/escalation.md` for the
verbatim-handback protocol when this role is invoked mid-flow from
another skill.

Do **not** silently choose a different architecture mid-diff. The same
divergence rule binds the engineering plan that binds the product plan
and design spec.

---

# Phase 11.5 — Exception discovery and batch resolution

During implementation the implementer encounters exceptions not
listed in the plan's §Error policy matrix — typically by
reading framework / plugin docs, by hitting a throw in a test,
or by walking a code path that turns out to throw an exception
class the planner missed. These are **enumeration drift** in
the error matrix, not architecture divergence (Phase 11).
Don't stop; log them. Resolve in batch immediately before that
phase's Phase 12 gate — for a Phased plan this fires **per landed
phase** (engineer/SKILL.md §Per-phase gate, Phase 7), not saved for the
last one; a Single-slice plan has one phase, so it's just "before
Phase 12" as below.

**The Phase-3 tracer front-loads only the *traceable* exceptions
(pre-existing chains + already-chosen leaves), so this phase no longer
carries the whole enumeration — but it stays LOAD-BEARING for
implementer-introduced throw sites** (a primitive / library the plan left
unspecified, new control flow, a new isolate), which the tracer cannot
see at plan time. For a chain whose leaf API + primitives the plan fully
named, an empty log is expected; for any chain that deferred that choice,
a *populated* log is expected and correct. The logging discipline below
and the Iron-Law-7 zero-`Pending`-rows gate (Phase 12 Step 0) are
**unchanged** — "front-loaded" never means "optional".

## Exception discovery — route it the moment you find it

When implementation surfaces an exception the plan's §Error policy
matrix did not predict, resolve it **there and then** — do not carry a
queue. First find the evidence (the throwing `file:line`, a framework
doc, a platform observation). **If you cannot find evidence, the
exception probably cannot occur on this path** — don't invent a row for
it.

Then route by what kind of decision it actually is:

- **(a) Unambiguous → add the row to §Error policy yourself.** Another
  `FileSystemException` from a new code path the existing outer-catch arm
  already covers; another transient cloud exception matching the existing
  transient-vs-conclusive classification. Add it citing the new Source and
  the same fallback, and note it `〔自行裁定〕` on that row so the founder
  can scan and override it.
- **(b) Ambiguous but engineering-internal → ask the user.** A new
  exception class with multiple plausible fallbacks; an unclear
  retry-vs-fail call.
- **(c) Product scope → the PM role.** Silent-vs-surface, new user-facing
  copy, a recovery-contract change, a persistence-flip rule change.
- **(d) UI scope → the designer role.** A new error affordance — banner /
  snackbar / retry button / re-auth flow / conflict-resolution prompt.
- **(e) Rare, cheap to leave defaulted, and has a clear revisit trigger →
  defer to a TaskList task.** Open it (Status `Deferred` + the Trigger —
  Crashlytics signal above N hits, a plugin major bump, the next feature
  touching this path) via the `archivist` skill, and record the deferral
  as a `〔自行裁定〕` / `〔使用者〕` note on the affected row.

**Batch the escalations, not the discoveries.** If a phase turns up
several (b) / (c) / (d) items, consolidate per route — one
`AskUserQuestion` covering up to 4 user-internal questions, one
`Skill: pm` call covering all PM-scope questions, one `Skill: designer`
call covering all UI-scope ones. Each carries the exception, the
evidence, and the options with your recommendation first.

**Nothing is left silent.** Every discovery ends as a matrix row, an
answered question, an upstream amendment, or a deferral with a trigger —
and every one of those leaves a decision note where it landed. There is no
separate exception log: the catch block has to be written for the code to
compile, so "defer the decision" is really "make it provisionally and
revisit" — which the note already records and the code-stage gates already
read against the plan.


## Step 1 — Invoke `/review`

Mark the seeded "`/review`" task (that phase's, for a Phased plan)
`in_progress` via `TaskUpdate`, then invoke `/review` against
the uncommitted diff — **that phase's diff** for a Phased plan, the
whole uncommitted diff for a Single-slice plan. The `/review` skill is
the project dispatcher and will spawn the `code-reviewer` sub-agent
(report-only). Pass the engineering plan (the feature's
Engineering Plan DB row) and the source product plan + design
spec rows so the reviewer can ground findings against intended
behaviour.

Default invocation:

```
/review the uncommitted changes against
the feature's Notion Engineering Plan row (the plan under review)
(source plan: the feature's Notion Product Plan row,
 source spec: its Design Plan row  or "non-UI work")
```

Background spawn is the `/review` default and is correct here —
the implementation diff is already on disk, the agent does not
edit source, and the main session can prepare the verdict scratch
while the reviewer runs. Foreground only when the user explicitly
asks to block on the review.

## Step 2 — Verdict per finding

When `/review` returns, every CRITICAL / WARNING / INFO finding
gets an explicit verdict from the `/review` skill's verdict set
— **FIX**, **DISMISS (with rationale written into the code or
the log file)**, **ESCALATE** (route to the PM role / the designer role /
the `security-reviewer`), or **DEFER** (only when written into a TaskList
task — Status `Deferred` + a Trigger, opened via the `archivist`
skill). Silent skipping is forbidden — re-read the `/review`
skill's "What 'silent skip' means" section before composing a
verdict.

Verdict default when a rule is ambiguous: **FIX**, not DISMISS.

## Step 3 — Apply FIX changes

Apply each FIX verdict in the main thread, one finding at a
time so the diff stays reviewable. After a FIX edit:

- After a FIX, run `dart format` + the project's lint command on the
  changed files yourself — the Step 5.5 commit gate (legs 1–2) re-checks
  them before commit. If a non-Dart sub-project changed, ensure it is
  rebuilt per its own build step.
- If a FIX touches a layer not covered by the original plan
  (new abstraction, new schema, new API caller), route through
  Phase 11 (Mid-flow divergence) first — update the affected tasks via
  `TaskUpdate`, rev the row body's §Classes / §Conformance (via the
  `archivist`), and re-request approval before landing the edit.
- If a FIX changes a test seam or coverage target, hand the
  test-authoring work to `/qa` per Iron Law 1 of
  `testing.md` — do not write `test/**` from the engineer role.

## Step 4 — Land DISMISS / DEFER rationale

Each DISMISS verdict needs its rationale **in code** — a **one-line**
`// review-dismiss: <reason>` at the site. One line is the whole
budget, and the reason must be specific and not precedent-only; the
next review reads it as the argument to beat and may overturn it
(`code-reviewer.md §Challenging a dismissal`). Each DEFER verdict needs a
matching TaskList task (Status `Deferred` + a Trigger — opened
via the `archivist` skill). Verbal "we'll address it later" is a
silent skip and re-classifies as FIX.

## Step 5 — Re-invoke `/review` when CRITICALs existed

If the first pass surfaced any CRITICAL finding, or if the
applied FIXes were non-trivial (multiple files, signature
changes, new abstractions), invoke `/review` again to confirm
clean. Re-review is cheap — the diff is small and the reviewer
sub-agent caches little state. Stop only when:

- Every finding has a written verdict, and
- A re-review (when triggered) returns clean or returns only
  findings with already-written DISMISS / DEFER rationale, and
- No FIX-induced regression surfaced.

## Step 5.5 — Commit gate (Iron Law 10)

Three legs must **all** be green before any `git commit` fires —
and they are checked **here, explicitly**, NOT left to the
turn-end Stop hook (the gate is the source of truth; do not rely
on the hook running after the commit):

0. **Regenerate codegen first (when applicable).** If the diff changed
   any freezed / json_serializable codegen **input** — a new or edited
   `@freezed` / `@Freezed` / `@unfreezed` / `@JsonSerializable` class, a
   field add / remove / rename, a new `fromJson` / `toJson` — run
   `dart run build_runner build --delete-conflicting-outputs` and include
   the regenerated `*.freezed.dart` / `*.g.dart` (+ `lib/generated/**`)
   in the diff. Stale generated files fail legs 1–2 and ship a broken
   build, so this runs **before** lint/test. Never hand-edit generated
   files (`.claude/rules/code-style.md §Generated Files`).
1. **Lint + format clean.** Run the project's lint command (no
   arguments) and `dart format` on the changed Dart files — confirm
   **zero** issues (analyzer + custom rules). The custom rules cover
   `lib`/`test`/`tool` via all three zones; `flutter analyze` itself
   still defaults to `lib` only in this no-argument form — `test`/`tool`
   each carry a real, untriaged stock-lint backlog the changed-files-only
   gate never caught (`the lint package's own docs`).
   Never call `flutter analyze` / `dart analyze` directly (deny-listed —
   the wrapper is the source of truth). A lint-dirty / unformatted diff
   does **not** commit; fix it
   first.
2. **Tests green.** Run `flutter test` over the affected scope and
   confirm it passes — no red, no unexplained skip. A failing test
   blocks the commit.
3. **`/review` clean.** Per Iron Law 7 — `/review` has run, every
   finding has a written verdict, and a re-review confirms clean
   when CRITICALs existed.
Only when legs 1–3 are **all** green does `git commit` fire. Legs
1–2 are mechanical (run them, don't assume); leg 3 is the review leg.
**Read the index before committing:** run `git diff --cached` as its
**own** call — confirm only the intended files are staged, and if it
already holds work you did not add (the user's pre-staged changes),
`git restore --staged` it first rather than committing it blind.
Post the close-out report **with** the commit — affected files, lint +
test results, `/review` cycle count + verdict mix, plan path, hash.

**Leg-3 tooling carve-out.** A **tooling / lint-package** change (a new
the project's linter AST-visitor rule, an analyzer-plugin tweak) that a
purpose-built probe has verified — true-positive fires, true-negative
stays silent, zero false positives — skips the `/review` leg: the
`code-reviewer` is **off-domain** for AST-visitor / analyzer-plugin code
and has hallucinated on the analyzer-API surface, so its pass adds no
signal there. Legs 1–2 still bind; the carve-out is leg 3 only, and
only for a change whose own probe *is* the correctness evidence. App-code
changes never qualify.

If the user dismisses some part of the diff ("revert the X change"):
apply the revert as a normal edit, re-fire `/review` against the
smaller diff (Step 5 cap still applies), then return to Step 5.5. The
diff that gets committed is the diff `/review` saw last, not an
earlier snapshot.

## Step 6 — Close out

**Runs once** — after the *final* phase's Step 5.5 passes for a
Phased plan (earlier phases' Step 5.5 lands their commit and moves on
to the next phase without running Step 6). Four mandatory actions; run
all four before declaring close-out. Step 5.5 has already landed the
commit by the time Step 6 starts; the hash referenced in action 4 is
that commit's hash.

1. **Mark task done** — `TaskUpdate` "Post-implementation code
   review" → `completed`.
2. **Check off the Notion task's `## Implementation` mirror** — its last
   unchecked items, via the `archivist`. **Do not copy state into the plan** —
   it carries no task list, and a shipped plan's Status already says it landed.
3. **Revision history entry** — append `Rev N: post-implementation
   /review — <count> findings, <count> FIX / <count> DISMISS /
   <count> DEFER; clean re-review`.
4. **Flip the plan's Status to Shipped** — invoke the `archivist` skill (you
   have no Notion MCP — the launcher's Iron Law 6) to set the Notion Engineering Plan
   row's **`Status` property** to `Shipped`, set the row's `Date`
   property to the ship date, and append a `## Revision history` entry
   `Rev N: Shipped YYYY-MM-DD, commit <hash>` to the row body. `<hash>`
   is the real hash from the Step 5.5 commit — read it with
   `git rev-parse HEAD`; do not invent or estimate. Have the `archivist`
   fetch the row back and confirm `Status = Shipped` — not `Draft`, not
   `In Progress`. (Status lives as a Notion DB **property**, never
   duplicated in the row body — per `/plan` SKILL.md "No duplicated
   property fields".)

**Iron Law 7 binds.** Skipping action 4 is the single most common
silent skip — the implementation ships, but the plan looks pending
to every cross-cycle reader. Phase 13 Stage 1 + Stage 2 gates key
off this field; a stale `Draft` makes the slug archive-ineligible
even when the feature has shipped. Auditors who scan the Engineering
Plan DB Status for pending work must be able to trust the Status property
as the live truth.

Update the feature's TaskList task(s) per Phase 10's rule —
close the in-flight task when the cycle ends fully closed, or
update it to name the DEFER follow-ups (Status `Deferred` + a
Trigger, via the `archivist` skill).

Closing report wording:

```
Implementation closed for: the feature's Notion Engineering Plan row
/review cycles: <count>  (CRITICAL: <count>, WARNING: <count>, INFO: <count>)
Verdicts: <FIX-count> FIX, <DISMISS-count> DISMISS, <ESCALATE-count> ESCALATE,
          <DEFER-count> DEFER (tasks written to the TaskList DB)
Re-review: <clean | not-required>
Status: Shipped (Notion row Status property set + revision-history entry landed, via archivist)
```

## What Phase 12 does NOT do

- Phase 12's Step 5.5 commit gate runs the project's lint command
  (no arguments), `dart format`, and the scoped
  `flutter test` **explicitly** as legs 1–2 — they are no longer
  deferred to the turn-end Stop hook. Never call `flutter analyze` /
  `dart analyze` directly (deny-listed — the wrapper is the source of
  truth).
- Phase 12 does **not** invoke the `security-reviewer`. Security
  review is a separate gate; if the review surfaces a finding that
  crosses into vulnerability territory (new attack surface, secret
  handling, auth boundary), ESCALATE to the `security-reviewer`
  (via `/review`) rather than resolving in the engineer role.
- Phase 12 does **not** run a design-review pass. Design adherence is the
  engineer's job to enforce against the design spec during implementation;
  `ux-reviewer` already gated the spec, and mockup-fidelity is a manual
  founder check.
- Phase 12 does **not** edit code from the reviewer's sub-agent
  — `/review` is report-only and the main thread applies fixes.

---

# Phase 13 — Close flow (per-cycle + per-feature-line)

Phase 12 closes the **implementation** — but cycle artefacts
(plan, design spec, TaskList task, TaskCreate tasks) keep living in
the active workspace until they are either deliberately retained
for follow-up amendments or moved to long-term retrieval. Phase
13 codifies that lifecycle so the workspace doesn't accumulate
dead pending-downstream lists or stranded shipped plans that
nobody knows whether to keep.

The flow runs in two stages — one mandatory after every cycle,
one conditional on judgment + owner confirmation.

## Stage 1 — Per-cycle close (mandatory, runs after Phase 12)

When Phase 12 returns clean **and** the post-ship verification step
has been dispatched — default: **ship a beta to Firebase via the
`ship-beta` skill** for the testers group to smoke on real devices
(not an owner-run manual matrix) — execute these in order:

1. **Plan Status** — verify Phase 12 Step 6 action 4 actually
   landed: have the `archivist` fetch the Notion Engineering Plan row
   and confirm its `Status` property reads `Shipped`, not `Draft` /
   `In Progress`. Also verify the revision history's last entry
   names the `/review` verdict + log path. If the Status is stale,
   the cycle silently skipped Phase 12 Step 6 action 4 — return to
   Phase 12 and complete it before proceeding.
2. **TaskCreate tasks** — every task in this cycle's list is
   `completed` (no stragglers in `in_progress`). The Phase 12
   close-out task in particular.
3. **TaskList task flip** — the in-flight task for this
   amendment becomes a SHIPPED summary:
   - Title / status: the feature's TaskList task reflects the
     shipped amendment (e.g. `<slug> (F-NNN vX.Y amendment) —
     SHIPPED YYYY-MM-DD`).
   - Summary: 2–3 sentences summarising what shipped + cite the
     plan / spec / review-log paths. **Do NOT keep "Pending
     downstream" lists** — those were the cycle's backlog; once
     the cycle ships, the audit trail lives in the plan's
     revision history, not in the TaskList task.
   - Retain only **forward-looking** items: `OQ-N ship-after
     observation point`, a beta smoke (shipped via `ship-beta`)
     whose tester feedback hasn't landed yet, or known follow-up
     gates that block future work. Each retained item is a TaskList
     task (Status `Deferred` + a **Trigger**, via the `archivist` skill).
   - Mid-flight residual ("beta smoke pending",
     "post-ship verification pending") clears off the TaskList
     once owner confirms PASSED — don't carry already-passed
     gates as dead text.
4. **Reclaim the cycle's disk footprint** — invoke the
   **`reclaim-space` skill**, which owns the sweep and the judgment
   around it (measurement discipline, fail-closed version scan,
   deliberate omissions). A shipped cycle leaves several gigabytes of
   build output and machine-wide tool cache behind, and nothing else in
   the flow ever removes it; on a full disk that accumulation is what
   eventually blocks the next build.
   - **This step, and not earlier.** Cleaning at the end of a *test
     run* is wrong: review rework re-runs the build and pays the
     rebuild twice. Stage 1 runs after Phase 12 returns clean, which
     is the first moment the artefacts are genuinely dead.
   - Report the skill's **freed** figure, never the per-target sizes it
     lists — the reason is in that skill and is not restated here.

Stage 1 is non-skippable. The cost of skipping is **stale
"in-flight" tasks** that the next planning cycle has to
re-classify ("is this still running, or is it done and the
TaskList task never got cleaned up?"). This wastes context budget
indefinitely.

## Stage 2 — Per-feature-line close (judgment, owner confirms)

When **all amendments under a feature slug have shipped** and
the owner explicitly confirms the feature is closed (not
dormant, not paused, not under-watch — closed), invoke the
`archivist` skill to synthesize the feature's plan rows (its Product /
Design / Engineering Plan DB rows + TaskList task) from the active
workspace into the the project's Notion KB — a Feature Archive row
+ Decision Log entries — and trash the feature's TaskList task once the
entry is verified (the plan rows stay in their DBs as history).

Mandatory checklist before invoking `archivist`. **Any unchecked
box → archive is too early, the feature stays live in its plan DBs
(not archived to the KB):**

- [ ] Father PM one-pager status = `Shipped` or
      `Terminally abandoned`.
- [ ] Every amendment file (v1.2 / v1.3 / v1.4 / …) status =
      `Shipped`.
- [ ] Corresponding design spec status = `Shipped` at the
      latest rev that covers all PM amendments.
- [ ] Corresponding engineering plan status = `Shipped` with
      Phase 12 done for every PM amendment.
- [ ] The feature's TaskList task(s) reflect final status —
      zero active deferred items: no `Pending downstream`, no
      `owner verification pending`, no `OQ-N ship-after
      observation point`. Stage 1 already cleared cycle-internal
      pending; the remaining items here are feature-line
      residuals.
- [ ] No in-flight the PM role / the designer role / the engineer role /
      `/qa` cycle for this slug.
- [ ] Owner explicitly says "this feature is done, archive
      it". Verbal "looks good" or "we're done with the
      sprint" does **not** clear this — the owner ruling
      must name the slug.

Forbidden trigger patterns (Phase 13 anti-patterns):

- "Feature has been quiet for N months, time to clean up" —
  dormant ≠ closed. Archive removes context from the active
  retrieval path; if a user-feedback signal triggers a v1.7
  amendment six weeks from now, the prior context having
  moved to the Notion KB adds retrieval friction.
- "The TaskList DB is getting long, archive a slug to slim it
  down" — `archivist` description forbids `speculative tidying`.
  TaskList length is a Stage 1 hygiene problem (uncleaned
  pending-downstream tasks), not a Stage 2 archive trigger.
- "OQ-N is unlikely to fire, archive anyway" — observation
  points are part of the audit trail; their purpose is to
  catch user-feedback signals six months from now. Archiving
  them moves the context to long-term retrieval but the
  feedback-log's connection back to the plan body becomes a
  cross-corpus reach. Keep observation points as active TaskList
  tasks until owner explicitly closes them.

Stage 2 invocation:

```
Skill: archivist with args:
  Archive the feature line (its Product / Design / Engineering Plan
  DB rows + TaskList task) — all amendments shipped, owner confirmed
  closure YYYY-MM-DD, checklist clear.
```

The archivist owns the synthesis into the Notion KB (Feature
Archive row + Decision Log) + original-file deletion, and — once the
Feature Archive row is verified (Iron Law 2) — **trashes the feature's
TaskList task(s)** per its close-out / archive flow (the plan rows are
kept; the active workspace no longer tracks this feature; the Notion KB
does).

## What Phase 13 does NOT do

- Phase 13 does **not** force every shipped cycle to archive
  immediately. Most feature lines accumulate multiple
  amendments under one slug; Stage 2 only fires when the
  whole slug is closed.
- Phase 13 does **not** modify the plan row's content —
  Stage 1 only touches the feature's TaskList task; Stage 2
  hands off to the `archivist` to synthesize the cycle into a
  Feature Archive row (per the close-out / archive flow).
- Phase 13 does **not** auto-fire the archivist. Stage 2 is
  judgment-gated by the owner ruling. Auto-archiving on
  "looks shipped" is exactly the speculative-tidying pattern
  `archivist`'s description bans.
- Phase 13 does **not** dispose of user-feedback entries. The
  feedback log is cross-feature and lives in the Notion **User
  Feedback Log** DB (a pre-existing, not-actively-archivist-managed
  DB) regardless of individual slug archives.
