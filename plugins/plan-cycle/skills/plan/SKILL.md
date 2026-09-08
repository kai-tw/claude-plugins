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
> 2. **Every UI-producing implementation traces to an approved design spec** — a
>    **Design Plan DB row linked to the task**. The spec defines the layout per
>    `WindowSize` breakpoint, the components, the tokens, and the four states
>    (default, empty, loading, error). Code must not invent UI.
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

If the request matches the exempt list, say so plainly and proceed — **no task,
no phases**:

- **Typo fixes** (string / doc / comment typos)
- **Lint fixes** (formatter, analyzer-suggested cleanup)
- **Isolated bug fixes** that restore intended behavior without changing flow,
  scope, or interaction surface — route to `/bug-investigate`. A "fix" that adds
  a flow step, changes a permission boundary, or repurposes state is **not** a
  bug fix — it is a feature change and needs the full flow. A fix that adds a
  user-facing state, screen, affordance, or copy is a **SCREEN change (designer)
  + a translation cycle** — surface that classification to the founder *before*
  building; mirroring a shipped sibling's mechanism is fine, but its copy and
  per-surface design still need their own pass, so do not ship a sibling-mirror
  fait accompli.
- **Behavior-preserving refactors** (file rename, function extract, test
  reorganization, type tightening with no behavioral delta)

Respond `Exempt from /plan: <one-line reason>` and do the work — no task, no plan
phases, no Notion trail, spawn nothing. **The worktree gate runs on significance,
not on exempt status:** if the exempt change is **significant** — large scope, or
**functional** (an isolated bug fix that alters behavior counts) — it still runs
in an isolated worktree and ships as a PR (Iron Law 9; §Worktree isolation), just
without the plan/Notion artifacts. Trivial mechanical edits (typo / format / small
lint / tiny behavior-preserving tweak) and all non-app-code edits go directly in
the main tree.

### Step 2 — Ensure the feature's TaskList task exists (only task-creator)

Every feature's planning artifacts link to **one** anchor: its **TaskList
task**. `/plan` is the sole task-creator — this step runs once per feature,
and **once per sibling** when the PM phase splits a big ask into several
(`pm/SKILL.md` §Split into sibling tasks), never a second mechanism.

- **Task exists:** note its URL; carry it through the cycle. Leave its **Stage**
  untouched.
- **No task:** create it by **invoking the `archivist` skill** (this skill has
  no Notion MCP — `/archivist` is the Notion gateway). Tell it to add a TaskList row
  with a **Title Case** Name, a Status, the Area (a `lib/features/` folder name),
  and **Stage = "Product Plan"**. It returns the task URL.

#### The GitHub issue is opened in the same step

**A cycle that will produce a PR gets a GitHub issue, created alongside the
task** — same predicate as the worktree (§Step 3: does this cycle write app
code?), so it is not a new judgment call. Plan-only cycles and `Tracing` rows
get none: with no PR there is nothing for it to anchor.

```bash
gh issue create --title "<the task's Name>" --body "<problem + Notion task URL>"
```

Then have the `archivist` set the task's **`GitHub Issue`** property to the
returned URL. If the work *started* from an existing issue (a user-filed report),
link that one instead of opening a second.

**The issue is a pointer, not a copy.** Its body carries the problem statement
and the Notion task link — never the plan. The plan lives in Notion and revs
there; a body that restates it becomes a second source of truth that drifts the
first time the plan changes (§Plan integrity `I2`, applied across systems).

**Who owns what:** Notion owns `Status` / `Stage` / `Area` / `Trigger` and the
three plan relations; the issue owns the git side — PR linkage, `Fixes #N`
auto-close, commit references. Neither mirrors the other's state.

DB ids / schema live only in `/archivist`'s `notion-kb.md`; reference the DBs and
the task **by name** — never hardcode a Notion id here.

### Step 3 — Analyze the task → decide which phases to open

**Before opening the PM phase, pull the usage baseline.** When the task is a
*should we build this* question and its outcome is a metric the project's
analytics already tracks (adoption / retention / engagement / a specific event),
query it through the project's own usage-data skill **first** — one query,
before any phase opens. Competitor research answers "how do others do this"; the
baseline answers "does anyone here reach it", and the second can moot the first
for a fraction of the cost. Cite the figure either way; at low traffic it is
**directional, not significant**, and product judgment still leads (P1.1).

Open a phase only when its criterion is met:

| Phase | Open when… | Spawns |
|---|---|---|
| **PM** | the change touches an online mechanism / data flow / permission / telemetry, or no approved product plan exists | `pm` |
| **designer** | the change produces or alters any user-visible surface | `designer` |
| **translator** | the change adds or changes user-facing copy needing i18n | `translator` |
| **engineer** | any non-trivial implementation (always, for code work) | `engineer` |
| **security + privacy** (one cross-cutting gate, two lenses) | **the code only** — boundary-gated on the diff's own sink signals. Whether a field should be collected **at all** is PM rule `P8`, walked at ① by `pm-plan-reviewer`. Default to spawn when unsure — fail-closed. Runs *inside* the phases, not a standalone phase you open/skip; see the audit matrix | `security-privacy-reviewer` |
| **QA test** | any code lands | `qa` |
| **code review** | after code is written | `code-reviewer` |
| **post-QA** | after code + after QA's spec tests, when an approved plan exists — the spec residue (§Non-goals violations, a seam wired to the wrong source, doc the change made false, the `spec-should-change` judgment), parity with the siblings the plan names, **and** the design of every test the diff touches | `post-qa-reviewer` |

Non-UI work skips the designer + translator phases but **not** the engineer
phase. Security / privacy are **not** standalone steps — they are gates that run
*inside* the PM, engineer, and code phases (see the audit matrix).

If the cycle writes **any app code** (translator / code / QA — i.e. any
code-bearing ticket), it executes in an **isolated git worktree** so concurrent
`/plan` sessions on other tickets never touch each other's working tree
(§Worktree isolation, Iron Law 9) — this is mandatory, not optional. Only
plan-only cycles (Notion writes, no app code) skip the worktree.

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
  motions and interactions — the downstream engineer's lens, which used to be a
  second `feasibility-reviewer` spawn on the same artefact). They merged because
  the defect that matters most sits between them: a control the user cannot reach
  *because* the stack cannot render it there is one finding, and split across two
  reviewers each filed half. A `critical` from either lens **blocks until
  resolved** — an objective usability defect (a dead-end state, an unreachable
  primary control, an unconfirmed destructive action, a silent action), or
  infeasible-as-drafted with a cited source; a `warning` (a friction trade-off,
  or deliverable-but-risky) goes to the founder to weigh.
  Neither re-runs the whole judgment (§Gate loop policy). It right-sizes itself to the design's scope
  — you needn't set a tier: a net-new navigation model / multi-step flow triggers
  its `deep` multi-persona fan-out (first-time / a11y / locale / power), a localized
  screen tweak stays `light`. Force `deep` / `light` only if you know more than the
  spec's scope shows.

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
  - **Escalate the moment a finding changes kind.** Any round budget is a
    ceiling, not a quota. Once a finding stops being a *verifiable error* (a wrong
    number, a missing section, a claim the source contradicts) and becomes a
    *debatable judgment* (the reviewer would rank the trade-off differently), no
    further round can settle it — that call is the founder's. Judge by the
    finding's kind, never by the round number.

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

#### Co-creation round (per authoring phase; PM + designer share one)

The main thread runs each authoring phase in-thread, so it can ask the user
directly. A round has five steps, and **the founder appears exactly once**:

1. **Draft.** Run the authoring role (`pm` / `designer` / `engineer`) in-context
   by invoking its skill **via the Skill tool**. **Read
   `${CLAUDE_PLUGIN_ROOT}/skills/plan/founder-corrections.md` §Engineering taste
   before proposing a solution or sizing what to build** — it carries the
   measured corrections (minimal mechanism, parallel markers, gate distrust) the
   questionnaires ask about but cannot teach. Read the file; it is not a skill
   and there is nothing to invoke. Do everything that does
   **not** need the user, and collect the open questions (each: the question,
   options, your recommendation, what it blocks) — don't surface them yet.
   *In the merged PM + designer round, draft both artifacts here, back-to-back.*
2. **① Sanity gate (旁觀, player ≠ referee).** For a **pm** artifact,
   spawn `pm-plan-reviewer` as an **isolated sub-agent**
   over `skills/pm/references/rules.md`. **The author never audits itself.** Any
   `violation` → fix it **in place** — **no deferred, no dismiss** — and
   re-spawn. Loop to green, **cap 3 rounds**; escalate earlier once the finding
   turns from error into judgment (§Gate loop policy). For a **designer**
   artifact this cell is `design-lint <presentation-dir>` and for an **engineer**
   plan `plan-lint <draft>` — both scripts, so neither loops: clear every HARD
   failure, eyeball every ADVISORY. Cheap either way, so it runs
   before the founder's time is spent.
3. **Resolve — the one founder round.** Put **every** open question and every
   load-bearing fork to the user in one `AskUserQuestion` pass. (This is also
   where the user grants the approval the three principles require.) **This is
   the step that must precede the expensive gates** — a founder decision arriving
   after the battery invalidates a clean pass and forces the whole battery to
   re-run.
4. **② Adversarial gate.** Now the scope is settled, spawn the Adversarial tier
   for this stage (matrix column ②). **One pass**, then one verification pass
   scoped to the fixes — never loop-to-green (§Gate loop policy). Resolve every
   `critical`; take a `warning` back to the founder only when it would change a
   decision, else note it at the affected line as an accepted trade-off. If a
   finding *does* reopen a fork, that is a short second Resolve — bounded, and
   still far cheaper than having run the battery twice.
5. **Finalize + confirm.** Fold everything in, write the final plan, **invoke the
   `archivist` skill to upload it** (Iron Law 6), and **confirm the upload
   landed** before advancing — a plan not in Notion does not exist. Re-run the
   gates per §Re-audit every plan change (the audit is per-change, not
   per-draft).

Never fabricate a user answer inside a sub-agent. If a `learning` surfaces that
the rules don't cover, the role's rules `CONVENTIONS.md` learning-update method
applies (find a similar rule → merge; else add a sub-check or a new principle;
stale rules may be deleted).

#### Two interaction rules — decisions ask, problems search-first

These bind this launcher **and** every authoring phase (PM / designer /
engineer), on top of the co-creation round above. They are the SSOT each role's
runtime block points back to.

1. **Every decision goes to the user — with your best answer attached.** The
   moment a genuine decision surfaces (which approach, which scope, which
   trade-off, what to defer), put it to the user via `AskUserQuestion` — don't
   bank a unilateral pick, and don't silently hold it for the phase-end batch.
   Make the option you'd pick the **first** choice, label it `(Recommended)`,
   and give the one-line why. A *decision* is a fork with more than one
   defensible answer where the user's preference matters — this is exactly what
   to ask, and it is distinct from a *problem* (rule 2).
   - **Trivial-decision carve-out — decide, but log it.** A low-stakes decision
     with one clearly-right or near-indifferent answer you MAY resolve yourself
     without asking — but every such autonomous call is **annotated `〔自行裁定〕`
     where it was decided** in the plan being authored this phase (§Plan
     integrity `I4`), so the user can scan and
     override it when they review that plan. Deciding without asking is
     allowed; **not** recording it is not. (User-made / co-created decisions use
     the same note marked `〔使用者〕`; cross-feature or likely-to-resurface ones
     promote to the Decision Log DB at close-out, as today — the list is the
     per-cycle log, the Decision Log DB its curated subset.)
   - **Scope-matching carve-out — don't inflate a detail adjustment.** When the
     user adjusts ONE detail of something that already exists, the narrow reading
     **is** the default pick — do **not** make a broader rebuild the
     `(Recommended)` option; surface the wider scope only as an explicitly
     non-recommended aside ("the card also covers X/Y/Z — those too, or just
     this?"). The `(Recommended)` label carries weight; pointing it at the big
     build manufactures scope the user never asked for. (Founder corrected this
     twice — a one-icon tweak framed as「全組 polish（建議）」as the recommended
     first option.)
2. **Every problem is researched before it's escalated.** When you hit a blocker
   or an unknown (how does X work, why does this fail, what's the existing
   pattern), find the answer first — the Notion KB → the codebase →
   project docs → the web — and only bring it to the user when that search comes
   up empty. Found → proceed, citing the source; empty → ask. Never guess
   silently, and never spend the user's time on something the record already
   answers.

**Plan writes are milestone-batched, never per-decision.** The living draft
accumulates in-thread and reaches Notion only at the existing upload milestones
(finalize → rev; Iron Law 8 / Step 5) — **not** one Notion write per decision.

**Which write mechanism to use** (`I1` says a rev edits the body — this is how):

- **Purely adding** (new §Conformance rows, a new section, nothing existing
  changes) → have the `archivist` append via
  `notion_payload.mjs append <page-id>` (block-level). Cheapest, and it cannot
  desync what it doesn't touch.
- **Anything existing changes** (a ruling rewritten, prose corrected, a section
  restructured) → a **full-body replace** via `bodyFile` (`update` treats the
  file as the source of truth). Re-emitting the whole body is the *point* here —
  it is what forces the stale occurrences elsewhere in the body to be swept
  (§Re-audit every plan change), which an append can never do.

A body kept honest stays small, so full-replace stays bounded.

#### Re-audit every plan change (audit-first, always)

Re-auditing is the **default, on every change** — never a one-time
initial-draft check. Any time a plan body changes — a co-creation
decision, founder feedback folded in, a finalize-round expansion, or a mid-flow
divergence rev (§Mid-flow divergence) — **re-run the matrix gates for that
stage on the changed plan BEFORE any implementation or next-stage work
proceeds**: the ① cell to clean (`pm-plan-reviewer` loop-to-green cap 3, or
`plan_lint.sh` exit 0), the Adversarial tier one pass
+ one verification, per §Gate loop policy. Audit first, then implement. A revised plan that has not been
re-audited is **not** approved, regardless of an earlier green pass — the change
is exactly where a new defect (e.g. a parallel-marker second source of truth the
prior pass never saw) enters. The author never self-audits the rev (player ≠
referee), and the audit runs *before* the user re-approves the delta, not
after. **And sweep the whole body when you rev** — that is check `I1` in
§Plan integrity, which a gate grades rather than leaving to the
author's diligence.

**The re-run is a conservative cache, not a cold replay — never a launcher
skip.** Each re-spawned gate gets its prior verdict + the diff since it; if the
diff is **disjoint from that gate's surface** it affirms ("out-of-surface, prior
verdict holds") instead of re-deriving, else it re-derives that surface + its
blast radius. Invalidation is **fail-closed** (any doubt → re-derive; a HIT is
the gate's own call, never the launcher dropping it). The ① cell is cheap —
always re-run it cold; the cache earns its keep on the Opus gates. Every gate
still signs off the whole plan.

#### Plan integrity (I1 · I2 · I3 · I4 — every plan, every role)

These constraints bind **every** plan body regardless of which role authored it —
they govern the artifact, not the role's domain — so they live here once instead
of as a copy in each role's checklist. They are **drafting constraints
first**: honour them while writing. `engineer-plan-reviewer` grades them by id on
every plan — inside the checklist walk for pm / designer, as a
cross-cutting check on the engineer plan — and `plan_lint.sh` catches their
mechanical tells. `design-plan-reviewer` catches the provenance half again at ②.

- **I1 — A rev edits the body; it never stacks a layer on top of it.** After any
  revision the body must state only what is true *now*: no two places may give
  different rulings on the same thing. Rewrite the affected prose in place and
  update the decision note there (`I4`) — never append
  a `## Rev` section that contradicts text left standing above it.
  **Reference by name, never by ordinal or count.** "The two gating metrics
  above", "the third constraint" and "§4" all decay silently the moment the thing
  they point at is edited — the prose stays grammatical and becomes false, which
  is the one kind of staleness a reader cannot see. Name what you mean instead
  ("the gating metric on log level") — "the two items above" survives a rev that
  merges them into one, and a reviewer spends a pass on it.
- **I2 — Downstream cites upstream; it does not re-derive it, and does not
  promote what upstream never ruled.** When a plan depends on a ruling made
  upstream, cite it (`per <upstream> §<section>`) and stop — do not restate its
  reasoning at equal or greater
  length. The same applies within one document: a fact is stated in full in the
  section that owns it, and referenced elsewhere.
  **Only a ruling can be cited as one.** §Proposed approach / §Acceptance
  criteria / §Success metric / §Non-goals and any decision note (`I4`) are authorized;
  a number, default, threshold or ordering that appears under §Product-level
  risk or arrives via "for instance" / "candidate" / "could" is **input**, not
  a ruling — own the call in your own voice (naming the principle it serves)
  or escalate for an explicit one. Nor may a plan answer *downstream's*
  question in its own body: a spec that settles a routing or state-reconciliation
  mechanism has banked an unverified engineering decision as settled design.
  Record the observable behaviour and defer the mechanism, with an owner. The
  classic tell is a spec importing an "e.g." threshold from a risk section as
  binding, against a principle the same spec states.
- **I3 — Point-form, one claim per line; the reader gets the plan in a minute.**
  Bullets and tables carry the body; prose only where a bullet cannot hold the
  thought. **Every line must answer "which ruling or fact do I carry" — if it
  answers nothing, delete it.** Rejected alternatives, resolved open questions,
  the wreckage of a superseded passage, and rationale restated from upstream all
  fail that test. Rationale that survives is compressed into the same line as the
  ruling, never given its own paragraph. The opening section must land four
  things on their own: what is being built, why, the goal, and the execution
  direction — a reader who stops there has the plan. Length is an outcome of this
  rule, never a target to hit: a section is as short as saying it once allows,
  and no shorter.
- **I4 — A decision is annotated where it was decided; there is no decision
  section.** Directly under the ruled line, one line:
  `〔使用者〕「<逐字原話>」 → <本輪怎麼落地>` or `〔自行裁定〕<裁示理由>`.
  `使用者` = co-created or founder-ruled; `自行裁定` = you decided unasked (the
  trivial carve-out) — every one of those **must** carry a note, so the founder
  can scan `〔自行裁定〕` and overturn any of them; deciding without asking is
  allowed, deciding without recording is not. **The quoted half is the founder's
  own words — never paraphrased, summarised, or replaced by your reconstruction
  of their reasoning**: a quote can be diffed against what was actually said, a
  paraphrase cannot, and each rewrite is another chance to drop the distinction
  the ruling turned on. Quote the sentence that ruled; your reading of it goes
  after the arrow, where it sits beside the words it claims to implement — as do
  rejected options, when "why not X" is what makes the ruling legible. A
  deliberate deferral is a decision — note it with its owner and trigger. When
  the ruling changes, **overwrite in place** (`I1`): the half after the arrow
  freely, the quoted half only by replacing it with the founder's new verbatim
  words; no numbered log, no superseded entries left standing. Purely mechanical
  choices with no fork are not decisions. Cross-feature decisions are promoted to
  the Decision Log DB at close-out, not maintained twice.

#### Revving a cycle that started under an older plan shape

A plan approved before the current section shapes does **not** get retro-fitted.
Delete this section once no such cycle is in flight.

- **A section the schema dropped, holding rulings, stays** — `freeformBody`
  permits it. Old `## Decision history` entries that are founder rulings are
  load-bearing: move each to an inline `〔使用者〕` note at the line it rules
  (`I4`) as you touch that prose, and leave the rest until you do. Do not delete
  a ruling to satisfy a shape. Quote whatever surviving wording is most original
  (`I4`) — if the founder's actual sentence is no longer recoverable, quote the
  old entry verbatim rather than re-summarising it; the point is that nothing
  gets re-authored on the way in.
- **A role boundary that moved does not move the work already done.** A cycle
  whose design plan predates the designer-ships-widgets hand-off has no
  `§Widgets`, no renders, and nothing for `design-lint` to read. That cycle keeps
  the boundary it was approved under: the engineer builds the presentation as
  before, and those three are `n/a` with the reason stated. Re-running the
  designer phase to produce artefacts the approved plan never promised is new
  work, not a migration — if it looks worth doing, that is the founder's call to
  make explicitly.
- **The new shape binds the next rev's *content*, not its history.** Write the
  amended prose to the current questionnaire's cells; don't rewrite settled
  sections just to change their headings.

#### Worktree isolation (the file-writing boundary)

Concurrent `/plan` sessions share one repo. To keep their edits from colliding,
every code-bearing cycle runs its **file-writing phases in an isolated checkout**.
Only the PM phase is Notion-only and stays in the main tree.

**Which shape of isolation depends on where the session runs**, because that
premise is what changes:

| | isolation | how |
| --- | --- | --- |
| local (`CLAUDE_CODE_REMOTE` unset) | a **worktree** | `EnterWorktree`, steps 1–4 below |
| cloud (`CLAUDE_CODE_REMOTE` set) | a **branch** | step 1 + 1a, then `git checkout -b <the same name>` |

A cloud session's container cloned the repo for itself — no other session can
write into it, so the collision this exists to prevent cannot happen and a
worktree buys nothing. **Everything else is unchanged**: the same base preflight,
the same captured `$BASE`, the same branch name, the same push-per-phase, the
same PR, the same teardown. Only step 2 differs, and step 3's init still runs
(a fresh container needs the project's codegen exactly as a fresh worktree does).

The push gate reads the same marker, so an unpushed cloud branch is caught too —
and it matters more there, since the container's disk goes away with the session.

Create the worktree **immediately before the first phase that writes repo files**
— **the designer phase** when UI is in scope, since it ships the presentation
widgets (`designer` §Phase 5); otherwise `translator` if i18n is in scope (it
writes ARB), else the `code` phase. The engineer-plan phase then runs inside the
worktree — harmless, it only writes Notion.

1. **Precondition.** Ensure the session is on an up-to-date base branch:
   `git fetch && git merge --ff-only @{u}` on whatever branch is the intended PR
   base (with `worktree.baseRef: head` + a session on `main`, that is `main`).
   That only pulls origin→local; it does **not** catch the local base being
   **ahead** of origin (founder's unpushed WIP): also run
   `git rev-list --count origin/main..main`; if >0 those commits ride into your
   branch and the squash-merge folds them into your commit (PR #59) — base the
   worktree off `origin/main` and TELL the user, never auto `git reset --hard`
   (deny-listed). Full reconcile protocol: `git-ops` skill §Worktree base preflight.
1a. **Capture the base** (the worktree's creation base *is* the PR base — single
    source of truth), keyed on the `worktree.baseRef` setting, **before**
    `EnterWorktree`:
    - `head`  → `BASE=$(git rev-parse --abbrev-ref HEAD)`
    - `fresh` → `BASE=$(basename "$(git symbolic-ref refs/remotes/origin/HEAD)")`
    Abort if `BASE` is empty or `HEAD` (detached) — never open a PR against a
    detached base. Carry `$BASE` to close-out alongside the branch name.
2. **Create the isolated checkout.** `name = wt/$BASE/<area>/<slug>` — the `wt/`
   namespace, the captured `$BASE`, the `lib/features/` Area, the kebab task
   slug. Truncate `<slug>` if the whole name would exceed 64 chars. The name is
   the same either way, because the PR, the ledger's `branch`, and the teardown
   all key on it.
   - **Local:** `EnterWorktree` (NOT `git worktree add` — only `EnterWorktree`
     applies `.worktreeinclude`).
   - **Cloud:** `git checkout -b <name>` in the container's own clone. No
     `EnterWorktree`, and therefore no `.worktreeinclude` copy — step 3's init
     is the only thing that makes the tree build, so it is not optional here.
3. **Init:** run the project's worktree-init step if it defines one — a project
   needing codegen, a dependency install, or an asset build in a fresh worktree
   documents that in `.claude/rules/`. `.worktreeinclude` has already copied the
   gitignored build artifacts the project lists there; the init step covers what
   copying alone cannot.
4. **Read the real branch name** with `git branch --show-current` — carry it for
   the close-out push/PR; never assume it equals the worktree name.

All repo-writing phases (translator ARB, code, QA) + their gates + the engineer
commit gate run **on the isolated checkout**. Locally that means staying in the
worktree — do not `ExitWorktree` until close-out; in the cloud it means staying
on the branch, so do not `git checkout` the base until close-out either.

**Sub-agents dispatched from inside a worktree** do NOT inherit its cwd — they
grep the MAIN tree, so worktree-only edits (uncommitted code, just-written ARB
keys) look absent unless you pass each spawned agent the worktree's absolute path
and tell it to `cd` there first. (A cloud session has one checkout and no second
tree to grep, so this trap is local-only.) A code-writing sub-agent commits on its own
unless the prompt forbids it ("do NOT run git commit / git add; leave changes in
the working tree and report the diff"). Full protocol: `git-ops` skill
§Sub-agent dispatch hygiene.

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

### Step 6 — Close out (archive)

When the task is complete, the cycle is **not done until these run** (Iron Law 7):

0. **Open the PR (from the worktree).** Push the branch, then open the PR with a
   heredoc body (never `--body` — embedded newlines and CJK mangle):

   ```bash
   git push -u origin <branch>
   gh pr create --base "$BASE" --title "<conventional-commit title>" --body-file - <<'EOF'
   Fixes #<issue>

   Implements <Notion task URL> (→ Product + Design + Engineering Plan rows)

   ## Plan-stage gates
   | Gate | Verdict | Findings |
   |---|---|---|
   | pm-plan-reviewer | passed / n-a | 0 |
   | engineer-plan-reviewer | passed | 2 critical resolved, 1 warning accepted |
   | feasibility-reviewer | passed | 0 |
   | design-plan-reviewer | n-a — no design phase | — |
   EOF
   ```

   The `Fixes #<issue>` line is what closes the cycle's GitHub issue (§Step 2) on
   merge, and the Notion URL is the planning trail (Iron Law 4). Omit the `Fixes`
   line only when the cycle genuinely has no issue.

   **The gate table is one row per plan-stage gate, and `n-a` needs its reason.**
   These four run before a PR exists, so a comment cannot carry them (the
   diff-stage reviewers post their own — `review/SKILL.md §Posting findings to
   the PR`). Without the table the founder is merging code whose plan-stage
   verdicts are visible only inside a session that is about to end, and a gate
   that was silently skipped looks exactly like one that passed. Report the
   verdict and the finding counts, not the reports — those live in the Notion
   rows.

   **`Fixes` fires only on a MERGE into the DEFAULT branch.** With
   `worktree.baseRef: head`, `$BASE` is whatever branch the session sat on — so a
   worktree opened from a non-default base produces a PR whose `Fixes` line
   silently never fires (GitHub shows "will close when merged into `<base>`", and
   that merge never reaches `main`). Two cases need the issue closed by hand at
   close-out: **`$BASE` is not the default branch**, and **the work landed without
   a PR at all** (a local fast-forward). Check the issue's state before reporting
   the cycle complete rather than assuming the keyword did it. `<branch>` is the name
   read back in §Worktree isolation and `$BASE` is the base captured there
   (satisfies Iron Law 4). **Committing and opening this PR do not need user
   approval** — the worktree branch targets `$BASE` (`main`) as a review artifact
   the user reviews + merges themselves, so fire `git push` + `gh pr create`
   directly (no `AskUserQuestion` gate). Capture the returned PR number and
   record it: `plan-cycle pr-opened <PR#> "$BASE"` — **run it from the worktree**,
   which is where it reads the branch name that Step 6.6's teardown is verified
   against (`pr-opened <PR#> <base> <branch>` if you must call it from elsewhere).

   **Then grade the tests and post the report** — scoped the way the change is.
   Coverage alone measures ~20 min (`bin/plan-coverage`) and mutation carries no
   time bound at all (`mutation.sh` has no dry-count mode) — long enough to hit
   the Bash tool's own cap if run as a blocking call. Run it with
   `run_in_background: true` and wait for the completion notification
   (`founder-corrections.md`'s harness-auto-notify rule — this is the main
   thread, not a dispatched sub-agent, so it applies here); `Monitor` if you
   want to watch it live:
   ```bash
   plan-qa-report -- flutter test test/features/<feature>/
   ```
   Coverage and mutation, one comment on the PR, and the `qa-green` mark that
   stops the ledger's test-strength gate blocking turn-end. `/review` and lint
   already ran because gates stop the turn without them; this is the gate for the
   two that ask whether the tests are worth anything, and it is the reason
   `pr-opened` is not the last thing this step does.

   **Then stop — the rest of Step 6 waits for the merge.**

**The founder merges, not you** — Step 6.0 opens the PR and the full-suite
report (§After code) is already on it; pressing the button stays theirs.

> **Steps 1–7 run AFTER the merge lands, not at PR-open.** Close-out archives
> what **shipped**; a Feature Archive row written for an unmerged PR describes
> work that may still be reworked or dropped, and trashing the task row that
> early leaves the rework with nothing to track. Nothing is lost by waiting: the
> Notion plan rows and the review reports posted on the PR (`review/SKILL.md`
> §Posting findings to the PR) hold the whole record until then.
>
> The close-out gate arms on the **merge**, not on the PR opening —
> `plan-cycle.sh check` watches for the squash commit's `(#N)` on
> `origin/$BASE`, so turn-end starts blocking only once there is genuinely
> something to close out — arming at PR-open instead blocks every turn-end
> across the founder-review window demanding work that cannot yet be done.
1. Invoke the `archivist` skill to create a **Feature Archive** row — a **synthesis**
   (problem / final approach / key decisions / outcome), **not** a verbatim dump.
1a. **Repoint the GitHub issue before the task is trashed.** Close-out deletes
   the Notion task, so the issue's `Implements <task URL>` link is about to die.
   Comment on the issue with the **Feature Archive row URL** — the durable record
   — then let the merge's `Fixes #N` close it (or close it by hand if the PR
   didn't carry the line). Skip when the cycle had no issue.
2. Have the archivist **trash the task row** — `ntn pages trash <id> --yes`
   (close-out **deletes** the task; its Status / Stage are irrelevant). `/plan`
   task bodies carry no `<!-- archivist-generated -->` marker, so the guarded
   builder refuses — trash it by hand, after eyeballing it is the right cycle's task.
3. **Verify, don't assume.** Have the archivist **fetch the Feature Archive row
   back** to confirm it exists, and **confirm the task row is gone** (the trash
   landed) — don't trust the `✓`. Same fetch-back discipline the engineer
   close-out uses. An unconfirmed archive does not count.
4. **Cite it in the closing report** — the `Close-out:` line must carry the
   Feature Archive row URL + the **confirmed-trashed task row** + the
   safe-to-delete list (see §Closing report); the `PR:` line carries the PR URL.
   **No Close-out citation → the cycle is still open** (cite-or-it-didn't-happen,
   per Iron Law 7).
4a. **Check for unblocked siblings.** If this task shares an **Area** with any
    `Deferred` sibling (`pm/SKILL.md` §Split into sibling tasks), invoke the
    `archivist` skill to check whether that sibling's **Trigger** names this
    task. If it does, say so in the closing report and propose promoting it
    to `Next` — don't leave a satisfied Trigger unnoticed on the board.
5. Report back to the user which local artifacts (if any) are now safe to delete
   manually.
6. **Tear down the isolated checkout — merge-aware.** Check the PR's merge state
   first (`gh pr view <PR#> --json state,mergeCommit`), then branch. **In a cloud
   session there is no worktree**: every `ExitWorktree` below is instead
   `git checkout $BASE` + `git branch -D <branch>` (only once merged), and the
   remote-branch deletion is identical. The `clear` gate checks worktree and
   branches separately, so it already accepts either shape.
   - **Not yet merged** (close-out reached early — you got here without the
     gate, or the merge isn't visible on the local `origin/$BASE` yet):
     `ExitWorktree action: "keep"`. Commits are pushed; keep the branch +
     worktree for review follow-ups. Report the worktree path and note it will be
     removed once the PR merges. **Never auto-remove an unmerged worktree.**
   - **Already merged** (the usual case — close-out follows the merge): the
     branch's work is safely on the base, so tear it down. First confirm the
     change actually landed on `origin/$BASE` (`state` is `MERGED` + a
     `mergeCommit`; spot-check a changed file on `origin/$BASE`), then
     `ExitWorktree action: "remove"` — this deletes the worktree **and its
     local branch** — and fast-forward local `$BASE` (`git fetch && git merge
     --ff-only origin/$BASE`) so the main tree reflects the merge. **Then delete
     the now-stale remote branch:** `git push origin --delete <branch>`.
     `ExitWorktree remove` only drops the *local* worktree branch; the pushed
     `origin/<branch>` survives the merge (a squash/rebase merge rewrites SHAs,
     and head-branch auto-delete is off on this repo), so without this it lingers
     as dead history. Removing a merged worktree **and deleting its remote
     branch** need no extra approval (the work is already on the base); the
     `ExitWorktree` requires `discard_changes: true` only because the
     squash/merge commit's SHA differs from the local branch commit — expected
     and safe once `MERGED` is confirmed.
   - **`ExitWorktree` is session-scoped.** It acts only on a worktree created by
     `EnterWorktree` **in the current session** — for a worktree from a prior or
     ended session (the common "PR merged earlier, now tear it down" case) it is
     a **silent no-op**, not a success. Don't read that no-op as "done"; fall
     back to raw git: `git worktree remove <path> [--force]` then `git branch -D
     <branch>`. And if the remote branch is already gone (a per-PR delete button,
     or a prior teardown already ran `git push origin --delete`), that is
     "already done" — not an anomaly to chase.

   On a merged cycle **`plan-cycle clear` checks all three against git** — the
   worktree, the local branch, `origin/<branch>` — and refuses while any survives.
   Clearing is the last moment anything asks: the ledger dies with it, so a
   worktree left standing past this point is never mentioned again.
7. **File the runner-feedback entry** via the `feedback-ledger` skill — in the
   **main tree**, after the worktree exit (never committed to a feature branch).
   `--cycle` **must carry the cycle's ledger slug** (`plan-cycle.sh status`
   shows it): `plan-cycle.sh clear` greps the entries for that slug and
   **refuses** on a shipped (pr-opened) cycle until it exists, so a dropped 6.7
   can't pass silently.

   ```bash
   plan-feedback add process \
     --source runner --cycle <slug> --title "Cycle retro: <slug>" <<'BODY'
   …gate R/H/L · 量測列（founder findings 分 reuse／一致性／其他 · --diff 對帳差異 · 復發 bug）· friction · the mandatory subtraction candidate…
   BODY
   ```

   The Stop hook handles the "time for a retro" reminder — don't add one to the
   closing report.

(Close-out **trashes** the task row rather than setting a terminal Stage / Status —
those track live progress during the cycle, not its end. See `/archivist`.)

## Mid-flow divergence

If during implementation an artifact turns out wrong, incomplete, or infeasible:
do **not** silently ship a different product / UI / architecture. Stop and
re-author through the right role (per the three approval principles): product
scope → re-run `pm`; UI → re-run `designer`; engineering decision →
re-run `engineer` (its Phase 11 handles divergence). **Re-run the matrix gates on
the rev'd plan *before* implementation resumes** — per §Gate loop policy
(§Re-audit every plan change — a divergence rev is a plan change like any other;
audit-first). Re-request user approval for the
delta, and re-upload to Notion (Iron Law 6). Read
`${CLAUDE_PLUGIN_ROOT}/skills/plan/divergence.md` for the exact procedure.

## Process retro (the subtraction channel)

The process grows by default — every incident adds a rule, every gap adds a
gate — and nothing prunes it. This is the counterweight: the **runner** (the
session that just executed a full cycle) holds the best friction data and logs
it while hot; the founder consumes it in batches and rules on subtractions.

- **Collect (every cycle — Step 6.7):** file one `process` entry via the
  `feedback-ledger` skill — per-gate `R/H/L` (confirmed-real findings /
  hallucinated-or-dismissed / loops to clean), the **measurement row** (three
  integers that say whether the gates are actually moving the failure earlier:
  founder findings at PR review **by kind** — reuse / process-consistency /
  other; `plan-lint --diff` reconciliation deltas this cycle; recurring bugs —
  a defect class this codebase has fixed before, back again), friction events
  (spurious ledger blocks, steps that duplicated another), and a **mandatory
  subtraction candidate** ("if I could delete one step this cycle: X, because
  Y"). Never blank — "nothing to delete" requires naming the runner-up step
  and why it survives. The measurement row is what the batch consume reads as
  a trend: a gate whose kind-count refuses to fall is not doing its job, and a
  HARD check whose `H` beats its `R` for consecutive cycles is a subtraction
  candidate by number, not by feel. **Any non-zero count owes entries of its
  own**: each founder finding lands in its review category, each recurring bug
  lands in `recurring-bug` (anchoring the prior fix it undoes AND the new
  sighting), and this retro entry lists those filenames — the counts are the
  trend, the entries are what a consume batch can act on.
- **Consume (when `plan-cycle clear` nudges at close-out, or on founder
  demand):** read the entries, aggregate per-gate hit rates + the most-nominated
  subtraction candidates, route each category to its named destination
  (`feedback-ledger §Consume routing` — recurring-bug goes to the qa
  failure-class index or the consistency mechanism table, never to prose), and
  put demote / delete / keep proposals to the founder via
  `AskUserQuestion`. Apply approved edits to the skill files, then **delete each
  consumed entry file** — an entry that survives its own consumption is the
  one-way growth this channel exists to prevent. A still-unresolved item stays
  as its own entry rather than riding along inside a consumed one, so nothing is
  silently dropped. Only delete an entry whose cycle is already cleared (shipped
  + closed out), so `plan-cycle.sh clear`'s slug check never fails on a
  still-open cycle. Proposal power is the runner's; ruling power is the
  founder's.
- **Guardrails:** the ledger records **verifiable facts**, not feelings — a
  gate that blocked you is not thereby friction (that may be the gate
  working). Read `0 findings` as possible deterrence, not automatic waste;
  hallucinated findings are pure cost. And this mechanism must stay lighter
  than what it prunes: one row in, one batched review out — if the retro
  itself starts growing steps, it goes on its own ledger.

New gates enter **on probation** — named on the ledger's watch list, first
subjects of the next retro (`feasibility-reviewer`, added 2026-07-08, is the
inaugural entry).

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
reasoning* holds, not merely whether the fix is present, is `opus`** — see
**Green is not proof**.
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
constraints are their questionnaire's own cells (`schemas/design-plan.mjs`,
`schemas/engineering-plan.mjs`), which apply at the moment of writing rather than
relying on the author to recall a separate document, and their cheap gate is a
script over the artefact (`design-lint`, `plan-lint`) rather than a checklist
over a description of it.

**Launcher detail files:**

- `artifacts.md` — Notion row locations per plan type, naming, citation format, scope rules.
- `engineering-plan.md` — gate-side required-contents summary for the engineer plan.
- `divergence.md` — mid-flow re-authoring procedure.
- `todo-backlog.md` — deferred items go to the feature's TaskList task.
- `migration.md` — pre-existing-violation compliance rule.
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
