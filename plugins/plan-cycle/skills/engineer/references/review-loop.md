# Design-quality review loop (Phase 8.5 detail)

Phase 8 confirms the plan **complies with the project's rules** —
layer direction, naming, DI scope, log calls, i18n surface. Rule
compliance is necessary but not sufficient. A plan that passes audit
can still be O(N²) on a hot path, leaky across feature boundaries,
or carry an §Error policy matrix that ticks every cell while
missing half the real failure modes.

This phase reviews the plan across the reviewer's two scope-gated
**should-this-exist** dimensions — abstraction / reuse / ownership, and
migration & back-compat — the ones the diff can no longer ask about, because by
then the second face and the dead migration both exist and both look
well-formed. Everything else (time, space, scalability, extendability,
coupling, correctness/race, error handling, testability, startup) is graded on
the diff by `code-reviewer`; **package choice** is neither — `package-explorer`
returns a source-evidenced verdict and the review carries it intact rather than
re-judging it (whether the dependency should exist at all is criterion 10).
The reviewer names each
**problem and the fix it would make**; the engineer applies that fix or a
better one of its own, then one verification round confirms them — no critical
findings left, warnings applied or recorded — before the approval gate in
Phase 10. Iron Law 9 binds: this
phase is non-skippable.

## Author against the dimensions FIRST (converge to one passing review)

The reviewer is the independent gate (player ≠ referee). The goal is
**not** to remove it — you cannot grade your own blind spots away — but
to make its **first pass return `proceed` with no critical**, so review
converges to a single confirming pass instead of a multi-cycle iteration loop.
That happens when the draft is authored against, *and self-checked against*, the
**same rubric the reviewer applies**. Five moves:

### 1. Scope the dimensions

Run `plan-scope-gate <plan-path>`
(advisory) to enumerate which of the two plan dimensions are in scope.
Keyword
heuristic — confirm the set yourself; never *drop* a flagged dimension
because the script stayed quiet, and add any it missed.

### 2. Load the bar — the rubric is the SSOT, do not reinvent it

The criteria you author against are the **same** ones the reviewer
judges against, and they live in exactly one place:
`.claude/agents/engineer-plan-reviewer.md` §"Criterion 10 / 11" + its **§Severity**
table. Read them there — do **not** keep a second copy in this
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

The criteria numbers are the same ones in `engineer-plan-reviewer.md §Criterion N`
— that file is still the rubric SSOT (the severity definitions and the specific
questions per dimension);
`notion-payload` is the routing SSOT (which section earns which dimension).

### 4. Self-check before you spawn — raise the floor, don't replace the gate

Before Step 1 below spawns the reviewer, judge your **own** draft against each
in-scope dimension with the same §Severity table — one line per dimension: what
would a hostile reader call critical here, and what would they call a warning?
**Fix anything you would call critical yourself first** — same fix → research →
escalate ladder as Step 3 below. Only spawn the reviewer once you cannot name a
critical of your own.

This is floor-raising, not review-replacing. A self-check cannot catch
the blind spots a fresh-context reviewer can — the context that produced
a flaw rarely detects it (the independence paradox). The reviewer stays
the gate; the self-check just stops the *obvious* fixes from costing a
whole review round-trip, so the gate's first pass **confirms** rather
than **iterates**. If you can name a critical of your own that research and
revision do not clear, that is exactly the escalate-to-user case — surface it now rather than spending the review
cycle discovering it.

### 5. Sweep the facts ledger — verify claims before the reviewer does

The self-check above grades *judgment*; it cannot catch a **false factual
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

## Step 1 — Spawn `engineer-plan-reviewer`

Invoke the `engineer-plan-reviewer` sub-agent against the drafted plan. Brief
shape (see `.claude/agents/engineer-plan-reviewer.md` for the full contract):

- **Plan path** — the file just authored under Phase 1–8.
- **Options to review** — "all options in the plan" by default. If
  Phase 3's §Architectural sketch enumerated alternatives, list
  them explicitly so the reviewer ranks them against each other rather than
  judging each in isolation.

It is report-only and does not edit source, so it is safe to run as a
blocking sub-agent call (the engineer's `Agent` tool is foreground; there
is no background-spawn surface here). Wait for its log, then act on the
findings. **Keep the report's `Round JSON:` path** — Step 4 cannot run
without it.

## Step 2 — Read the verdict

When `engineer-plan-reviewer` returns, the review log carries:

- **Findings by severity** (critical · warning · suggestion) + the plan
  section each is grounded in.
- **A `Fix:` on every finding** — the one the reviewer would make, alongside
  the problem (what's wrong + failure scenario + citation). Applying it is a
  perfectly good answer; you own the design and may override it.
- **Recommended option** (multi-option plans only) — adopt this
  as the canonical approach; the rival options drop out of the
  plan in the rev unless the user overrides.
- **Verdict** — `blocked` (one or more `critical`) or `proceed` (none).
  Nothing else blocks: not a count of warnings, not a dimension that "could be
  stronger". **Criterion 10 is the one escalation**: a `warning` there is not
  yours to quietly accept — surface it to the founder in Resolve terms (which
  unit is doubted as a second face, what the minimal option would delete)
  before revving. The reuse dimension is where both measured over-builds passed
  as "well-formed"; the escalation, not another round, is the gate.

The **findings** are what you act on — by applying each `Fix:`, or a better one
of your own.

## Step 3 — Apply the fixes and rev the plan

If the verdict is `proceed` and there is nothing you are applying, there is
nothing for Step 4 to verify: record the review verdict in the plan header
(Step 5) and proceed to Phase 9.

Otherwise, first snapshot the draft for Step 4's diff
(`cp <plan-path> "$(mktemp -d)/plan.before.md"` — keep that path), then work the
findings — **every `critical` first, because those block; then the warnings;
then whichever suggestions you take**:

- **Take the reviewer's `Fix:` or beat it.** Each finding arrives with the fix
  the reviewer would make. Applying it verbatim is a perfectly good answer and
  usually the fastest one — you own the design, so override it when you see
  better, but you owe no argument for agreeing. Apply the fix to the plan (the
  Notion Engineering Plan row body) by invoking the `archivist` skill (no
  Notion MCP — the launcher's Iron Law 6). **When the fix path is non-obvious, research it**
  — `WebSearch` / `WebFetch` for the canonical pattern, prior art, or
  package option — so the rev names a concrete approach, not a guess.
- If a fix would require new product or design scope (e.g.
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
  (`Rev N: engineer-plan-reviewer pass — resolved <severity> <dimension> via
  <fix summary>`), **naming the finding ids it resolves** (`[10.1]`, `[11.2]`
  — the ids the round-1 report printed). Every critical and every warning must
  appear in some fix line, in one §Accepted line, or in `## Open questions`
  before Step 4; one that appears in none is a silent skip.

Then go to Step 4 for the verification. A `blocked` verdict is the same loop —
the criticals just have to be resolved before the re-spawn.

## Step 4 — Verification round (the second and last spawn)

After Step 3's fixes land, re-spawn `engineer-plan-reviewer` **once**, as a
verification of round 1 — not a fresh review. Re-running a judgment gate
produces a new judgment (`plan/SKILL.md §Gate loop policy`): a dimension
re-derived from scratch always finds one more thing to say, and
a plan reviewed that way never closes, it just grows new findings every
fix. The brief therefore carries, in addition to Step 1's elements:

- **`--prev`: round 1's `Round JSON:` path** (from its report header);
- **the plan diff, rev N-1 → rev N** — `diff -u <the Step 3 snapshot>
  <plan-path>`;
- **the line:** "verification round — carry dimensions the diff does not
  touch; disposition every prior finding by id; tag every new one
  `diff-introduced` or `newly-observed` with `missed_because`".

Read the returned `CONVERGENCE` ledger. Verdict `proceed` → Step 5.
Otherwise **stop — no third spawn** — and surface to the user, with what is
still open grouped **by origin**, because they are different
asks:

- **still open (`origin: prior`) / `diff-introduced`** — your fix did not
  land or broke something. Give: the finding in plain prose, what you
  tried (including what the web research found), and the candidate routes —
  rev the product plan via the PM role (scope is the bottleneck), rev the
  design spec via the designer role (a UI gap is the bottleneck), or
  accept it as debt (user override).
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
Plan review: engineer-plan-reviewer (不落檔 — verdict returned inline)
              final verdict: proceed; no critical findings after <N> round(s)
              | accepted: <dimension> <finding id> carried as debt by user
```

The line traces the plan back to its quality verdict so a reader
of the plan row — months from now, in a different session — can
audit calibration. The engineer-plan-reviewer writes no log file; the
plan header IS the durable record of the verdict. Without
it, the verdict evaporates; with it, the next planner can compare
against the rubric.

## What this phase does NOT do

- Does **not** re-run the rule-compliance audit (Phase 8). That
  pass is separate; `engineer-plan-reviewer` measures design quality, not
  rule conformance.
- Does **not** edit upstream artefacts (product plan, design spec).
  When a reviewer finding needs upstream scope, route
  via `## Open questions` — the engineer role is not authorised to
  amend the PM role or the designer role artefacts.
- Does **not** invoke the `security-reviewer` — and neither does any other part
  of the engineer phase. Security and privacy read the **diff's** real sinks,
  not a plan's claim about them, so their spawn is at the code stage
  (`plan/SKILL.md` §audit matrix). A security-flavoured concern that surfaces
  while drafting (auth boundary, secret handling, untrusted-input parsing) is
  still worth writing into `## Open questions` — it briefs the code-stage gate
  and, when it is really a *mechanism* question, routes back to the PM role.
- Does **not** write tests. Test-seam findings (testability /
  correctness overlap) feed Phase 5's testing-strategy section but
  the actual test code stays with `/qa`.
