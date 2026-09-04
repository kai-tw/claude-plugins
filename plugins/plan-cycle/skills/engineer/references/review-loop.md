# Design-quality review loop (Phase 8.5 detail)

Phase 8 confirms the plan **complies with the project's rules** —
layer direction, naming, DI scope, log calls, i18n surface. Rule
compliance is necessary but not sufficient. A plan that passes audit
can still be O(N²) on a hot path, leaky across feature boundaries,
or carry an §Error policy matrix that ticks every cell while
missing half the real failure modes.

This phase scores the plan across the reviewer's scope-gated
**design-quality** dimensions that the rule-compliance audit doesn't
cover (time/space complexity, scalability, extendability, coupling,
correctness/race, error handling, package usage, testability,
abstraction/reuse/ownership, migration). The reviewer names the
**weaknesses**; the engineer **devises the fixes**, then one verification
round confirms them — every in-scope dimension ≥ 8, or the remainder goes
to the user — before the approval gate in Phase 10. Iron Law 9 binds: this
phase is non-skippable.

## Author against the dimensions FIRST (converge to one passing review)

The reviewer is the independent gate (player ≠ referee). The goal is
**not** to remove it — you cannot grade your own blind spots away — but
to make its **first pass return `approve`**, so review converges to a
single confirming pass instead of a multi-cycle iteration loop. That
happens when the draft is authored against, *and self-scored on*, the
**same rubric the reviewer scores**. Four moves:

### 1. Scope the dimensions

Run `plan-scope-gate <plan-path>`
(advisory) to enumerate which plan dimensions are in scope and whether
the Track-2 (security/privacy plan-mode) trigger fires. Keyword
heuristic — confirm the set yourself; never *drop* a flagged dimension
because the script stayed quiet, and add any it missed.

### 2. Load the bar — the rubric is the SSOT, do not reinvent it

The criteria you author against are the **same** ones the reviewer
scores against, and they live in exactly one place:
`.claude/agents/blueprint-reviewer.md` §"Criterion 1–11" + its **Score
anchors** table. Read them there — do **not** keep a second copy in this
file (two copies drift; the reviewer owns the bar, you consume it). Each
criterion's checklist *is* your authoring target, read generatively:
"Are hot paths identified and bounded?" → identify and bound them in
§Data flow.

### 3. Know where each dimension is earned (author-side routing)

Each criterion is satisfied in a specific plan section — design for it
*there* while drafting, not retroactively. The routing table is generated
from `notion-payload` (SSOT — section `criteria` fields); run:

```
notion-payload criteria engineering-plan
```

The criteria numbers are the same ones in `blueprint-reviewer.md §Criterion N`
— that file is still the rubric SSOT (1–10 anchors, specific questions);
`notion-payload` is the routing SSOT (which section earns which dimension).

### 4. Self-score before you spawn — raise the floor, don't replace the gate

Before Step 1 below spawns the reviewer, grade your **own** draft against
each in-scope dimension using the same Score anchors: write a one-line
score + the section that earns it. **Lift anything < 8 yourself first**
— same devise-fix → research → escalate ladder as Step 3 below. Only
spawn the reviewer once your self-score clears ≥ 8 on every in-scope
dimension.

This is floor-raising, not review-replacing. A self-score cannot catch
the blind spots a fresh-context reviewer can — the context that produced
a flaw rarely detects it (the independence paradox). The reviewer stays
the gate; the self-score just stops the *obvious* lifts from costing a
whole review round-trip, so the gate's first pass **confirms** rather
than **iterates**. If your honest self-score can't reach ≥ 8 on a
dimension (and research + revision don't lift it), that is exactly the
escalate-to-user case — surface it now rather than spending the review
cycle discovering it.

### 5. Sweep the facts ledger — verify claims before the reviewer does

The self-score above grades *judgment*; it cannot catch a **false factual
claim**, because the context that wrote the claim is the context that
believes it. So before Step 1, dispatch the **claim sweep** over §事實帳:
read-only-plus-execution `general-purpose` sub-agents (`model: sonnet`; a
handful of rows per agent, batched in one dispatch), each briefed to
**refute** its rows, not confirm them. No hook reaches a sub-agent, so the
prompt is the only channel for the discipline — state it there verbatim:

- return per row: **證實**（the evidence, re-cited）/ **證偽**（the
  counter-evidence）/ **查不到**;
- for a row asserting an **absence or a count** (只／全部／沒有／從來／唯一／N
  個), re-verify with a **method different from the one the row already
  cites** — re-running the same grep re-confirms the same blind spot, not
  the claim;
- for an `實驗` row, the verbatim command + output (可重跑是實驗與軼事的
  分界); probes exercise the **real path** — faking the layer under claim
  is circular — run **side-effect-free, local only**, live in a throwaway
  location, and are **never committed**;
- the agent does not edit the plan and does not commit anything.

證偽 → fix the row **and the design decisions its 依賴 column names**,
before spawning the reviewer. A sweep returning all-證實 with zero 未讀
rows on the first pass is suspicious — reread the prose for unledgered
claims instead of celebrating.

Measured motivation: one review round's findings were entirely draft-time
-checkable facts (a wrong line ref, a formula written differently in two
places, a missed construction site) — a full opus review round spent on
what this sweep settles; reviewer-caught「宣稱既有機制已涵蓋，實查沒有」
hit 7 times in a single cycle; one unverified dartdoc sentence carried
a whole design into a cold-start bug that took a TestFlight build to
falsify; and 「`birthdayMonth` 只由一處寫」was reused as precedent for a new
design while checked by the same method twice — neither pass looked
anywhere but the one write site it already knew about.

## Step 1 — Spawn `blueprint-reviewer`

Invoke the `blueprint-reviewer` sub-agent against the drafted plan. Brief
shape (see `.claude/agents/blueprint-reviewer.md` for the full contract):

- **Plan path** — the file just authored under Phase 1–8.
- **Options to score** — "all options in the plan" by default. If
  Phase 3's §Architectural sketch enumerated alternatives, list
  them explicitly so the reviewer ranks rather than scores in
  isolation.
- **Weighting** — equal by default. The verdict gate is **per
  dimension (every in-scope dimension ≥ 8)**, not a weighted total, so
  weighting only tunes the informational summary; override only when the
  upstream product plan declares a quality emphasis.

It is report-only and does not edit source, so it is safe to run as a
blocking sub-agent call (the engineer's `Agent` tool is foreground; there
is no background-spawn surface here). Wait for its log, then act on the
weaknesses. **Keep the report's `Scores dir:` path** — Step 4 cannot run
without it.

## Step 2 — Read the verdict

When `blueprint-reviewer` returns, the review log carries:

- **Per-dimension scores** (1–10) + the plan section each is scored
  against.
- **Weaknesses** — every sub-8 dimension carries a precise, evidenced
  weakness (what's wrong + failure scenario + citation). The reviewer
  does **not** propose the fix — that's yours to devise.
- **Recommended option** (multi-option plans only) — adopt this
  as the canonical approach; the rival options drop out of the
  plan in the rev unless the user overrides.
- **Verdict** — `approve` (every in-scope dimension ≥ 8) /
  `approve-with-improvements` (some 6–7, none < 6) / `send back to
  revise` (any < 6). **Criterion 10 is the exception to the soft
  band**: a 6–7 there is not yours to quietly lift — surface it to the
  founder in Resolve terms (which unit is doubted as a second face,
  what the minimal option would delete) before revving. The reuse
  dimension is where both measured over-builds passed as "well-formed";
  the escalation, not the score, is the gate.

Treat the scores as calibration; the **weaknesses** are what you act
on — by devising and applying the fixes.

## Step 3 — Devise + apply fixes and rev the plan

If verdict is `approve` (every in-scope dimension ≥ 8): record the review
verdict in the plan header (Step 5) and proceed to Phase 9.

Otherwise, first snapshot the draft for Step 4's diff
(`cp <plan-path> <scores-dir>/plan.before.md`, `<scores-dir>` = the report's
`Scores dir:`), then for **every sub-8 dimension** (all of them — the gate is
≥ 8 each; start with the < 6 blocking weaknesses):

- **Devise the fix yourself.** You own the design; the reviewer named
  the *weakness*, not the solution. A weakness may list ≥2 unranked
  `Directions` — optional starting points, not a shortlist; picking one
  verbatim is not devising a fix. Apply your fix to the plan (the
  Notion Engineering Plan row body) by invoking the `archivist` skill (no
  Notion MCP — the launcher's Iron Law 6). **When the lift path is non-obvious, research it**
  — `WebSearch` / `WebFetch` for the canonical pattern, prior art, or
  package option — so the rev names a concrete approach, not a guess.
- If lifting a dimension would require new product or design scope (e.g.
  "add a snackbar on quota exceeded" implies a new UI affordance), do
  **not** improvise — surface it as `## Open questions` and route to
  the PM role or the designer role per the same escalation rules as Phase 11.
- **When a finding invalidates the plan's *model* — a mechanism premise, an
  architecture choice — rewrite every section that describes that model,
  never patch the one section the finding names.** Measured: a rev that
  patched one section after a model change left the others describing the
  dead model — seven self-contradictions, the rev was voided by the next
  review round. After the rewrite, `plan_lint.sh`'s closure checks verify
  the sections agree again.
- Mirror every fix into the Notion row body's `## Revision history` (via the `archivist`)
  (`Rev N: blueprint-reviewer pass — lifted <dimension> <old>→<new> via
  <fix summary>`), **naming the weakness ids it resolves** (`[5.1]`, `[7.1]`
  — the ids the round-1 report printed). Every sub-8 weakness must appear in
  some fix line or in `## Open questions` before Step 4; one that appears in
  neither is a silent skip.

Then go to Step 4 for the verification. (A `send back to revise` — any
dimension < 6 — is the same loop; the blocking weakness just must be resolved
before the re-spawn.)

## Step 4 — Verification round (the second and last spawn)

After Step 3's fixes land, re-spawn `blueprint-reviewer` **once**, as a
verification of round 1 — not a fresh review. Re-running a judgment gate
produces a new judgment (`plan/SKILL.md §Gate loop policy`): a dimension
re-derived from scratch always finds something new to say about a 6–7, and
a plan reviewed that way never closes, it just grows new findings every
fix. The brief therefore carries, in addition to Step 1's elements:

- **`--prev`: round 1's `Scores dir:` path** (from its report header);
- **the plan diff, rev N-1 → rev N** — before Step 3 touches the draft,
  snapshot it (`cp <plan-path> <scores-dir>/plan.before.md`); after, pass
  `diff -u <scores-dir>/plan.before.md <plan-path>`;
- **the line:** "verification round — carry dimensions the diff does not
  touch; disposition every prior weakness by id; tag every new one
  `diff-introduced` or `newly-observed` with `missed_because`".

Read the returned `CONVERGENCE:` ledger. Every dimension ≥ 8 → Step 5.
Otherwise **stop — no third spawn** — and surface to the user, with the
still-sub-8 weaknesses grouped **by origin**, because they are different
asks:

- **still open (`origin: prior`) / `diff-introduced`** — your fix did not
  land or broke something. Give: the weakness in plain prose, what you
  tried (including what the web research found), and the candidate routes —
  rev the product plan via the PM role (scope is the bottleneck), rev the
  design spec via the designer role (a UI gap is the bottleneck), or
  accept the sub-8 dimension (user override).
- **`newly-observed`** — the reviewer found something round 1 did not,
  with its `missed_because`. This is a *finding that changed kind*: say
  whether you read it as a genuine miss (then it is a fix the user is
  choosing to fund or defer) or as reviewer variance (then it is an
  observation the user can accept as-is). The user rules; you do not send
  it back for a tie-break round.

The user's decision lands in `## Revision history` before Phase 10's
approval gate.

## Step 5 — Record the review verdict in the plan header

In the plan's frontmatter-style block (right after `Source spec:`
or, when non-UI, after `Source plan:`), add a line:

```
Plan review: blueprint-reviewer (不落檔 — verdict returned inline)
              final verdict: <approve | approve-with-improvements>;
              every in-scope dimension ≥ 8 after <N> cycle(s)
              | escalated: <dimension> accepted at <score> by user
```

The line traces the plan back to its quality verdict so a reader
of the plan row — months from now, in a different session — can
audit calibration. The blueprint-reviewer writes no log file; the
plan header IS the durable record of the verdict. Without
it, the score evaporates; with it, the next planner can compare
against the rubric.

## What this phase does NOT do

- Does **not** re-run the rule-compliance audit (Phase 8). That
  pass is separate; `blueprint-reviewer` measures design quality, not
  rule conformance.
- Does **not** edit upstream artefacts (product plan, design spec).
  When a reviewer weakness needs upstream scope, route
  via `## Open questions` — the engineer role is not authorised to
  amend the PM role or the designer role artefacts.
- Does **not** invoke the `security-reviewer`. The reviewer scores design
  quality, not threat surface. If correctness or error handling
  surfaces a security-flavoured concern (auth boundary, secret
  handling, untrusted-input parsing), surface in `## Open
  questions` and route to the `security-reviewer` separately.
- Does **not** write tests. Test-seam findings (testability /
  correctness overlap) feed Phase 5's testing-strategy section but
  the actual test code stays with `/qa`.
