---
name: house-rules
description: |
  The founder collaboration contract — the behavioral rules a new operator
  (human or model) must follow to work the way this founder (Kai) expects,
  distilled from ~30 real corrections across communication & scope, engineering
  taste, verification, and tooling. Each rule carries the incident that produced
  it, so a weaker model follows the reason rather than a bare MUST. (Root
  `CLAUDE.md §Working agreements` is the always-loaded digest; this is the full
  catalog behind it.)
  CONSULT BEFORE: proposing a solution · choosing how much to build · dismissing
  a review/gate finding · any irreversible or outward-facing call (store listing,
  Notion status, push) · collapsing a layout wrapper · contradicting the user on
  framework behavior · responding to founder feedback or a correction.
  TRIGGER: how does the founder like X · before I respond to this feedback · the
  founder said X — what should I do · is this in scope · should I do the whole
  thing or just this · can I flip the Notion status · do I fix or dismiss this
  finding · founder correction · collaboration rules · house rules ·
  你可以…嗎 · 幫我改一下這個細節 · 這個 finding 我覺得不用改 ·
  Notion 狀態幫我收尾 · 這樣算 in scope 嗎 · 這個對齊看起來怪怪的 ·
  創辦人的偏好 · 跟 Kai 合作的規則 · 我該怎麼回這個回饋
  NOT for: code-style / architecture / error-handling → `.claude/rules/*.md`
  (user-owned; cite, never restate here) · per-role plan-authoring rules → the
  pm / designer / engineer / review role `rules/` folders · git mechanics →
  /git-ops and root `CLAUDE.md §Worktree + PR`
---

# House Rules — the founder collaboration contract

This is not a code-style guide. It is *how to collaborate with this founder*:
the judgment calls that repeatedly went wrong and the corrections that fixed
them. Each rule states the WHY as a real incident, because a weaker operator
follows a reason it understands better than a bare MUST. Where a fact already
has an in-repo home, this skill **cites** it (restating creates drift) and adds
only the missing behavioral nuance.

Read the section that matches what you are about to do. When in doubt between
two readings of a request, the founder's consistent bias is: **match the exact
scope and verb of the ask, lead with the safe/secure option, and confirm before
anything outward-facing.**

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

**Dismiss a finding with ONE substantive reason — precedent is 推託.** Rejecting
a code-review / gate finding requires a reason rooted in the code's actual
behavior, types, or invariants. "Other sibling code does it" and "the doc
example does it" are dodges (推託) — they answer *is this consistent?*, not *is
this correct?*, and consistency can co-exist with a shared latent bug. WHY: the
founder graded three dismissals of a missing-`onError` finding — two precedent
appeals rejected, only "the source is a pure broadcast controller fed solely by
`.add()`, so it structurally cannot emit an error" accepted. **If precedent is
your only defense, that is the signal to FIX, not dismiss.** This extends
`${CLAUDE_PLUGIN_ROOT}/skills/review/SKILL.md §Verdict per finding` (which already demands a
specific, written rationale) with the founder's bar: a sibling-pattern citation
can *pass* that written rule while still failing here.

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

**繁體中文 prose uses full-width punctuation.** In Chinese prose to the founder —
Notion plan bodies, chat, commit messages — use `，。：；！？（）`, not their
ASCII forms. WHY: half-width punctuation inside CJK reads as broken/ASCII;
founder corrected 「逗號請用全形」. Embedded English identifiers keep ASCII
(`reader_app_bar.dart`) but the separators around them stay full-width; code
blocks and file paths are exempt. The ARB/translated-value side is already
covered by `lib/i18n/CLAUDE.md §Full-width CJK punctuation` — this extends the
same register to **prose and plan bodies**, which no rule currently states.

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

**Replace a defensive `!` with an if-null domain guard.** → **Moved** to the
code-time impl rule `.claude/rules/error-handling.md §Exception Classes` (glob
`lib/**` — it now auto-loads while the Dart is being written, which is where it
has to fire; the review agents that cite `error-handling.md` pick it up too). No
hole left here. Incident: the founder pushed back twice on `return header!;` in
`GoogleAuthApi.getAuthHeaders` — 「production code 用 ! 判斷 null？好危險？」.

**After fixing a shared component, hoist the fix INTO it.** → **Moved** to
`.claude/rules/presentation.md §7 Shared Component Location & Contract` (glob
covers `lib/app/widgets/**` + `lib/features/shared_components/**`). No hole left
here. Incident: founder — 「可以抽成共用嗎？我不希望未來套用時還需要再走一次這個
修正的流程」 — after the licenses master-detail corrections were left inside
`LicensesPage` instead of the shared `AdaptiveListDetailLayout` (shipped contract:
`lib/app/widgets/adaptive_list_detail/adaptive_list_detail_layout.dart`).

**Model "value OR auto/default" as a nullable canonical type.** A setting that is
"a specific value OR auto" is `CanonicalType?` with `null` = auto — NOT a bespoke
parallel enum, NOT a value+flag pair. WHY: on the reader definition-language
setting the operator first built `enum ReaderDefinitionLanguage {auto, zhHant,
…}`; the founder walked it back to `KnownLocale?` (null = auto). A bespoke enum
duplicates the canonical type (a parallel-marker smell); value+flag encodes a
sum type as a product → redundant/ignored state (`auto=true` with a stale
language). Nullable-canonical matches the codebase idiom (app locale `Locale?`,
`pageTurnAnimation` null = derive). `.claude/rules/architecture.md §Minimal,
Direct Mechanism` already names both "value + flag rather than a nullable
canonical type" and the parallel-marker anti-pattern — this is the pattern-match
to reach for. HOW: persist by the canonical's **natural key** (language tag;
absent = auto), not an enum `.index`; domain `copyWith` for the nullable is
pure-Dart `T? Function()?`, never Flutter's `ValueGetter` (breaks
`domain_pure_dart_imports`).

**Ground every load-bearing code claim in source before you write it.** In an
engineering plan (or a solution proposal), every method/API signature, "preserves
X verbatim", "matches the current predicate", or "what this helper resolves to"
must be read from the actual source BEFORE it's written — not asserted from
memory. WHY: on one plan ~half of six audit round-trips came from assumption-
authored claims — a whole null→fallback contract rested on a `parseLocale`
signature that didn't exist; a "verbatim preserves current logic" claim used the
wrong predicate (`metadataExists` vs the state holder's real `bookExists`). **"This is
the same as the current X" is the highest-risk line in any plan** — it reads as
verified and is usually assumed. HOW: read the declaration before asserting its
shape; read every call site a "matches existing" claim covers and quote it; when
a design element is renamed, grep the whole plan body for the old name. This
extends the engineer role's evidence rules (`${CLAUDE_PLUGIN_ROOT}/skills/engineer/rules/`,
the P3 family) from external-package claims to internal-code claims.

**Implement the APPROVED plan's mechanism verbatim — don't reinvent a simpler
stand-in mid-iteration.** During device-bug fixes, code to the plan's specified
mechanism exactly; if the plan is underspecified, write the precise state table
INTO the plan first, THEN build to it. WHY: on the narration prev-button
(PR #76) the approved eng plan specified a repository-side threshold judgment
(this-chapter `elapsed` vs a threshold `T`, per chapter, continuous), but during
device iterations the operator re-invented it as a view-side "nearest earlier
narrated chapter" + a one-shot 3s timer only at the first chapter — breaking the
restart-grace re-arm and the button-disable on three counts; founder — 「開始東漏
西漏的喔，請仔細核對 plan 中的要求，把規格寫進 plan 中」. HOW: before writing a
device-reported fix, re-read the plan (`ntn pages get <eng-plan-id>` + design /
product) and grep the exact mechanism (門檻 / prev / elapsed / 自動), grounding
both the action predicate and the button-disable predicate in the plan, not
intuition. The plan's spec is itself a load-bearing claim — the same source-first
bar as above applies to it.

**Gate every reviewer finding through severity + minimalism before implementing
it — reviewers propose, the engineer decides.** A report-only reviewer's severity
label and example fix are inputs, not orders. Before acting on one, pass it
through (a) a **severity check** — is it truly CRITICAL (data-loss / crash /
security) or a minor/transient trade-off dressed up? — and (b) a **minimalism
check** — does existing domain state (`code`, an enum, a nullable) already model
the fact, so no new flag/field is needed? WHY: the operator reflexively added an
`isImporting` flag to a **shared** state type because the code-reviewer graded a
CRITICAL, when the real impact was a self-healing ~2s deferral (not CRITICAL) and
`LoadingStateCode.backgroundLoading` already modeled it (an import IS a background
load); founder caught both the over-grade and the parallel marker. Down-grade or
push back on an over-graded finding instead of building infrastructure for it.
(This is the diff-finding sibling of the plan-stage gate distrust below.)

**Distrust the review gates on "should this exist at all".** The engineer-stage
gate (`blueprint-reviewer`) optimizes *within* the chosen design and
will happily endorse the over-built option; it has no canonical-home step.
WHY: both gates preferred a NEW operator method + lock extraction over reusing an
existing `syncMetadata` that already no-ops — to save one probe the codebase
already tolerates; the founder invoked minimal-mechanism and the minimal option
scored *higher* on re-review. Separately, a plan added `Book.language`
"projected from `BookMetadata.language`" — a second source of truth that drifted
— and it **passed both gates** (they score a field as well-formed, never ask if
it should exist). HOW: before accepting a gate-preferred abstraction, ask "is
there a minimal option that reuses an existing method and deletes the whole
sub-decision?"; for every new field/entity/marker, **grep for an existing
canonical home first** and treat "projected from / derived from / mirrors"
phrasing as a parallel-marker tell. Founder's minimal-mechanism instinct
(`architecture.md §Minimal, Direct Mechanism`, engineer P3.5) outranks the gates'
optimization instinct. (The **code-time half** — extend the new-abstraction audit
to a new entity field / marker, and read "projected from / derived from /
mirrors" as the parallel-marker tell — **has moved** to
`.claude/rules/architecture.md §Adding New Abstractions`, so it now fires while
the field is being written rather than only when a gate is consulted. What stays
here is the **judgment** half: distrust a gate's endorsement on "should this
exist at all".)

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

**Device-verify a user-facing feature before "done", and prove the buggy path
is actually REACHED.** Green unit tests + code-review + every plan gate can all
pass while the feature is 100% dead on device. WHY: on PR #87 a lazy
lazily-constructed provider calling `..init()` that **no widget reads** never ran
`init()`, so the fire-and-forget file-association state holder was silently dead —
and unit tests, which call `init()` directly, structurally cannot catch "the app
never calls `init()`"; only the device gate caught it. HOW: a fire-and-forget
side-effect holder (drives navigation/subscription, no widget consumes it) must
be constructed eagerly, not lazily — whatever your DI calls that. Before trusting
any root-cause diagnosis, grep for a consumer /
non-lazy trigger to prove the buggy code is reached, not just that its internal
logic is wrong; drive the real flow on device before "done". (Verbatim-migrating
native code can also carry a latent data-loss bug — e.g. a `copyToCache` that
deletes the user's in-place file — forward unflagged; audit migrated code for
data-loss behavior even when preserving it.)

**UI mockups mount the REAL `lib/` widget with mock data — never a hand-built
imitation.** A design-mockup render mounts the actual screen/widget and mocks
only its data; it never re-implements part of it as a Material 3 approximation.
WHY: recurring correction — 「我好像很多次都說要拿實際的畫面來作呈現，而不是只
渲染部分」 — after the operator rendered a hand-built preview instead of the real
`ReaderBottomSheet`. A partial imitation drifts from the real screen and misses
real layout/tokens/states; the harness exists precisely so the real widget tree
paints and can't drift. The full contract (all cases, including the net-new
guarded-sketch path) is already encoded — follow
`tool/design_mockups/CLAUDE.md §Authoring a fixture — render the real thing`.
Before rendering anything "partial", ask: does the real widget already exist? If
yes → mount it.

**For an alignment complaint, decode the screenshot and measure glyph gaps in
dp.** Reasoning from `contentPadding` constants misses glyph-internal whitespace
entirely; only measuring rendered pixels catches it. WHY: the operator "fixed" a
licenses-tile alignment complaint by removing an outer `Padding` (structural
reasoning) when the real issue was the trailing chevron sitting further from the
right edge than the title from the left — a Material icon glyph carries ~16dp of
its own optical whitespace inside its 24dp box, so at symmetric 16 padding the
chevron tip lands ~32dp off the edge while text hugs ~17dp. Founder —
「trailing 右側的 padding 跟左側不同…被你忽略了？」. HOW: decode the screenshot
(python3 stdlib is fine for a one-off — decompress the IDAT, reverse the PNG
filters, scan luminance for the leftmost/rightmost dark pixel per y-band),
compute left-gap vs right-gap in dp (÷ devicePixelRatio), and re-measure after
the fix. Icon-vs-text rows are inherently asymmetric — the app's nav-row idiom
(`lib/app/widgets/navigation_list_tile.dart`) balances a leading icon against the
trailing chevron (icon↔icon, both carry whitespace) rather than tweaking a magic
`contentPadding.right`. And before dropping a subtitle to "simplify" a row, check
it isn't legally load-bearing (a `licenseType` attribution line is the only
attribution on rows with no detail page).

---

## §Tooling

**No Python installs for build/dev tooling.** Reach for system-native tools
already present — HarfBuzz (`hb-subset`/`hb-shape`), bash, `iconv`, `bsdtar`,
`curl`, `node` single scripts — before Python + pip. WHY: founder — 「我很不喜歡
python 會污染系統這點」; a fontTools/Python version of the font build was written
then trashed at the founder's request in favor of `tool/fonts/build_fonts.sh`
(hb-subset + iconv + bsdtar, which carries a "NO PYTHON" header). HOW: only
propose Python if no non-Python path exists — and then in an isolated venv, and
flag it. Exemption: a **one-off stdlib** `python3 -c` that installs nothing (e.g.
decoding PNG pixels for the alignment-measurement above) is fine.

**`rm` is denied → use `/usr/bin/trash -v`; same-volume trash frees no disk until
emptied.** The permission layer denies `rm`; delete with `/usr/bin/trash -v
<targets…>` (system binary, multiple targets). WHY/caveat (machine-local — these
are macOS host facts on *this* machine, not repo config): `trash` moves files to
`~/.Trash` on the **same volume**, so it frees **no disk space** until the Trash
is emptied; and emptying from the shell is TCC-blocked
(`osascript … empty trash` fails with AppleEvent -10000, and `~/.Trash` itself is
TCC-protected). HOW: for a "space is critical" request, tell the user the final
step is theirs — empty the Trash manually in Finder (⌘⇧⌫); the shell cannot do
it. (The use-`trash`-not-`rm` directive is also stated in
`${CLAUDE_PLUGIN_ROOT}/skills/archivist/SKILL.md`.)

**Dispatching a sub-agent: forbid its commit, and match the model to the task.**
Two standing defaults govern every sub-agent you spawn. (1) **Tell it NOT to commit
or stage** — the main thread owns the gated commit (the gate spans more than a
sub-agent can see); a code-writing sub-agent runs `git commit` on its own unless
the prompt forbids it, and one shipped a solo commit with broken test compilation.
The mechanics + recovery (review its diff, amend clean) are the git-ops skill's
(`§3 Sub-agent dispatch hygiene`) — this is the standing dispatch default that makes
root `CLAUDE.md §Working agreements` hold. (2) **Match the model to the task's
complexity** — a mechanical, well-specified job (a rote refactor, a grep-and-report)
goes to a cheaper Sonnet-class agent; genuine design / judgment work (a plan, an
ambiguous fix) needs an Opus-class one. Over-powering a rote job burns budget;
under-powering a judgment job ships shallow work.

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
- **Not the commit gate.** The four-leg commit discipline (codegen → lint/format
  → tests → `/review` → auth) is `${CLAUDE_PLUGIN_ROOT}/skills/engineer/references/closeout.md
  §Step 5.5`; this skill only supplies the founder-judgment overlays (dismiss
  reasons, verify-before-commit-for-layout, etc.).
