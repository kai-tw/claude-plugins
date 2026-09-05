---
name: review
description: >-
  The single entry for every review concern — spawns the matching report-only
  sub-agent against the relevant artifact (an uncommitted diff, or a plan):
  code-reviewer · engineer-plan-reviewer (engineering-plan design quality) ·
  pm-plan-reviewer (the PM plan's rules walk) ·
  security-reviewer (threat
  model, the diff) · privacy-reviewer (data minimization, the diff) · conformance-reviewer (the residue
  of "code embodies the approved plan" that /qa's spec tests can't pin) ·
  test-reviewer (test DESIGN, both halves of the test/** partition) ·
  ux-reviewer (design-spec usability) · feasibility-reviewer (downstream
  deliverability of an upstream plan) · consistency-reviewer (cross-feature
  mechanism parity — second sources of truth, sibling check-set divergence,
  duplicate capability). All are report-only — the caller acts on the findings.
  TRIGGER: code review · review the code · review my changes · review this ·
  review the tests · test review · are these tests any good · 審一下測試 ·
  check my code · review before commit · security review · threat model X ·
  review X for vulnerabilities · privacy review · minimization review ·
  rules audit X · review the plan · engineering-plan review · design-quality review ·
  conformance review · feasibility review · ux review · usability review ·
  heuristic review · will this confuse a first-time user · run review ·
  consistency review · 一致性檢查 · 跟既有的做法一致嗎 · duplicate implementation ·
  幫我 review · 檢查這段 code · review 一下改動 · 安全性檢查 · 威脅模型 ·
  隱私檢查 · 可用性檢查 · 這樣使用者會不會困惑 · 審一下計畫
  NOT for: bug investigation → /bug-investigate · format runs (the Stop hook) ·
  lint / analyze (the engineer commit gate; manual
  the project's lint command) · authoring the plan or spec under review →
  /plan · FIXING the findings — this skill only reports
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
| Code review (semantic, architectural, lint-uncatchable) | `code-reviewer` | the uncommitted diff | **return to caller** (no file) |
| Engineering-plan **should-this-exist** (2 scope-gated dimensions; the other 9 are graded on the diff by `code-reviewer`) | `engineer-plan-reviewer` | an engineering plan | **return to caller** (no file) |
| **PM-plan rules compliance** (`P1`–`P8` + plan integrity, sub-check by sub-check) | `pm-plan-reviewer` | a pm plan | **return to caller** (no file) |
| **Security** (threat model, attack surface) | `security-reviewer` | the diff — never a plan | **return to caller** (no file) |
| **Privacy** (data-minimization) | `privacy-reviewer` | the diff + store declarations — never a plan; "should this be collected at all" is PM rule `P8` | **return to caller** (no file) |
| **Conformance** (the residue /qa's spec tests can't pin — §Non-goals, token drift, stale docs, `spec-should-change`) | `conformance-reviewer` | approved product / design plan vs the diff, after QA | **return to caller** (no file) |
| **Test design** (change-detectors, untagged cases, illegal fakes, partition breaches) — **not** replaced by `plan-mutation`, which grades the opposite error and scores a change-detector perfectly | `test-reviewer` | every test the diff adds / changes — engineer-owned and `/qa`-owned alike | **return to caller** (no file) |
| **UX** (usability, first-time-user confusion) | `ux-reviewer` | a design spec (at design time; it right-sizes itself — say "go deep" / "light pass" to override) | **return to caller** (no file) |
| **Feasibility** (downstream deliverability, early-bounce) | `feasibility-reviewer` | a PM plan (designer + engineer lens) or a design spec (engineer lens) — never the engineering plan | **return to caller** (no file) |
| **Consistency** (cross-feature mechanism parity — second truth sources, sibling check-set divergence, duplicate capability) | `consistency-reviewer` | the diff + the plan's §Conformance 同儕 rows, vs the sibling implementations + `.claude/rules/consistency.md` mechanism table | **return to caller** (no file) |

Pick by trigger phrase. If the user asks for "review my changes" without
specifying, ask once which dimension(s) they mean — don't guess. If they ask for
several, spawn them in parallel.

**"Does this design meet the design rules"** is the `ux-reviewer`;
mockup-fidelity is a manual founder check. The `conformance-reviewer` checks
**shipped code vs the approved spec** (is a required state / motion / interaction
actually implemented), not mockup-vs-design-rules.

**Every reviewer above is 不落檔** — they grade and **return their
findings to this dispatcher** (security/privacy/ux/feasibility/consistency:
each item `passed` / `warning` / `critical`, looped until all `passed`;
code-reviewer / engineer-plan-reviewer: the consolidated report
inline). No file output. (No count here on purpose — the roster grows, and a
hardcoded number is a staleness bug waiting to print.)

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

## After the agent returns

The agent returns its findings (counts for code and the engineering plan;
graded findings for security / privacy / ux / feasibility) + a one-line overall assessment.
**Every finding gets an explicit verdict — silent skipping is forbidden.**

### Verdict per finding

**Before verdicting, pass each finding through two checks** (the measured
failure both ran the other way — see `house-rules §Gate every reviewer finding
through severity + minimalism`): a **severity check** — is it truly CRITICAL
(data-loss / crash / security), or a minor / self-healing trade-off wearing the
label? — and a **minimalism check** — does existing domain state (a code, an
enum, a nullable) already model the fact, so the "fix" would build a parallel
marker? Reviewers propose; the engineer decides. Down-grading an over-graded
finding, with the reason stated, is a legitimate verdict — building
infrastructure for one is not.

For each finding the reviewer filed, report a verdict from this set:

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
(`plan/SKILL.md §Gate loop policy`). A `critical` still standing after that, or a
`warning` you don't FIX, goes to the user — `critical` is never DISMISSed without a
landed class-eliminating rationale (for ux, a written design rationale).

### Posting findings to the plan row (plan reviews)

When the review target is a **plan row** (a PM / Design / Engineering Plan under
`/plan`, not a code diff), post the graded findings + their dispositions as a
**Notion comment on that plan row** — invoke the `archivist` skill (`comment
<page-id> - --commit`, findings piped on stdin). This leaves a durable,
founder-visible collaboration trail on the plan itself, consistent with the 不落檔
stance — a comment annotation, **not** a file.

### Posting findings to the PR (code / security / privacy reviews)

When the branch under review **has an open PR**, the report is posted to that PR
as a comment — **twice**, and the order is the rule:

1. **Before any fix lands** — post the reviewer's findings as returned. Covers
   `code-reviewer`, `security-reviewer` and `privacy-reviewer` alike. Open the
   comment with the sha that was reviewed — `Reviewed at <git rev-parse HEAD>` —
   then record it: `plan-cycle reviewed <that sha>`.
2. **After the fixes land** — post the disposition: every finding from comment 1
   with its verdict (FIX / DISMISS-with-rationale / ESCALATE / DEFER) and what
   actually changed, one line each.

**Why post first rather than once at the end.** Once fixing starts, the finding
list can only be reconstructed from memory, and a report written afterwards
silently narrows to whatever happened to get fixed — the findings quietly
dropped leave no trace, which is the exact failure the verdict protocol exists to
prevent. The pre-fix comment is the evidence a finding existed; the post-fix
comment is answerable to it.

**Why the sha.** A review comment without one records that a review happened but
not *against what*, so "how far has the branch drifted since" has no answer — and
on PR #204 the answer went unasked for 40+ commits and 24 hand-found defects. The
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
`/review` to confirm clean** when CRITICALs existed or the diff was non-trivial.
The re-review diff is small and re-running is cheap.

**Why report-only:** an agent auto-fixing in the background is fast but
asymmetric — a bad fix that lints clean (semantically broken, behavior-altering,
wrong design intent) ships silently. Report-only keeps the human in the loop on
every change.
