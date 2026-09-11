---
name: plan
description: >-
  Codebase GUARDIAN and SINGLE entry for any task or code change: gates
  non-trivial work behind an approved product → design → engineering plan
  trail, and is the ONLY creator of a feature's TaskList task. Approvals:
  MECHANISM → PM, SCREEN → designer, CODE → engineer.
  TRIGGER: plan · planning · implement X · build/add a feature · new
  feature/screen/page/flow/system · redesign · refactor with scope change ·
  improve X · roadmap · scope · should we build X · is this in scope · ship X ·
  one-pager · PRD · PR-FAQ · product plan · frame the problem · discovery brief
  · opportunity tree · strategy memo · design spec · wireframe · responsive
  layout · lay out X · M3 spec · breakpoint behavior · render the mockups ·
  engineering plan · eng plan · architect X · implementation plan · task list
  for X · phased rollout · amend/rev the plan · scope/design/engineering ruling
  · 規劃 · 新增功能 · 新功能 · 新畫面 · 新頁面 · 新流程 · 新系統 · 改版 ·
  重構並擴張範圍 · 範圍 · scope 怎麼定 · 要不要做 X · X 的計畫 · 一頁式 ·
  產品計畫 · 這解決什麼問題 · 設計 X · 畫 wireframe · 響應式版面 · 斷點行為 ·
  產示意圖 · 出示意圖 · 工程計畫 · 技術計畫 · 實作計畫 · 架構 X · 拆 task
  Over-trigger rather than under-trigger — a false negative ships work with no
  plan.
  NOT for: typo / lint / isolated bug fixes (→ /bug-investigate) and
  behavior-preserving refactors — answer "exempt — proceeding without plan" and
  continue · test code → /qa · ad-hoc review → /review · freehand mockups off
  the design system · the format gate (Stop hook owns `dart format`; the Dart
  lint is the engineer commit gate).
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
  - SendUserFile
  - Artifact
  - EnterWorktree
  - ExitWorktree
  - TaskCreate
  - TaskUpdate
  - TaskList
---

# Planning — guardian + orchestrator

`/plan` is the **single guardian entry** for this project. Any task or code
change reports here first. It does two jobs:

1. **Guard** — it stands between intent and implementation, exempts obviously
   trivial work at a glance, and is the **only** creator of a feature's
   TaskList task.
2. **Orchestrate** — for non-trivial work it runs the authoring phases itself,
   **in the main thread**, invoking each role skill in-context along a fixed DAG
   (PM → designer → translator → engineer → code → QA → close-out, with
   security / privacy cross-cutting), drives the co-creation round with the user,
   and advances the task.

The main thread **is** the author of every plan, spec, and test — it runs each
role's contract (`pm` / `designer` / `engineer` / `qa`) in-context and asks the
user directly. It spawns **isolated sub-agents only for the gates that must stay
independent** — the review roles (`engineer-plan-reviewer` /
security / privacy / `code-reviewer`, so the referee never grades the player) and
`translator`. Notion writes go through the `archivist` skill, also run in-thread.
`/plan` and `/review` **share one review sub-agent pool** — `/review` is the
standalone entry to the same review agents this launcher spawns in-flow.

## The three approval principles (the guardian's essence)

> These bind every cycle. Nothing ships that violates one.
>
> - **Any MECHANISM change is approved by the PM role.** New / changed online
>   behavior, data flow, permission boundary, or telemetry needs a PM plan the
>   user approved.
> - **Any SCREEN change is approved by the designer role.** Any user-visible
>   surface — down to a token tweak — needs a design spec the user approved.
> - **Any CODE change is approved by the engineer role.** No line of code lands
>   without an engineering plan the user approved.

A change that touches a mechanism *and* a screen *and* code needs all three,
in that order.

## Iron Laws

> Break any one and the gate is invalid. (Each spawned role carries its own Iron
> Laws governing how that artifact is authored.)
>
> 1. **Every non-trivial implementation traces to an approved product plan** — a
>    **Product Plan DB row linked to the feature's TaskList task**. The plan
>    defines the problem, target user, success metric, scope, and non-goals.
>    Code must not invent product scope.
> 2. **Every UI-producing implementation traces to an approved design** — the
>    shipped `*.design.dart` widgets plus the **contact sheet the task's
>    `Design Sheet` points at**. The widgets define the layout per `WindowSize`
>    breakpoint, the components and the tokens; each one's contract defines the
>    four states (default, empty, loading, error) and what enters them. Code must
>    not invent UI.
> 3. **Every non-trivial implementation has an engineering plan** approved before
>    the first line of code. It converts product/design artifacts into concrete
>    affected layers, class / interface sketches, data flow, migration impact,
>    testing strategy, and risk. It lives as a row in the **Engineering Plan DB
>    linked to the task**, paired with a TaskCreate task list (task list =
>    canonical for live status; row body = canonical for content).
> 4. **The diff cites the full trail** — the Notion task URL (reaching the
>    Product / Design / Engineering Plan rows) in the PR description or commit
>    message. Versioned trail or it didn't happen.
> 5. **Code touching a file is brought into compliance with all rules in
>    `.claude/rules/`** as part of the same change. Pre-existing violations stop
>    being exempt once the file is re-touched.
> 6. **Every plan finalize or rev is uploaded to Notion immediately.** The
>    moment you finalize (or rev) a plan in-thread, invoke the `archivist` skill
>    to write it to the matching Notion DB row. Never leave a plan that exists
>    only as a local draft or an in-chat message — a plan not in Notion does not
>    exist.
> 7. **A cycle is not done until it is closed out.** Close-out (Step 6) **deletes** the task —
>    `ntn pages trash` the task row, irrespective of its Status / Stage. A task
>    left **undeleted** (at any Status / Stage) without running Step 6 is an
>    **unfinished cycle**, not a completed one. This is the **single most common silent skip** — once code is
>    committed + reviewed the work *feels* done and the archive gets dropped.
>    The cycle is closed **only** when the closing report cites the Feature
>    Archive row URL + the **trashed task row (verified gone)** (see §Closing report). No
>    Close-out citation → the cycle is still open; do not stop. **Deterministically
>    backed:** once the PR recorded at Step 6.0 lands on the base, the Stop-hook
>    close-out gate (Gate 2) blocks turn-end until `clear` — so the common drop
>    (PR merged, archive dropped) can't pass silently. It arms on the **merge**,
>    not the PR opening: before the merge there is nothing to archive.
> 8. **The task's Status and Stage track the work in real time — never
>    batched.** The moment the cycle begins active authoring (the first phase
>    spawns), flip **`Status`** `Next`/`Backlog` → **`In Progress`**; it stays
>    `In Progress` for the whole cycle until close-out trashes the task. A task
>    being actively worked must never still read `Next`. **`Stage`** must always
>    name the phase you are *in right now*, not the
>    last one that finished: advance it the moment a phase **begins** (entering
>    designer → `Design Plan`; translator → `Translation`; engineer →
>    `Engineering Plan`; a cross-cutting review loop → `Security`/`Privacy`;
>    implementation → `Implementation`; code/QA → `Review`/`QA`). Deferring
>    Stage to "later" / the end of the cycle is forbidden — a board that
>    reads `Translation` while the engineer plan is already drafted-and-audited
>    is a lie about where the work is. **The moment you notice the Stage
>    lagging reality, invoke the `archivist` skill to reconcile it before doing
>    anything else.**
>
>    **The plan row's content is a single write, at Finalize** — after both gate
>    tiers are clean *and* the co-creation Resolve step has settled every
>    open question with the user (§Co-creation round Step 5), never before and
>    never batched to "later" either. A finalized plan not yet in Notion does
>    not exist (Iron Law 6). A Resolve conversation that runs long enough to
>    risk a session boundary or context compaction before Finalize is the
>    `session-journal` skill's job (record which plan is in flight and what's
>    still open) — not a reason to write a half-negotiated body to Notion
>    early; a "Draft" row the user hasn't actually approved yet is its own kind
>    of lie about where the work is.
> 9. **Every significant app-code-bearing cycle runs in an isolated worktree and
>    ships as a PR.** A full `/plan` code cycle is significant by construction (it
>    cleared the Step 1 exempt gate) → it **always** worktrees: enter it
>    (§Worktree isolation) *before* the first phase that writes app code
>    (translator / code / QA); close-out pushes the branch + opens the PR (Step
>    6). Writing a planned code cycle's app code in the main tree — or merging it
>    without a PR — is a flow violation, the same class of silent skip as a
>    dropped close-out (Law 7). Outside a full cycle (a `/plan`-exempt fix, or an
>    ad-hoc edit with no phases), the worktree is required only when the change is
>    **significant** — large scope or functional (root `CLAUDE.md §Worktree +
>    PR`); trivial mechanical edits stay in the main tree. When unsure, worktree.

## Upload enforcement (the cycle ledger + Stop-hook gate)

Iron Laws 6 + 8 decay over a long cycle: once this SKILL.md scrolls out of the
active context (or is summarized), the upload habit is the first thing dropped —
the plan gets authored in-chat and the Notion write is silently skipped. Prose
cannot fix a context-persistence problem, so a **deterministic gate** backs the
laws up the same way a project's own Stop hook backs up its formatter and build:

- **A local cycle ledger** (the `plan-cycle` command, a per-session,
  gitignored file in the main tree — so multi-opened sessions never cross-block)
  mirrors the Notion writes of this cycle. It is maintained as a
  **byproduct of the `archivist` calls you already make** — task-create →
  `start`, Stage flip → `enter`, plan-row write → `uploaded`, close-out (task
  trashed) → `clear` — plus the launcher's own `pr-opened` at Step 6.0 (archivist
  owns the rest; see its §Plan-cycle ledger). You add
  **no** new step: keep invoking `archivist` at each Notion moment and the ledger
  stays current on its own.
- **The plugin's Stop hook blocks turn-end** on any of the ledger's gates — a
  plan phase advanced past without its Notion row, a merged PR never closed out,
  unreviewed commits piling up, a `// review-dismiss:` that fails its own rule, a
  frozen test edited without a reason, and **a PR opened whose tests were never
  graded for strength (`plan-qa-report`)**. The gates and their exact conditions
  are defined once, in `bin/plan-cycle` — never restated here, because a copy
  drifts and this one already had. The block reason names the gap and is fed
  back as your next input; doing the named thing clears it.

**If a turn-end is blocked by the "Plan-cycle upload gate":** that is this gate
firing — the named plan exists only in chat. Invoke `archivist` to upload it
(linked to the task) and confirm it landed, then continue; the gate clears
itself. Do not work around it. The gate proves Iron Law 6 mechanically — so the
habit no longer depends on remembering it.

## Launcher flow (the six steps)

```
request to change code / open a task
        │  (guardian: everything reports here first)
        ▼
  1. quick exempt check  ──(exempt)──▶ proceed, no task, no phases
  2. ensure the TaskList task exists   (only task-creator; via archivist)
  3. analyze the task → decide which phases to open
  4. run each phase along the DAG — author in-thread, spawn the review gates
  5. keep the task's Stage + plan rows in sync continuously (Iron Law 6 + 8)
  6. close out → Feature Archive + trash the task row → tell the user
```

**One invocation runs to the PR.** The user has exactly two turns: **plan
approval** (§Co-creation round Step 3) and **a decision** (§Two interaction
rules rule 1). Everything else is yours to carry — a phase boundary, a green
gate, a passed commit gate are **not** user turns: report in one line and open
the next.

### Step 1 — Quick exempt check (guardian at the door)

**Read `${CLAUDE_PLUGIN_ROOT}/skills/plan/blocks/exempt-check.md` and follow
it.** It owns the exempt list, the two shapes that look like a bug fix and are
not, the worktree-runs-on-significance rule, the usage baseline, and the
phase-opening criteria. Nothing about them is restated here.

It returns `triage`: exempt, or which flow to run and which phases have work.
**Exempt ends here** — no task, no phases, no Notion trail, spawn nothing.

### Step 2 — Ensure the feature's TaskList task exists (only task-creator)

**Read `${CLAUDE_PLUGIN_ROOT}/skills/plan/blocks/task-anchor.md` and follow
it.** It owns the one-anchor rule, the sibling case, the GitHub issue opened
alongside, and the who-owns-what split between Notion and the issue.

`/plan` is the sole task-creator. The block returns `task-anchor`; carry it
through the cycle.


### Step 3 — Pick the flow

`triage` (Step 1) already named it. Confirm the topology from the contract
rather than from memory — the node set changes when a block is added:

```bash
plan-flow show --flow <standard-dev|code-only>
```

| the change | flow |
|---|---|
| produces or alters any user-visible surface | `standard-dev` |
| no user-visible surface | `code-only` |

Non-UI work skips designer + translator, **not** the engineer phase. Security /
privacy are not standalone phases — they are gates inside the PM, engineer and
code stages (see the audit matrix), boundary-gated at the code stage on the
diff's own sink signals.

Any flow with a repo-writing node runs in an isolated worktree
(§Worktree isolation, Iron Law 9) — mandatory, not optional.

### Step 3.5 — Single-session or team? Decide per phase, from two reads

This skill was written when one session ran every phase in order. It still does
that, **unless another session is already holding a phase** — and running a
phase someone else holds is not a slow path, it is two plans for one feature
that diverge silently.

Two reads, neither of them a guess:

```bash
plan-cycle roster --json      # who DECLARED a role, by joining
```
…then `ListAgents` for **liveness**. A member is real only if it is in both: the
roster says who joined, and only the listing says who is still running.

| what the two reads say | this phase |
|---|---|
| `{"joined": false}` — no cycle | **run it here.** Single-session mode, everything below unchanged. |
| a live member holds the role | **do not run it.** It is theirs. Ask them for it and wait for the hand-back. |
| a member holds it but is NOT in the listing | **unheld** — its session ended. Say so before touching it; a dead member's phase is a founder-facing fact, not a gap to quietly absorb. |
| the cycle exists and nobody holds the role | **run it here**, and say in the hand-back that you did — the roster does not know, and the lead is reporting from the roster. |

Do this **per phase**, not once for the cycle. A cycle with an engineer session
and no designer is normal, and its designer phase is yours while its engineer
phase is not.

**If you are yourself a member** (your session id is in `members`), run only
your own role's phase regardless of the table above. The other phases are not
yours to open even when they are unheld — report them to the lead instead.

### Step 4 — Run each phase along the DAG (author in-thread, spawn the review gates)

Authoring main sequence (fixed order, non-overlapping):

```
┌─ ONE round ──────────────────────────────────────────┐
│ PM plan draft → [① ENTER WORKTREE] → designer:       │ → engineer plan (own round)
│   translator ⇄ build widgets → render                 │ → code → QA
│   → Sanity → Resolve → Adversarial                    │ →[② push+PR]→ close-out
└──────────────────────────────────────────────────────┘

① Mandatory node for any app-code-bearing cycle (Iron Law 9): enter the worktree
  immediately before the FIRST phase that writes repo files — **the designer
  phase** when UI is in scope (it ships the widgets), else `translator` if i18n
  is in scope, else `code` (§Worktree isolation).
② Close-out (Step 6) pushes the branch + opens the PR, then `ExitWorktree keep`.
```

- **PM and designer share ONE round.** Both artifacts stay separate documents
  (separate DB rows, separate rules checklists, `feasibility-reviewer`
  still reviews the PM plan while the designer hasn't started) — what merges is
  the **round**: draft both back-to-back, gate both in one Sanity batch, take
  **one** Resolve pass to the founder, run **one** Adversarial battery, finalize
  both. A non-UI cycle simply has no designer half and the round degenerates to
  the PM plan alone; a pure-restyle cycle degenerates the other way. Split, the
  second battery routinely graded a draft the first round's answers were about to
  invalidate.
- **Translation runs INSIDE the designer phase, always before the render.**
  `translator` still owns the whole ARB string (keys, the `app_en.arb` source
  value, all four translations; ja / zh_Hant still need founder sign-off) — what
  changed is only when it runs. Renders that show real copy are the point:
  fabricated placeholder text hides exactly what a render exists to expose (a CJK
  string that wraps, a long locale that overflows), and the founder signs off on
  the copy **seeing it in place** rather than as a list of strings. **New copy
  runs it before the widgets are built**, because a project that lints
  "user-facing strings go through `AppLocalizations`" leaves no legal way to
  build first — a literal is a knowing violation and an ungenerated getter does
  not compile (`designer` §Phase 6.5). The engineer phase only wires ICU +
  `gen-l10n` + the call sites.
- The engineer plan runs its **own** round (same three stages), because it is
  downstream of translator in the DAG and its scope depends on what shipped
  upstream.
- **Security / privacy are cross-cutting reviewers, boundary-gated everywhere.**
  They intervene at **two** points — the PM plan (mechanism attack surface +
  telemetry / data minimization: *should this exist at all*) and the code
  (sinks: *is it built right*) — and at **both** the spawn is gated on the
  artifact actually touching that boundary (see the audit-matrix note). There is
  deliberately no engineer-plan spawn: a plan's threat model and data flow are
  the plan's *claim* about sinks, and the diff is where the sinks are. The
  **designer plan does not run security / privacy by default** (a
  screen layer rarely adds collection or attack surface). If a design introduces
  a new data display / collection interaction, route back to the **PM role** to
  add the mechanism decision, then let security / privacy review it.
- **`design-plan-reviewer` is the designer plan's whole judgment gate**, and it
  walks two lenses in one pass: **usability** (a cognitive walkthrough +
  heuristic sweep — a spec can pass the designer *rules* of M3 tokens,
  breakpoints and four states and still confuse a first-time user) and
  **deliverability** (can the project's UI stack actually build these layouts,
  motions and interactions — the downstream engineer's lens). One gate walks
  both because the defect that matters most sits between them: a control the
  user cannot reach *because* the stack cannot render it there is one finding,
  not half a finding in each of two reports. A `critical` from either lens **blocks until
  resolved** — an objective usability defect (a dead-end state, an unreachable
  primary control, an unconfirmed destructive action, a silent action), or
  infeasible-as-drafted with a cited source; a `warning` (a friction trade-off,
  or deliverable-but-risky) goes to the founder to weigh.
  Neither re-runs the whole judgment (§Gate loop policy). It right-sizes itself to the design's scope
  — you needn't set a tier: a net-new navigation model / multi-step flow triggers
  its `deep` multi-persona fan-out (first-time / a11y / locale / power), a localized
  screen tweak stays `light`. Force `deep` / `light` only if you know more than the
  spec's scope shows.

#### Gates — the matrix, the tiers, and how they stop

**Read `${CLAUDE_PLUGIN_ROOT}/skills/plan/gates.md`.** It owns the audit matrix
(which gate runs in which tier), the gate loop policy, the re-audit rule, the
ordered implementation gates after code, and the two full-suite runs.

The two things you need before opening it:

- **① Sanity is cheap and runs before Resolve; ② Adversarial is judgment and
  runs after.** A founder decision arriving after the battery invalidates a
  clean pass.
- **① loops to green (cap 3). ② never loops to green** — one pass, then one
  verification scoped to what changed. `critical` blocks; `warning` goes to the
  founder.

#### Co-creation round (per authoring phase; PM + designer share one)

**Read `${CLAUDE_PLUGIN_ROOT}/skills/plan/co-creation.md`.** It owns the five
steps and the two interaction rules that bind here and in every authoring phase.

The shape, so you can route without opening it: **Draft → ① Sanity → Resolve →
② Adversarial → Finalize**, and **the founder appears exactly once** (Resolve).
Everything else is yours to carry.

#### Plan integrity (I1 · I2 · I3 · I4)

**Read `${CLAUDE_PLUGIN_ROOT}/skills/plan/plan-integrity.md`.** It owns the four
constraints that bind every plan body regardless of author, and the rules for
revving a cycle that started under an older plan shape.

They are **drafting constraints first** — honour them while writing, rather than
leaving them to the gate that grades them.

#### Worktree isolation (the file-writing boundary)

**Read `${CLAUDE_PLUGIN_ROOT}/skills/plan/worktree.md` before the first phase
that writes repo files.** It owns the local/cloud split, the base preflight, the
capture, the naming, the sub-agent cwd trap, and the merge-aware teardown.

Create it immediately before the **first repo-writing node** — the designer
phase when UI is in scope, else `translator` if i18n is, else `implement`.

#### After code, and the full-suite runs

Both live in `${CLAUDE_PLUGIN_ROOT}/skills/plan/gates.md` — the three **ordered**
implementation gates (code-stage row → QA → after-QA row, and that order is
load-bearing), the two measured gates that must be green, and the two bare
`flutter test` runs the main thread owns.

### Step 5 — Keep the task's live status in sync (every phase, both edges)

Status tracking is **continuous, not end-of-cycle** (Iron Law 8). The launcher
never writes Notion directly — every write goes through the `archivist` — but it
invokes the `archivist` skill to reconcile status at **each** of these moments,
not just once at the end:

- **On phase entry** — the instant you begin a phase, advance **Stage** to it
  (Product Plan → Design Plan → Translation → Engineering Plan → Security /
  Privacy → Implementation → Review / QA → …). Do this *before* spawning that
  phase's authoring/review agent, so the board shows where the work *is*.
- **On entry to the first app-code-writing phase** (translator if i18n is in
  scope, else `code`) — **create the worktree before spawning that phase**
  (§Worktree isolation, Iron Law 9). This edge is as mandatory as advancing the
  Stage: a code-bearing cycle that has reached translator / code while still in
  the main tree has already skipped it — stop and enter the worktree first.
- **On finalize** — author the plan row (its one and only content write —
  §Co-creation round Step 5) and re-confirm the Stage.
- **During a long Resolve** — if the co-creation back-and-forth risks running
  past a session boundary or a context compaction before Finalize, use the
  `session-journal` skill to record the in-flight draft's state (which plan,
  which open questions remain). This is **not** a Notion write — the plan row
  still doesn't exist until Finalize; it's how the *conversation* survives
  long enough to reach it.
- **On each implementation phase landing** — check its `- [ ]` box in the task
  body's `## Implementation` checklist (see `/archivist` §Progress tracking).

If at any point the Stage or a plan row does not match the current situation,
reconciling it is the **next** action — ahead of advancing the work.

### Step 6 — Close out

Three blocks, and the order is not a preference:

| | block | when |
|---|---|---|
| **6.0** | `ship` | after the commit gate — push, open the PR, grade the tests, then **stop** |
| **6.1+** | `close-out` | **after the merge lands**, never at PR-open |
| **6.7** | `retro` | after close-out, every cycle |

**Read the block before running it.** Each owns its own steps, and `close-out`
owns why the wait for the merge is load-bearing.

**The founder merges, not you.** Step 6.0 opens the PR with the full-suite
report already on it; pressing the button stays theirs.

The cycle is **not done** until `close-out` has cited the Feature Archive row
and the verified-trashed task row (Iron Law 7).

**A phased feature merges more than once.** When a merged PR shipped one phase
and the task is genuinely still `In Progress`, close-out is not owed yet —
archiving a non-terminal cycle is forbidden (`archivist` Iron Law 1). Run
`plan-cycle phase-done` instead: it records the shipped PR, re-arms the per-PR
gates for the next phase, and leaves the task row alone. Close out on the last
phase.


## Mid-flow divergence

If during implementation an artifact turns out wrong, incomplete, or infeasible:
do **not** silently ship a different product / UI / architecture. Stop and
re-author through the right role (per the three approval principles): product
scope → re-run `pm`; UI → re-run `designer`; engineering decision →
re-run `engineer` (its Phase 11 handles divergence). **Re-run the matrix gates on
the rev'd plan *before* implementation resumes** — per §Gate loop policy
(`plan/gates.md` §Re-audit a SCOPE change — a divergence rev is one). Re-request user approval for the
delta, and re-upload to Notion (Iron Law 6). Read
`${CLAUDE_PLUGIN_ROOT}/skills/plan/divergence.md` for the exact procedure.

## Process retro (the subtraction channel)

The `retro` block owns it — read
`${CLAUDE_PLUGIN_ROOT}/skills/plan/blocks/retro.md`. One `process` entry per
cycle, and it is where the mandatory subtraction candidate is named.


## Citation in the diff

The diff cites the trail = the **Notion task URL** in the PR body / commit
message (it links the Product / Design / Engineering Plan rows, so the trail is
recoverable from `git log` alone), plus **`Fixes #<issue>`** so the git side
closes itself on merge. Mechanics — IL4 + Step 6.0's `gh pr create
--base "$BASE"` + `artifacts.md §Citation`; don't restate them here.

## Role pool + how each runs

Two execution mechanisms:

- **In-thread skills** the main thread invokes **via the Skill tool** and runs
  **in its own context** (no isolation) — the authoring roles (`pm` / `designer`
  / `engineer`) and the Notion-write gateway (`archivist`). The main thread
  executes their contract inline and asks the user directly; they run on the
  **session model**. (`archivist`'s skill body stays in-thread but delegates its
  bulky MCP I/O sub-transactions to disposable workers — §Reading.)
- **Isolated sub-agents** spawned **via the Agent tool** (shared with `/review`)
  — the review / audit roles, `translator`, and the test-author (`qa`); they run
  in a fresh context (player ≠ referee) and read `review/rules/` (reviewers) or
  their own skill / contract. `qa` has a dual face: the `/qa` skill is its
  direct-entry gateway + contract, but its execution (read source → design →
  write → run → iterate, with the bulky `flutter test` output) runs in the
  isolated `qa` agent so that transient never persists in the caller's context.

| Role | Contract it follows | Exec / model |
|---|---|---|
| `pm` | `skills/pm/SKILL.md` | Skill (in-thread) / session |
| `designer` | `skills/designer/SKILL.md` | Skill (in-thread) / session |
| `engineer` | `skills/engineer/SKILL.md` | Skill (in-thread) / session |
| `translator` | `lib/i18n/CLAUDE.md` ownership split | Agent / sonnet |
| `qa` | `${CLAUDE_PLUGIN_ROOT}/skills/qa/SKILL.md` (+ `agents/qa.md`) | Agent / sonnet |
| `pm-plan-reviewer` | the PM plan (`pm/references/rules.md` + plan integrity) | Agent / sonnet |
| `engineer-plan-reviewer` | the engineering plan (scope-gated dimensions) | Agent / opus |
| `security-privacy-reviewer` | `review/rules/security/` + `review/rules/privacy/` | Agent / opus |
| `code-reviewer` | the diff | Agent / opus |
| `post-qa-reviewer` | the approved plans + the siblings + `/qa`'s contract, on the diff | Agent / opus |
| `feasibility-reviewer` | the PM plan vs downstream deliverability | Agent / opus |
| `design-plan-reviewer` | the design spec: `review/rules/ux/` + the UI stack | Agent / opus |
| `archivist` | `${CLAUDE_PLUGIN_ROOT}/skills/archivist/SKILL.md` | Skill (in-thread) / session |

### Model tiering

**Every sub-agent dispatch pins `model:` explicitly, matched to the task's
nature — never inherited from the session model for mechanical work:**
`haiku` = pure mechanical collection (list / read / bulk fetch), `sonnet` =
bounded recon or pattern work (grep sweeps, call-chain tracing,
fact-checks), `opus` = judgment (authoring, adversarial review, synthesis).
Pinning happens **at dispatch**; an agent definition's `model:` is only a
default for callers that don't. **A pass that has to judge whether a *fix's
reasoning* holds, not merely whether the fix is present, is `opus`** —
`plan/gates.md` §Green is not proof.
This applies to the table above **and** to every ad-hoc spawn inside a
phase (the authoring roles' recon sweeps, tracers, `archivist` bulk
reads). The main thread stays the orchestrator — it decides, dispatches,
and synthesises; the 動手 work runs on the cheapest tier that does it well.

**Role contracts** (the main thread loads the role's own SKILL.md and runs it
in-context to author the phase):

- `skills/pm/SKILL.md` (+ `skills/pm/abstraction.md`, `escalation.md`).
- `skills/designer/SKILL.md` (+ `skills/designer/abstraction.md`,
  `escalation.md`, `scripts/render-mockups.sh`).
- `skills/engineer/SKILL.md` (+ `skills/engineer/references/*`,
  `scripts/{plan_lint,scope_gate}.sh`).

**Per-role rules**: only `skills/pm/references/rules.md` — one file holding every
principle with its sub-checks and examples inline, walked by `pm-plan-reviewer`
(`skills/pm/rules/CONVENTIONS.md` is its maintenance contract).
**The designer and engineer roles have no rules file**: their drafting
constraints are their own artefact's cells (the widget contract in
`designer/ownership.md`, `schemas/engineering-plan.mjs`), which apply at the
moment of writing rather than
relying on the author to recall a separate document, and their cheap gate is a
script over the artefact (`design-lint`, `plan-lint`) rather than a checklist
over a description of it.

**Launcher detail files:**

- `artifacts.md` — Notion row locations per plan type, naming, citation format, scope rules.
- `engineering-plan.md` — gate-side required-contents summary for the engineer plan.
- `divergence.md` — mid-flow re-authoring procedure.
- `todo-backlog.md` — deferred items go to the feature's TaskList task.
- `migration.md` — pre-existing-violation compliance rule.
- `gates.md` — the audit matrix, the gate loop policy, the re-audit rule, the
  ordered implementation gates, the full-suite runs.
- `co-creation.md` — the five-step round and the two interaction rules.
- `plan-integrity.md` — `I1`–`I4`, and revving an older plan shape.
- `worktree.md` — the file-writing boundary: create, capture, teardown.
- `blocks/` + `flows/` — the pipeline contract; `plan-flow lint` validates it,
  `blocks/CONVENTIONS.md` is the format spec.
- `founder-corrections.md` — the collaboration contract: the judgment calls that
  went wrong and the corrections that fixed them. **Read before proposing a
  solution, sizing what to build, dismissing a review finding, or making an
  outward-facing judgment call.** Not a skill — there is nothing to invoke.

## Plan-spec language

Row bodies default to **繁體中文 (Taiwan terminology)**, English for technical
acronyms / product names / cross-reference anchors — and **no duplicated property
fields** (Date / Status / Type / the Task + Feature Archive relations / Author
live as Notion DB properties, never repeated in the body; an opening
`**Status:** … / **Author:** …` header block is dropped). Both rules live in full
in each role's §Language + `artifacts.md` — the authoring role applies them; this
is the pointer, not the restatement.

## Closing report

After the cycle (whether it permits, refuses, routes, or exempts), close with a
one-block summary in chat:

```
/plan: <exempt | routing | in-flight | complete>
Task:  <Notion task URL> | (created)
Issue: <GitHub issue URL> | (n/a — no PR this cycle)
Phases opened: <PM, designer, translator, engineer, security, privacy, QA, code review — as applicable>
Stage: <current Stage> | (unchanged) | (n/a)
Plans uploaded: Product | Design | Engineering  (Notion rows linked) | (pending)
Worktree: <wt/… path + branch> | (n/a — no app-code writes this cycle)
PR:    <PR URL, base $BASE> | (n/a — no code in this cycle)
Close-out: <Feature Archive row URL + task row trashed (verified gone)> | (n/a — cycle still in-flight / exempt)
Retro: <ledger at N ≥ 5 unconsumed rows — run a process retro>  (line present only at threshold)
Next:  <one-line concrete next move>
```

**The `Close-out:` line is a hard gate, not decoration.** When `/plan: complete`,
this line MUST carry the Feature Archive row URL **and** the verified
**trashed task row (gone)** — that is the only proof Step 6 ran (Iron Law 7).
`Close-out:` may read `(n/a — …)` **only** while the cycle is genuinely still
in-flight or exempt; a `complete` cycle whose `Close-out:` is blank, `(n/a)`, or
uncited is **not complete** — the report is invalid and the cycle stays open.
Cite-or-it-didn't-happen. **The `Worktree:` + `PR:` lines are the same kind of
gate** (Iron Law 9): whenever app code was written this cycle, both must be
cited — a code-bearing cycle reporting `(n/a)` for either means the worktree was
skipped (app code landed in the main tree), which is a flow violation, not a
clean run.

A gate without a next move rots. Always close with a concrete next step.
