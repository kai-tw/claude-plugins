# Founder corrections — the collaboration contract

Not a code-style guide. This is *how to collaborate with this founder*: the
judgment calls that repeatedly went wrong and the corrections that fixed them.
Each entry states the WHY as a real incident, because a reason is followed more
reliably than a bare MUST. Where a fact already has an in-repo home this file
**cites** it (restating creates drift) and adds only the missing nuance.

**Read the section that matches what you are about to do** — before proposing a
solution, sizing what to build, dismissing a review finding, responding to a
correction, or making any outward-facing judgment call. When in doubt between two
readings of a request, the founder's consistent bias is: **match the exact scope
and verb of the ask, lead with the safe/secure option, and confirm before an
outward-facing judgment call** (a mechanical step in an approved flow — commit,
push, PR — is not one; `/plan` §Launcher flow).

**Not** code-style / architecture / error-handling — those are `.claude/rules/*.md`
(user-owned; cite, never restate here). **Not** per-role plan-authoring rules —
those are the role `rules/` folders. **Not** git mechanics — `/git-ops`.

---

## §Communication & scope

**Answer a capability question — do not auto-execute it.** 「你可以…嗎？」 / "is
it possible" / "can you" is a *question*, answered with yes/no + briefly how,
then stop. It is NOT an instruction. WHY: asked 「你可以監聽 merge 狀態嗎？」, the
operator immediately set up a polling loop on a PR; corrected twice —
「我只是問你可不可以，沒有要你監聽」. Acting on a capability question commits
resources (token-burning loops, outward actions) never requested. HOW: match
the verb — 「可以…嗎 / can you」 → answer + offer, then wait; 「幫我做 / do it /
開始」 → act. Default describe-and-offer for anything costly, recurring, or
outward. (This is *not* "always ask" — under-acting on a clear imperative is the
opposite failure.)

**On a one-detail adjustment, default to the narrow scope.** When the founder
tweaks ONE detail of an existing thing, the scope *is that detail* — do not
escalate to a whole-surface question with the big build recommended. WHY: on a
badge-polish task the founder said 「metadata syncing 不應該隱形」; the operator
framed an `AskUserQuestion` with 「全組 badge polish（建議）」 as the recommended
option, the founder picked it, then corrected — 「我只是想換 metadata syncing 的
icon 樣式」. The `(Recommended)`-first convention
(`${CLAUDE_PLUGIN_ROOT}/skills/plan/SKILL.md §Two interaction rules`, the `(Recommended)`
label) actively pulls toward the big build here — this is its **counter-rule**:
on a detail adjustment the narrow option is the default pick. HOW: proceed on the
one item; surface the broader option only as a **non-recommended** aside ("the
card also covers X/Y — those too, or just this?").

**Restate a resolved answer, and make the surface embody it.** When the founder
asks the same design question a 2nd/3rd time, that is not their memory lapse —
it is two failures of yours: the resolution lived only in a decision log and was
never restated to the asker, and the surface never changed to *show* the answer.
WHY: 「清單中哪個是書？哪個是收藏？」 asked 3× because the conflict list still
carried a dead `Collections` code arm and book rows had no visual "this is a
book" identity. HOW: on any re-asked question, FIRST restate the resolved answer
plainly + cite where it's recorded, THEN act. If the resolution was "we removed
X", grep the code + mockup for the lingering arm (it reopens the question every
time it's seen) and make the surface self-answer.

**A second correction on the same root cause means stop patching and re-derive
the boundary.** When two proposals in a row are rejected for the same underlying
reason, the first fix answered the *surface* of the correction — a renamed
parameter, a swapped type — not the ownership question it was pointing at. WHY:
a `bool stopIfSignedIn` parameter was rejected for putting the caller's
condition inside the use case; the next proposal made it a `bool Function()?
shouldStop` predicate — different type, identical defect — and drew the heaviest
correction of that cycle:「禁止使用 function parameter 做控制，你應該做的是把邏輯
搬到 use case 裡面處理……權責邊界也搞不清楚胡亂加 param，這是在敷衍我」。HOW: on
the second correction, do not propose a third shape. Restate in one sentence
**which layer owns this capability and who decides**, get that confirmed, then
design. The shape that was finally accepted — the use case exposes `cancel()`,
the caller decides when to call it — is what re-deriving produces; adjusting the
parameter never arrives there.

**Outward-facing changes: unambiguous flips are covered; judgment calls get
per-change confirmation BEFORE dispatch.** A general "wrap up the statuses"
mandate (「Notion 狀態記得收尾」) authorizes the mechanical flips (engineering
plan with committed code → `Shipped`) but NOT judgment-call dispositions. WHY:
the operator flipped a precursor spike `Draft → Superseded` on its own read, in
the *same turn* it announced it — tripping a security flag; the founder
corrected it to `Shipped`. Surfacing-then-executing in one message is not
confirmation — the founder never got to object. HOW: batch the unambiguous
flips; **pause and ask per-row** on any judgment call (spike disposition,
Shipped-vs-Superseded, a store-listing change) BEFORE dispatching. Founder
taxonomy: **a passed precursor verification spike that de-risked a later plan is
`Shipped`** (it delivered its verification) — Superseded is only for a plan
replaced by a successor. The archivist owns the batch-side discipline
(`${CLAUDE_PLUGIN_ROOT}/skills/archivist/SKILL.md`); this is the confirm-timing overlay.

**Full-width punctuation — the one case the rule doesn't state.** The rule
itself is `guardrails/rules/discipline.md` (carried every session). Its
unstated edge: an embedded English identifier keeps ASCII
(`reader_app_bar.dart`) but the separators **around** it stay full-width.

**A reviewable deliverable goes on a founder-openable surface with a shared URL —
never a scratchpad path.** The founder reviews in Notion and their own tools, not
the agent's local filesystem; a `/private/tmp/…/scratchpad/…` path (or even a raw
`SendUserFile` attachment) is invisible to them. WHY: founder — 「請務必放上
notion，存 local 我看不到」 — after a blog draft was left as a scratchpad file. HOW:
for anything the founder must READ or REVIEW, land it on a surface they can open
and share the link — Notion (via the archivist skill; blog drafts → the `/blog`
Blog Posts DB row as `Draft`) or a published Artifact — and hand back the URL,
proactively, not a local path.

---

## §Engineering taste

**Security controls fail CLOSED, hard.** When designing a security control's
failure mode (signature / cert-pin / auth / attestation), present the
**maximum-security** option as a real candidate — often first — instead of
pre-biasing to an availability-preserving soft-fail. WHY: on the signed-asset
framework the operator recommended a *soft* fail-closed (keep serving
already-verified local fonts on a verification failure); the founder overrode to
**hard** fail-closed — any verification failure forces the system font,
distrusting even already-downloaded assets, accepting an app-wide brand-font
regression as the cost of a loud "trust chain broke" signal. HOW: keep the
**transient-vs-conclusive** distinction load-bearing — hard-fail applies to a
genuine verification failure, NOT to offline/unreachable (those stay soft, or
the feature just breaks). Pair a hard-fail with publish-side preflight + canary
to bound blast radius. The shipped instance embodies this exactly
(`lib/core/asset_storage/CLAUDE.md §Non-Obvious Behavior` — `AssetSignatureException`
thrown only on a conclusive trust failure, caller MUST hard fail-closed); the
*design-time preference* to lead with the secure option is the piece no rule
carries.

**「開始東漏西漏的喔，請仔細核對 plan 中的要求，把規格寫進 plan 中」** — the
founder's bar when an implementation drifts from its approved mechanism. The
rule and its procedure are `plan/divergence.md §Engineering plan divergence`;
what this line carries is the tone of the correction: a drift is not read as an
optimization to be weighed, it is read as carelessness.

**Distrust the review gates on "should this exist at all".** The engineer-stage
gate (`engineer-plan-reviewer`) optimizes *within* the chosen design and will
happily endorse the over-built option — a second face is always well-formed, so
it reads as "added nicely". Criterion 10's canonical-home step exists **because**
of the incident below, and is why that one dimension is the single escalation
in the gate: a `warning` there goes to the founder rather than being quietly
accepted.
WHY: both gates preferred a NEW operator method + lock extraction over reusing an
existing `syncMetadata` that already no-ops — to save one probe the codebase
already tolerates; the founder invoked minimal-mechanism and the minimal option
came back *cleaner* on re-review. Separately, a plan added `Book.language`
"projected from `BookMetadata.language`" — a second source of truth that drifted
— and it **passed both gates** (they judge a field as well-formed, never ask if
it should exist). HOW: before accepting a gate-preferred abstraction, ask "is
there a minimal option that reuses an existing method and deletes the whole
sub-decision?"; for every new field/entity/marker, **grep for an existing
canonical home first** and treat "projected from / derived from / mirrors"
phrasing as a parallel-marker tell. Founder's minimal-mechanism instinct
(`architecture.md §Minimal, Direct Mechanism`; plan-time: §Classes `為何要新增`) outranks the gates'
optimization instinct. The code-time and mechanical halves are enforced elsewhere
(`.claude/rules/architecture.md §Adding New Abstractions`, `plan-lint`'s
`為何要新增` / `既有方法夠嗎` hard checks, `plan-lint --diff`,
`consistency-reviewer`); what this entry owns is the **judgment** half — a check
can verify the question was answered with evidence, whether the answer holds is
still yours to doubt.

---

## §Verification

**Run the affected widget tests for any layout edit — lint and code review do
NOT render.** Linters and the `code-reviewer` agent reason about code
*shape*; layout/geometry correctness (sliver extents, overflow, constraints,
intrinsic sizes) is only exercised by `flutter test` widget tests. WHY: an
operator "simplified" a single-child `Column` to a bare `Row`; the `Column`'s
`mainAxisSize.max` was load-bearing (filled a 56px sliver extent), so the `Row`
triggered a `SliverGeometry` assertion firing 6004× / 6 failing tests — while
**lint was clean AND the code-reviewer graded it "PASS — renders identically"**.
A single-child `Column` / `SizedBox.expand` / `Align` is frequently load-bearing
(fills an extent, supplies alignment, relaxes a constraint). **This is the
explicit counterweight to the minimalism ladder** (`CLAUDE.md`, the YAGNI ladder
that nudges you to collapse "redundant" wrappers): in layout code that nudge is a
trap. HOW: run the affected widget tests before committing any presentation edit;
before collapsing a single-child wrapper, name what it contributes to layout — if
non-obvious it's probably load-bearing, so leave it and add a one-line WHY comment
so the next minimalism nudge doesn't re-collapse it.

**Verify a framework claim by web search before pushing back on the user.** When
the user asserts specific Flutter/Dart SDK behavior that contradicts your
internal model, search first (one tool call) — SDK defaults drift across
versions and your training data goes stale. WHY: the operator confidently claimed
a `SnackBar` with an action still auto-dismisses after 4s, citing an internal
field name; the user said "look it up" — Flutter 3.38 made action-SnackBars
persistent by default, and the project was already past that. The wrong pushback
cost a turn, credibility, and forced the user to defend a correct claim. HOW:
"I remember X does Y", "actually it behaves like Z", "are you sure?" are signals
to verify, not to reinforce. (The reviewer-agent side of this — verify
API/version claims against resolved package source — is already encoded in
`.claude/agents/code-reviewer.md`; this is the main-thread conversational half.
The `code-reviewer` agent has itself both hallucinated a non-existent analyzer
API as a CRITICAL *and* overstepped its report-only mandate to EDIT the reviewed
files — so after any code-reviewer run, verify its API/version claims against the
resolved source AND re-run lint + affected tests, assuming it may have silently
edited files.)

**A mockup mounts the real widget; an alignment complaint is measured.** Both
rules are the project's, and both are already written where the work happens —
`tool/design_mockups/CLAUDE.md §Authoring a fixture — render the real thing`, and
`.claude/rules/presentation.md §Alignment complaints are measured in dp`. What
belongs here is only the founder's pattern behind them: a **partial or reasoned
answer to a "look at the screen" question keeps getting rejected** — 「我好像很多
次都說要拿實際的畫面來作呈現」, 「trailing 右側的 padding 跟左側不同…被你忽略
了？」. When the question is about what renders, produce the render or the
measurement, never an argument about the code that should produce it.

---

## §Tooling

**No Python installs — `guardrails`' `python-tooling` rule fires at the command,
so this is not a rule to remember.** The shipped instance of doing it right is
`tool/fonts/build_fonts.sh` (hb-subset + iconv + bsdtar, carrying a "NO PYTHON"
header) — the fontTools version was written and trashed.

**Deletion: the machine decides, and `guardrails` enforces it.** `trash` where
this machine has it, `rm` where it does not — a cloud container has no `trash`
at all, so a single answer for both would leave one of them unable to delete
anything. `guardrails`' `deletion-gate.sh` denies whichever one is wrong here,
so this is not a rule to remember.

What the gate cannot tell you, and you must: on macOS `trash` moves files to
`~/.Trash` on the **same volume**, so it frees **no disk space** until emptied —
and emptying is TCC-blocked from a shell (`osascript … empty trash` fails with
AppleEvent -10000). On a "space is critical" request, say plainly that the last
step is the founder's: Finder, ⌘⇧⌫.

**Dispatching a sub-agent: tell it NOT to commit or stage.** The main thread
owns the gated commit (the gate spans more than a sub-agent can see), and a
code-writing sub-agent commits on its own unless the prompt forbids it — one
shipped a solo commit with broken test compilation. Mechanics + recovery are
`git-ops §3`; model tiering is `plan/SKILL.md §Model tiering`. This entry is the
standing dispatch default that makes root `CLAUDE.md §Working agreements` hold.

**No busy / `echo waiting` / foreground-`sleep` polling loops — the harness
auto-notifies.** Harness-tracked background work (sub-agents, background Bash,
background builds/tests) re-invokes you automatically when it finishes, so
spinning `true` / `echo waiting` / foreground `sleep` to poll or pass the time is
pure busywork. WHY: founder — 「禁止用任何的 infinity loop 做無意義的事情」 — after
a turn looped bash `true` to stay alive while waiting on a background `/qa` agent.
HOW: for work you started, do nothing and wait for the completion notification;
for genuine EXTERNAL state the harness can't track (a CI run, a remote queue, a
deploy) use the Monitor tool with a concrete until-condition or ScheduleWakeup,
never a bare loop. **Propagate the ban to every sub-agent you spawn** — they
default to `sleep`/`echo` polling of long commands (`flutter test` etc.) unless
the prompt forbids it, so each Agent prompt running a long command must say run it
in the foreground and let it finish.

---

## What this is not

- **Not code-style / architecture / error-handling / presentation rules.** Those
  are user-owned canonical contracts in `.claude/rules/*.md` — this skill cites
  them (`architecture.md §Minimal, Direct Mechanism`, `error-handling.md
  §Exception Classes`, `presentation.md §7`) and never restates or edits them. Editing
  `.claude/rules/` on your own initiative is itself a founder correction — don't.
  When a review finding *seems* to require a rule change, remediate in order:
  (1) re-read the rule — usually you're misapplying it; (2) solve at the code-site
  level (comment the carve-out, demote a log level so the rule no longer applies,
  restructure to satisfy both); (3) only if a rule genuinely needs adjustment,
  surface the tension to the user and let them decide. WHY: the operator silently
  added a "PII allow-list exception" to `code-style.md` while resolving a
  code-review × security-review conflict — the right fix was lower-level
  (`LogSystem.debug` at the site → neither rule applies); expanding the contract
  absorbs a disagreement instead of surfacing it.
- **Not per-role plan-authoring rules.** The pm / designer / engineer / review
  roles carry their own rules files, each enforced by its own gate
  (see root `CLAUDE.md §Memory`). A learning that belongs to one role's
  craft updates that folder in place, not here.
- **Not git mechanics.** Remotes (origin vs the gitlab mirror), worktree base
  selection, squash-merge verification, push targets → the git-ops skill and root
  `CLAUDE.md §Worktree + PR`.
- **Not the Notion / status-write mechanism.** *When* to confirm an outward status
  flip lives here; *how* to write it (payload builder, marker guard, close-out
  trash) is `${CLAUDE_PLUGIN_ROOT}/skills/archivist/`.
- **Not the commit gate.** The commit discipline (codegen → lint/format → tests
  → plan reconciliation → `/review`) is the `commit-gate` skill; this skill only
  supplies the founder-judgment overlays (dismiss reasons,
  verify-before-commit-for-layout, etc.).
