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
**weaknesses**; the engineer **devises the fixes** and iterates until
every in-scope dimension is ≥ 8, before the user is asked to approve in
Phase 10. Iron Law 9 binds: this phase is non-skippable.

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
hit 7 times in a single cycle; and one unverified dartdoc sentence carried
a whole design into a cold-start bug that took a TestFlight build to
falsify.

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
weaknesses.

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
  revise` (any < 6).

Treat the scores as calibration; the **weaknesses** are what you act
on — by devising and applying the fixes.

## Step 3 — Devise + apply fixes and rev the plan

If verdict is `approve` (every in-scope dimension ≥ 8): record the review
verdict in the plan header (Step 5) and proceed to Phase 9.

Otherwise, for **every sub-8 dimension** (all of them — the gate is
≥ 8 each; start with the < 6 blocking weaknesses):

- **Devise the fix yourself.** You own the design; the reviewer named
  the *weakness*, not the solution. Apply your fix to the plan (the
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
  <fix summary>`).

Then go to Step 4 for the re-review. (A `send back to revise` — any dimension
< 6 — is the same loop; the blocking weakness just must be resolved
before the re-spawn.)

## Step 4 — Re-spawn the reviewer (cap = 2 cycles)

After Step 3's fixes land, re-spawn `blueprint-reviewer` against the
revised plan to confirm every dimension now scores ≥ 8. The cap is
**2 review cycles total** — initial pass + one re-review. The cap
exists because:

- 1 cycle = scored only, no iteration; useful but not what Iron
  Law 9 demands.
- 2 cycles = devise-fix + verify; the productive case.
- 3+ cycles = the reviewer disagreeing with itself, or a dimension
  that can't be lifted inline; escalate to the user rather than loop.

If, after research **and** manual revision, the re-review still leaves
any dimension < 8:

- **Stop iterating.** Don't run a third cycle.
- Surface to the user with: (a) the latest review verdict (the
  blueprint-reviewer's inline return); (b) the
  unliftable dimension(s) + their weakness in plain prose, and what you
  tried (including what the web research found); (c) the candidate
  routes — rev the product plan via the PM role (when scope is the
  bottleneck), rev the design spec via the designer role (when a UI gap is the
  bottleneck), or explicitly accept the sub-8 dimension (user override,
  recorded in `## Revision history`).
- The user's decision lands in `## Revision history` before Phase 10's
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
