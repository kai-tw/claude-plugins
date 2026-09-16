---
name: review
description: >-
  Single entry for every review: spawns the matching report-only agent —
  code-reviewer (+ finding-scorer per filed finding), engineer-plan-reviewer,
  pm-plan-reviewer, security-privacy-reviewer, post-qa-reviewer,
  design-plan-reviewer, feasibility-reviewer. The caller acts on the findings.
  TRIGGER: review X · code / security / privacy / plan / ux / feasibility /
  consistency review · 幫我 review · 審一下
  NOT for: bug investigation → /bug-investigate · lint · authoring the artefact
  → /plan · fixing the findings
allowed-tools:
  - Agent
---

# Review (dispatcher)

The single review hub. Pick the matching report-only sub-agent and spawn it; the
agent does **not** edit source. (The `/plan` launcher spawns these same agents
in-flow during a planning cycle — this skill is the standalone / ad-hoc entry.)

## When to run

Run `/review` **proactively on a growing worktree bundle** — early and between
fixes — not only once at PR-open. As soon as accumulating commits touch real
architectural surface (a new use case, repo method, or cross-layer
boundary), review the diff so far; the founder catching a smell by hand
mid-bundle is the signal the gate ran too late. This complements the PR-time
pass, it does not replace it.

**Rework counts, and counts most.** Commits landing *after* the PR opens — a layer
deleted, a base class swapped, a cubit generalized, a capability moved across
features — rewrite structure an earlier review approved and are usually absent
from the plan's §Classes, yet they are the least-reviewed stretch of a cycle:
`/qa` fires there on its own because a refactor turns tests red, and review has no
equivalent trigger. `plan-cycle`'s Gate 3 is that trigger — turn-end blocks once
an open PR's branch runs too far past the last reviewed sha (it prints the count
and the threshold). Treat the block as late, not as the schedule.

## Mode dispatch

| User intent | Sub-agent | Reviews | Output |
|---|---|---|---|
| Code review (semantic, architectural, lint-uncatchable) | `code-reviewer` (the 法官 — questions and rules in one pass) | the uncommitted diff | **return to caller** — its report (no file) |
| Engineering-plan **should-this-exist** (2 scope-gated dimensions; the other 9 are graded on the diff by `code-reviewer`) | `engineer-plan-reviewer` | an engineering plan | **return to caller** (no file) |
| **PM-plan rules compliance** (`P1`–`P8` + plan integrity, sub-check by sub-check) | `pm-plan-reviewer` | a pm plan | **return to caller** (no file) |
| **Security and/or privacy** (threat model + attack surface · data-minimization) — asking for one spawns the agent, which walks **both** lenses | `security-privacy-reviewer` | the diff + store declarations — never a plan; "should this be collected at all" is PM rule `P8` | **return to caller** (no file) |
| **Post-QA** (did we build what was approved · is it built the way this codebase already does it · will these tests still catch the bug next year) — asking for one spawns the agent, which walks **all three** lenses | `post-qa-reviewer` | the diff + the approved product / design plan + the engineering plan (§Conformance matrix and its `同儕：` rows) + the siblings it names + every test the diff touches, graded against `/qa`'s contract | **return to caller** (no file) |
| **Design spec — usability + deliverability** (first-time-user confusion · can the stack build it) — asking for one spawns the agent, which walks **both** lenses | `design-plan-reviewer` | a design spec + its renders (it right-sizes the usability walk itself — say "go deep" / "light pass" to override) | **return to caller** (no file) |
| **Feasibility** (downstream deliverability of a PM plan, early-bounce) | `feasibility-reviewer` | a **PM plan** only, designer + engineer lens — never a design spec (that is `design-plan-reviewer`) and never the engineering plan | **return to caller** (no file) |

Pick by trigger phrase. If the user asks for "review my changes" without
specifying, ask once which dimension(s) they mean — don't guess. If they ask for
several, spawn them in parallel.

## Why this many reviewers — the merge criterion

**Dimension count is never the argument, in either direction**: `code-reviewer`
walks nine dimensions in one pass, so "covers a lot" never splits a reviewer and
"we have several" never by itself merges two. **Two reviewers merge only when
they would run at the same moment on the same artefact** — four tests, all
required; a different rule corpus fails none of them:

1. **Same trigger.** A reviewer that runs on every diff and one that is
   boundary-gated do not merge: the merged agent either runs the gated walk
   unconditionally or hides the same gate behind one bigger context.
2. **Same stage.** Same cell of the audit matrix — a ① cheap-tier walk and a ②
   adversarial pass answer at different costs for different reasons.
3. **Isomorphic contracts.** The phases line up, so the result is one spine with
   two lenses, not two agents stapled together.
4. **A cross-reference that disappears.** They currently tell each other to file
   half a finding; that seam is where a finding drops — the strongest signal, and
   it outranks the other three.

| Reviewer | Trigger | Stage | Also loads |
|---|---|---|---|
| `code-reviewer` (9 dims, 法官) | **every** code change | code ① | `.claude/rules/` + `style-pack --paths` (母規則 + 該 diff 的語言檔) — no plan |
| `security-privacy-reviewer` | the diff's own **sink signals** (a pure-removal diff skips it) | code ② | sink rule packs + store declarations — no plan |
| `post-qa-reviewer` | after QA, when an approved plan exists | after-QA | the approved plans + the siblings they name + `/qa`'s contract; it splits the diff by tree (conformance and consistency on `lib/**`, test design on `test/**`) |
| `pm-plan-reviewer` · `engineer-plan-reviewer` · `feasibility-reviewer` · `design-plan-reviewer` | a plan or spec is drafted | ① / ② | no diff exists yet |

Read the table down the **Trigger** column: every merged pair shared one exactly,
every remaining pair differs in it. Before proposing a merge, say which of the
four tests pass — fewer than four is a dispatch-count optimisation that buys a
bigger context loaded more often.

**"Does this design meet the design rules"** is the `design-plan-reviewer`;
mockup-fidelity is a manual founder check. The `post-qa-reviewer` checks
**shipped code vs the approved spec** (is a required state / motion / interaction
actually implemented), not mockup-vs-design-rules.

**Every reviewer above is 不落檔** — it grades and **returns its findings to this
dispatcher** (security/privacy/ux/feasibility/consistency: each item `passed` /
`warning` / `critical`, looped until all `passed`; code review: the 法官's report;
engineer-plan-reviewer: the consolidated report inline). No file output.

## Spawn protocol

**No `Agent` tool → stop, don't self-review.** Check first. This skill's only
mechanism is spawning the matched sub-agent(s); reviewing the diff yourself
instead, and flagging that only in a closing footnote, is exactly the silent
skip `§What "silent skip" means` forbids. Reply with just: which sub-agent(s)
the request would have spawned, and that the caller must invoke `Agent`
directly, from its own context, to spawn them.

**Spawn in background by default** (`run_in_background: true`):

- The agent's file reads and sub-sub-agent spawns stay in its sub-context; background
  lets the main session keep helping the user in parallel.
- The agents do **not** edit source, so background is safe — no clobbering parallel
  edits.
- On completion the agent's summary arrives as a notification; relay it then.

Spawn foreground only when the user explicitly asks ("block on it", "I'll wait").
Pass the user's request verbatim plus any extra constraints. Do **not** re-run the
review in this main context.

### Code review: the 法官, then a scorer per finding

`code-reviewer` is the 法官: it questions every detail of the diff, rules on its
own challenges (有效 · 有理), and returns the finished report. Because it referees
challenges it raised itself, before any verdict spawn one `finding-scorer`
(sonnet) per filed CRITICAL / WARNING, all in parallel, each briefed with that
finding's `[C<n>]` block verbatim, the diff hunk it points at, and the rule
section it cites — never the packs. A finding
scoring **below 80** moves to a `### 低信心` section of the relayed report with
its score and the scorer's line — that is its verdict: not acted on, no marker
owed. SUGGESTION is not scored. Relay and post the scored report.

**Its report must carry the buckets, not only the findings.** 駁回, 成立但不處理,
無法判定 and §Detail coverage are what a single-agent review has instead of a
second reader: they are the record that a question was asked and answered
against. A report that lists only filed findings is indistinguishable from one
where the rest were dropped — treat that as an incomplete review and say so.

## After the agent returns

The agent returns its findings (counts for code and the engineering plan;
graded findings for security / privacy / ux / feasibility) + a one-line overall assessment.
**Every finding gets an explicit verdict — silent skipping is forbidden.**

### Verdict per finding

**Before verdicting, run the minimalism check** — the measured failure was a
reflexive `isImporting` flag added to a shared state type where an existing enum
already modeled it: does existing domain state (a code, an enum, a nullable)
already model the fact, so the "fix" would build a parallel marker? Reviewers
propose; the engineer decides. Down-grading an over-graded finding, with the
reason stated, is a legitimate verdict — building infrastructure for one is not.

For each finding the reviewer filed and the scorer kept, report a verdict from this set:

- **FIX** — apply the change in the main thread (or hand to the user) one finding
  at a time.
- **DISMISS (rationale)** — keep the code as-is, with the rationale **written into
  the codebase** as a **one-line** `// review-dismiss: <reason>` at the site. The
  reason must be specific (not "intentional" / "by design") and must not be
  precedent alone — "the sibling does it" is 推託, not a reason; cite the source
  plan / spec / rule when one applies. A dismissed finding without the marker is a
  silent skip — re-classify as FIX.

  **One line is the whole budget.** A rationale that needs a paragraph is not a
  dismissal: it is either a FIX, or a principle that belongs in `.claude/rules/`
  and should be written there instead.

  `plan-cycle`'s Gate 4 enforces the two halves of this that are string-checkable
  — an empty or generic reason ("intentional", "by design"), and a rationale
  spilling onto a second comment line — against the uncommitted diff at turn-end.
  It deliberately does **not** judge the precedent rule: telling a bare sibling
  appeal from a structural argument that mentions a sibling needs judgment, and a
  gate guessing at it would fire on correct dismissals. That half stays yours.

  The marker is a **message to the next review, not a shield**. It tells the
  reviewer the point was already raised and settled, so it is not re-filed from
  scratch every cycle — and, deliberately, it hands the reviewer the exact
  sentence to attack. The reviewer may overturn it; see
  `code-reviewer.md §Challenging a dismissal`.
- **ESCALATE** — finding needs scope change (the PM role) or design change (the
  designer role); route there before code-side action.
- **DEFER** — finding is real but explicitly out-of-scope for this cycle (e.g. a
  pre-existing violation in a block the current diff doesn't touch). DEFER is
  allowed **only** as a TaskList task (Status `Deferred` + a Trigger) via the
  `archivist` skill. A verbal "we'll fix it later" is a silent skip.

**A Kind 1 finding cannot be DISMISSed** — its exits are FIX and ESCALATE, and
the SUGGESTION carve-out below does not reach it. The reviewer is already barred
from waiving a written rule it finds not worth the trouble
(`code-reviewer.md §Ruling`), and that bar does not lift when the finding changes
hands: "the rule is wrong here" is an amendment, argued where the rule lives, and
until it lands the verdict is FIX. A marker at the site would make the exception
the rule could not grant itself.

`code-reviewer`'s **SUGGESTION** tier is the single carve-out from the
written-into-the-codebase requirement: nothing is wrong, so declining one leaves no
defect behind and there is nothing for a future reader to be warned about. It still
gets an explicit verdict, but a DISMISS needs only a one-line reason **in the
report** — no `// review-dismiss:` marker. Forcing a codebase annotation for an optional
improvement is how that tier would start costing more than it returns.

For **security / privacy / ux**, a `critical` blocks: hand it back to the
implementer / authoring role (ux → the designer role), then re-spawn the reviewer
**once, scoped to the fix + its blast radius, with the prior findings in the brief**
so it verifies them rather than re-deriving the whole judgment
(`plan/gates.md §Gate loop policy`). A `critical` still standing after that, or a
`warning` you don't FIX, goes to the user — `critical` is never DISMISSed without a
landed class-eliminating rationale (for ux, a written design rationale).

### Posting findings to the plan row (plan reviews)

When the review target is a **plan row** (a PM / Design / Engineering Plan under
`/plan`, not a code diff), post the graded findings + their dispositions as a
**Notion comment on that plan row** — invoke the `archivist` skill (`comment
<page-id> - --commit`, findings piped on stdin). This leaves a durable,
founder-visible collaboration trail on the plan itself, consistent with the 不落檔
stance — a comment annotation, **not** a file.

### Posting findings to the PR (every reviewer whose artefact is the diff)

**Which reviewers this covers is decided by what they read, not by which stage
they run in.** Every reviewer graded against the **diff** posts here: code
review (the 法官's report) and `security-privacy-reviewer` at the code
stage, and `post-qa-reviewer` after QA. Their
findings are about the code the founder is being asked to merge, so the PR is
where they belong. The plan-stage reviewers (`pm-plan-reviewer`,
`engineer-plan-reviewer`, `feasibility-reviewer`, `design-plan-reviewer`) read a plan or a
spec, not the diff — their record is the Notion row plus the gate summary in the
PR body (`plan/SKILL.md` Step 6.0).

When the branch under review **has an open PR**, the report is posted to that PR
as a comment — **twice**, and the order is the rule:

1. **Before any fix lands** — post the scored report as relayed. Open the
   comment with the sha that was reviewed — `Reviewed at <git rev-parse HEAD>` —
   then record it: `plan-cycle reviewed <that sha>`.
2. **After the fixes land** — post the disposition: every finding from comment 1
   with its verdict (FIX / DISMISS-with-rationale / ESCALATE / DEFER) and what
   actually changed, one line each.

A reviewer that returned **zero findings still posts** comment 1, saying so with
its sha. "No comment from `post-qa-reviewer`" and "it found nothing" are indistinguishable otherwise, and only one of them means the gate ran.

**Why post first rather than once at the end.** Once fixing starts, the finding
list can only be reconstructed from memory, and a report written afterwards
silently narrows to whatever happened to get fixed — the findings quietly
dropped leave no trace, which is the exact failure the verdict protocol exists to
prevent. The pre-fix comment is the evidence a finding existed; the post-fix
comment is answerable to it.

**Why the sha.** A review comment without one records that a review happened but
not *against what*, so "how far has the branch drifted since" has no answer. The
`plan-cycle reviewed` mark is the machine half of the same fact and arms Gate 3.
Post the sha even when there is no ledger to mark: the comment is what a human
reads.

Post with a heredoc, never `--body` (embedded newlines and CJK mangle):

```bash
gh pr comment <n> --body-file - <<'EOF'
…report…
EOF
```

**No open PR → skip both.** The verdicts above are then the whole record; don't
invent a file to write them to.

### What "silent skip" means

These count as silent skipping and must NOT occur:

- Acknowledging a finding in chat but not landing the rationale in code or as a
  TaskList task.
- Conflating "the lint doesn't fire" with "the rule is satisfied" — the prose
  rules in `.claude/rules/` bind even when no lint catches the violation.
- Reading "code modified by a feature PR must be brought into compliance"
  (`/plan` skill `migration.md`) at too fine a granularity to exclude pre-existing
  violations in adjacent blocks of files the current diff touches. When ambiguous,
  default to FIX.
- Any verdict that boils down to "I'll let the user decide" without enumerating
  the finding for them.
- A finding present in the PR's pre-fix comment but absent from the post-fix
  disposition comment. The two comments must enumerate the same findings.

### Re-review

After every finding has a written verdict and any FIX changes land, **re-invoke
`/review` to confirm clean** when CRITICALs existed or the diff was non-trivial,
briefing the prior report so the pass verifies rather than re-derives. Pin
`model: sonnet` unless a CRITICAL was filed — only a critical's fix reasoning
needs opus (`plan/SKILL.md §Model tiering`).

**Why report-only:** an agent auto-fixing in the background is fast but
asymmetric — a bad fix that lints clean (semantically broken, behavior-altering,
wrong design intent) ships silently. Report-only keeps the human in the loop on
every change.
