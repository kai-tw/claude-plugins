# Gates — which one runs when, and how it stops

> `plan/SKILL.md` 的路由決定**跑哪些 gate**；本檔決定**它們怎麼收斂**。
> 每一道 gate 都受本檔約束，所以它住在一個地方而不是每個角色一份。

#### The audit matrix (which gate runs in which tier)

Gates run in **two tiers**, split by what "clean" means for them — and the cost
follows from that, not the other way round. The checklist tier gates *before* the
founder's time is spent; the judgment tier runs *after* the scope is settled, so
it never grades a draft that is about to change.

| Stage produced | ① Sanity (cheap, before Resolve) | ② Adversarial (opus, judgment, after Resolve) |
|---|---|---|
| **PM plan** | `pm-plan-reviewer` (pm rules `P1`–`P8` + plan integrity) | `feasibility-reviewer`(designer + engineer lens) |
| **designer plan** | `design-lint` (script, not an agent — the shipped widgets) | `design-plan-reviewer` — usability **and** deliverability, against the renders + widget source |
| **engineer plan** | `plan_lint.sh` (script, not an agent) | `engineer-plan-reviewer` |
| **code (after implementation)** | `code-reviewer` | `security-privacy-reviewer` (threat model + data minimization) — *boundary-gated on the diff's sink signals* |
| **after QA** | — | `post-qa-reviewer` — the spec residue QA's tests can't pin, cross-feature mechanism parity against the plan's §Conformance `同儕：` rows and the project's `.claude/rules/consistency.md` table, and the design of every test the diff touches |

Because PM and designer share one round (§Step 4), their two Sanity cells run as
one batch and their two Adversarial cells as one battery — one Resolve between
them, not two.

The ① cell is a different agent per stage, with the checks rehomed **by kind**:

- **The checklist walk stays a walk, and stays independent.** A PM plan gets
  `pm-plan-reviewer` — one pass over `pm/references/rules.md` `P1`–`P8` plus
  `§Plan integrity`, passed / violation / na / 無法判定 per sub-check. An author
  may know its rules; it may never grade itself (player ≠ referee), so this cell
  is never a self-check.
- **Engineering judgment → the dimensions**, inside `engineer-plan-reviewer`'s walked
  dimensions and cross-cutting checks.
- **Design judgment → `design-plan-reviewer`.** The designer rules also live inside the
  ② usability sweep, so a spec that lies about state, hides a distinction in one
  perceptual channel, or pollutes a shared component surfaces as the usability
  defect it is — with severity attached — rather than only as a rule number.
- **Comparison → a script.** `engineer/scripts/plan_lint.sh`: the named files
  exist, §Conformance rows map to tasks, §-refs resolve, no count points back at a
  body that changed. A comparison a script settles should never cost a review
  round-trip — the same call-site count was written wrong three revisions running.

#### Gate loop policy — loop the checklist, verify the judgment

**The two tiers loop differently, because "clean" means different things.**

- **① Sanity — loop to green, capped at 3 rounds.** It walks a **finite,
  enumerated checklist**, so green is a real state and a re-run genuinely verifies
  the fix rather than producing a fresh opinion — which is also why it is the
  cheap tier. For the PM plan that walk is
  `pm-plan-reviewer` (**旁觀, 禁自審**): every `violation`
  fixed in place, no deferred and no dismiss, re-spawn, loop — a later round
  catching that an earlier round's *fix* was itself wrong is the loop working.
  **Not green by round 3 → stop looping and
  hand the founder a plain-language report**, one entry per unresolved item:
  **缺失項目 / 原因 / reviewer 評價 / 自提解法**. Write about the plan's defect and
  what you would do about it — never about the gate, the checklist, or how the bar
  is set; the founder is ruling on the plan, not on the mechanism.
  The engineer plan's cell is `plan_lint.sh` instead — a script, so it does not
  loop: clear every HARD failure, eyeball every ADVISORY line.
- **② Adversarial (opus gates) — one pass, then one verification. Never
  loop-to-green.** Re-running a judgment gate produces a *new* judgment, not a
  verification of the old one; converging on "it stopped finding things" partly
  measures the gate's own variance rather than the plan's quality. So: run it
  once; resolve every finding; then run **one** verification pass scoped to what
  changed plus its blast radius, **briefed with the prior findings** so it
  dispositions each one rather than re-deriving (for `engineer-plan-reviewer` this is
  the `--prev` round — `agents/engineer-plan-reviewer.md §The verification round`).
  - **`critical` blocks until resolved** — unchanged, and non-negotiable. What is
    dropped is re-deriving the whole judgment each round, not the blocking.
  - **`warning` never triggers a loop** — it goes to the founder to weigh, or is
    noted at the affected line as an accepted trade-off.
  - **A finding that cannot be reduced is dropped, not escalated.** Before a
    finding becomes a change, name what makes it true — the existing test it
    turns red, or the source line that proves it (§Green is not proof). Neither
    can be named, and the failing test cannot be written? **The finding is what
    is wrong**: drop it and log the drop. This is the tier's mechanical exit
    condition, and it is the only one it has — every other gate in the cycle
    terminates on a script (`plan_lint.sh` exit 0, coverage per line, mutation
    per file), while this one would otherwise terminate on somebody inside the
    loop deciding it had converged.
  - **Escalate the moment a finding changes kind.** Any round budget is a
    ceiling, not a quota. Once a finding stops being a *verifiable error* (a wrong
    number, a missing section, a claim the source contradicts) and becomes a
    *debatable judgment* (the reviewer would rank the trade-off differently), no
    further round can settle it — that call is the founder's. Judge by the
    finding's kind, never by the round number.

#### Green is not proof

**Green is not proof — and neither is red.** A gate's verdict is evidence, not a
certificate, in both directions: a re-run can pass against wrong reasoning, and a
finding can be wrong on its face. So before a finding becomes a code change,
**name what makes it true** — the existing test it turns red, or the source line
that proves it. Neither can be named? Write the failing test first; if that test
cannot be written, the finding is what is wrong.

**A direction claim is settled by executing it, never by reviewing it again.**
Paper review is structurally weak at truth-table errors — an inverted comparison,
a reversed guard — because each round's attention follows what changed most
recently, so a line that stopped changing reads as already verified and the rounds
accumulate confidence instead of evidence (an inverted `!=` survived three rounds
plus the author's own truth-table checks). When a plan adds a condition to an
existing loop or method, the first verification is a runnable test of that truth
table — a throwaway worktree is enough — not another review round. The converse
is what review is *for*: ownership and shared-state defects (a capability sitting
in the wrong layer, a private field shared across callers) are found by judgment,
not by execution, and stay worth sending.

**`engineer-plan-reviewer` runs on every engineer plan** — never skipped, not even on
a single-slice plan, which would otherwise have no judgment gate at all, only
a script. The cost stays proportionate because its own **Stage 1b scope-gate**
right-sizes the fan-out over its **two** dimensions — abstraction / reuse /
ownership, and migration & back-compat, the two that ask *should this exist at
all* — and a single-slice plan dispatches only those whose surface it actually
touches. Package choice is not a third: `package-explorer` returns a
source-evidenced verdict that the review carries intact rather than re-judging. Everything that asks *is it built right*
(time, space, scalability, extendability, coupling, correctness & race, error
handling, testability, startup) is graded on the diff by `code-reviewer`, which
declares all nine in its `coverage:` line; the split is recorded once in
`notion-payload criteria engineering-plan`.

**Security / privacy are gated at the code, and only there.** Decide the two
reviewers **independently** (one may be in scope while the other is not); when in
doubt, spawn (fail-closed). Gate on the **actual diff, NOT the plan's claim** —
the code is where real sinks live. Spawn `security-privacy-reviewer`
only when the diff **introduces** one of these mechanical sink signals: a new
network / HTTP call, a new non-`debug` `LogSystem` interpolation, a new
persistent-storage or file write, a new platform-channel call, a new dependency,
or a `Clipboard` / `Share` sink. A diff that adds **none** — a pure removal (a
deleted egress), or a delta on an already-reviewed feature that adds no new sink
— skips the corresponding gate. Detect the signals mechanically from `git diff`
before spawning; any hit, or any ambiguity about whether a line is a sink, →
spawn (fail-closed). The removal case is the clearest skip: a diff whose content
is the *deletion* of an egress cannot introduce one.

**Neither runs on a plan — engineer or PM.** Every rule in
`review/rules/security/` is anchored to a parser sink, a credential, a
deep-link parameter or a dependency lock, and every rule in
`review/rules/privacy/` to a collection-site `file:line` or a log template. A
plan has none of them: it states a *claim* about sinks while the diff *is* the
sinks, so a plan walk grades a code checklist against prose.

**What plan stage still owes is a product decision, not a sink audit**, and it
lives in PM rule `P8` (`pm/references/rules.md`): every collected field named,
bound to a written outcome, unremovable without breaking it, at the lowest
identifiability that works, with its sensitivity tier, retention bound,
permission justification and store-declaration delta. Those are answerable from
a plan and **unanswerable from a diff** — by then the field is already flowing,
correctly, to a sink that handles it properly, and nobody asks whether it should
exist. Same structure as engineering criteria 10 and 11.

The code-stage spawn survives but stays boundary-gated: a no-new-sink or removal
diff skips it, while security and privacy each earn a spawn independently when
their boundary *is* touched.

**`feasibility-reviewer` is the downstream consumer's lens on the PM plan** —
the early-bounce gate that catches at the boundary what would otherwise surface
as a mid-flow divergence rev one or two phases later. **The PM plan is now its
only artefact**, and it runs both downstream lenses there (designer: can the
design system express this scope; engineer: are the mechanisms buildable). The
**design spec** gets the same deliverability question from
`design-plan-reviewer`, beside the usability walk on the same renders. The
engineer plan gets none — upstream coverage is `engineer-plan-reviewer` +
§Conformance + QA's spec tests + `post-qa-reviewer` on their
residue. A `critical`
(infeasible as drafted, evidence-cited) blocks until resolved; a `warning`
(deliverable but risky) goes to the founder to weigh (§Gate loop policy — neither
re-runs the whole judgment). It institutionalises the PM role's optional
riskiest-assumption consult — systematic, every plan, fresh context.


#### Re-audit a SCOPE change — not a fix

A revised plan that has not been re-audited is **not** approved, regardless of
an earlier green pass: the change is exactly where a new defect enters (a
parallel-marker second source of truth the prior pass never saw), and the
author never self-audits the rev (player ≠ referee).

**But only a scope change triggers it.** The distinction is what stops this
rule from reinstating the loop §Gate loop policy just banned:

| the body changed because… | re-audit? |
|---|---|
| the founder ruled something that changes **what is being built** | **yes** — a new judgment is owed, because the subject is new |
| a mid-flow divergence rev (§Mid-flow divergence) | **yes** — same reason |
| a finalize-round expansion adding scope | **yes** |
| **you applied a fix this gate itself raised** | **no** — that is what ②'s single verification round is for, and it is capped there |

**A gate re-judging its own fix is the loop.** ② produces a *new* judgment on
every run, so feeding it the fix it asked for manufactures the next round's
findings — the cost is superlinear in the number of findings and none of it
measures the plan. The verification round exists precisely to disposition
those fixes once; running the full gate instead is not extra rigour, it is the
same gate spending an Opus round to re-derive what it already said.

When it does fire: the ① cell to clean (`pm-plan-reviewer` loop-to-green cap 3,
or `plan_lint.sh` exit 0), then the Adversarial tier one pass + one
verification, per §Gate loop policy. Audit first, then implement, and the audit
runs *before* the user re-approves the delta, not after.

**And sweep the whole body when you rev** — that is check `I1` in
§Plan integrity, which a gate grades rather than leaving to the author's
diligence.

**The re-run is a conservative cache, not a cold replay — never a launcher
skip.** Each re-spawned gate gets its prior verdict + the diff since it; if the
diff is **disjoint from that gate's surface** it affirms ("out-of-surface, prior
verdict holds") instead of re-deriving, else it re-derives that surface + its
blast radius. Invalidation is **fail-closed** (any doubt → re-derive; a HIT is
the gate's own call, never the launcher dropping it). The ① cell is cheap —
always re-run it cold; the cache earns its keep on the Opus gates. Every gate
still signs off the whole plan.


#### After code: the implementation gates

Three **ordered** steps, not one batch:

1. **The code-stage row of the matrix** — `code-reviewer`, plus
   `security-privacy-reviewer` when the diff's own sink signals fire.
2. **The QA phase** — spawn the `qa` agent; it authors the spec-derived tests,
   the engineer role already wrote the contract-derived ones.
3. **Only then the after-QA row** — `post-qa-reviewer`, once, walking all three
   of its lenses.

**That order is load-bearing.** `post-qa-reviewer`'s conformance lens is
*residual*: it opens by listing `test/spec/` and skips every item those tests already
pin, because a permanently-failing test is stronger than a point-in-time verdict. Run it before QA and it has nothing to subtract, so it
re-derives the whole spec walk and duplicates the ratchet it was narrowed to
complement. Apply the `/review`
verdict-per-finding protocol (FIX / DISMISS-with-rationale / ESCALATE / DEFER);
every security / privacy `critical` blocks until resolved, and a `warning` goes
to the founder — neither re-runs the whole judgment (§Gate loop policy). No
silent skips.

**Every one of these six posts to the PR** — the three code-stage reviewers and
the three after-QA ones alike, findings before the fixes and dispositions after
(`review/SKILL.md §Posting findings to the PR`). A zero-finding pass posts too;
otherwise a gate that never ran and a gate that found nothing look identical from
the PR.

**Not finished until both measured gates are green.** They are the QA phase's
output rather than an opinion about it, and `qa/SKILL.md` §Iron Law 1 owns the bar:

- **`plan-coverage`** — every line the cycle changed either executed, or carrying
  `// coverage-ignore: <reason>`. Deliberately **per line, not per percent**: two
  files at 92% are not the same file when one missed a logging branch and the
  other missed the error path, and a percentage cannot express the difference.
- **`plan-mutation`** — every changed file kills its own mutants above the
  threshold the script prints on each run. A survivor is a missing case or a line
  nothing asserts; keeping one means writing why.

They **stack rather than substitute** — a line no test executes produces no
mutant, so it never survives and never appears; mutation grades what was reached,
coverage grades the reach. And neither retires `post-qa-reviewer`, which catches the
opposite error: a change-detector scores perfectly on both.

**During authoring, tests belong to the `qa` agent and you run none.** The agent
runs **only the change's blast radius**, never the bare suite, never
backgrounded-and-polled (`.claude/agents/qa.md` §Test-run discipline), and you
don't re-run on top.

Your job is to read the hand-back: the tally **and the paths it ran**. That path
list is your only view of what went uncovered — if it looks narrower than the
change (a signature / required-field edit is the classic case, where a run
scoped to the edited files compiles green and hides sibling breakage), send it
back to widen. If it hands back without a tally, don't resume it in a poll loop
— read what it already produced, or re-dispatch its scope.

#### The full-suite run — twice, on the main thread, reported to the PR

Scoped runs cannot see a cross-feature regression, and CI only runs the suite on
`push` to `main` (`.github/workflows/test.yml`) — i.e. **after** the merge, too
late to stop one. So the **main thread** runs the bare `flutter test` at exactly
two moments, both **before** the founder's merge:

1. **Engineering done, PR going up for review** — the state the founder is about
   to read.
2. **Review-driven rework that touched `test/`** — re-run, because the thing the
   first run vouched for has changed underneath it.

Rework that doesn't touch `test/` doesn't re-trigger it; the founder can always
ask for a run.

**Post the result to the PR as a comment, every time** (`gh pr comment <PR#>`),
so the founder can track it without re-running anything. Keep it short:

```markdown
## Full suite — <trigger: pre-review | rework re-run>

**5307 passed / 0 failed** · ~5 min · `<commit sha>`
```

**A failing run is posted too, with the error and the fix** — never withheld
until it's green, never softened:

```markdown
## Full suite — rework re-run

**5301 passed / 6 failed** · `<commit sha>`

### Failures
- `test/features/x/x_state_test.dart` — "emits loaded after refresh"
  `Expected: loaded / Actual: error`
  **Fix:** <what changed — or, if not yet fixed, say so and what's blocking>
```

**Report faithfully.** Post what the run actually did: a green summary is only
for a run that was actually green and actually finished. If it was aborted,
partial, or you ran a scope rather than the whole suite, the comment says that.
A known-flaky failure is still posted, named as flaky — never dropped because
"it always does that". The founder is merging off this comment; a comment that
overstates the run is worse than no comment.

> **Do NOT stop here.** Code committed + reviewed + tested *feels* like the
> finish line — it is not. Steps 5 and 6 still run: advance the Stage, then
> **close out (Step 6)**. The cycle is open until the task is `Archived`
> (Iron Law 7). This is the exact point the close-out gets dropped — keep going.

