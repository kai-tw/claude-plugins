---
name: qa
description: |
  Project-specific test-authoring craft.
  Owns `test/spec/**` — the spec-derived tests pinning the shipped flow to the
  approved product / design plan; the engineer role owns the rest of `test/**`
  (contract-derived).
  Applies formal techniques (equivalence partitioning, boundary
  analysis, decision tables, state transition, pairwise, error
  guessing, FMEA-lite, mutation sensitivity) so coverage is
  systematic, not anecdotal. Scans a category blind-spot list and a
  compact failure-class catalog (risk-based, not exhaustive) before writing a line of test
  code. NOT a debugger — the deliverable is the test that catches
  the bug next time, not the fix.
  TRIGGER when: "/qa", "write a test for X",
  "test cases for X", "regression test for X", "cover X with
  tests", "write tests for X", "add tests for X", "qa for X".
  NOT for: fixing the bug itself, authoring standalone test-plan
  documents, or "just stub a quick test" requests — refuse
  inline assertions and demand the formal-technique flow.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - AskUserQuestion
  - Agent
---

# Test Authoring

> **Iron Laws.** Break any one and the test is rejected.
>
> 1. **Risk-based, not coverage-based.** Spend test budget where
>    failure hurts users most. 100 % coverage is not a quality
>    signal.
> 2. **Behavior, not implementation.** Tests must survive a
>    refactor that preserves behavior. Change-detector tests that
>    mirror the code block future work — rewrite or delete.
> 3. **Every test case is tagged with the technique that produced
>    it.** A case that doesn't name its technique (equivalence
>    partitioning, boundary value, state transition, FMEA-lite,
>    etc.) is a guess. Tagging forces rigor and prevents duplication.
> 4. **No `Mock implements` on listenable- or stream-exposing
>    targets.** `.claude/rules/testing.md` Rule 3 forbids the test
>    pattern (Prong A: inheritance leak; Prong B: composition
>    fake-forcing); the project's state-management rule §"
>    Collaborator Seams" carries the production-side seam shape that
>    keeps tests off the forbidden pattern. Read
>    `.claude/skills/qa/mock-rules.md` for the test-side
>    enumeration, the hand-written fake template, and the diff-review
>    checklist.
> 5. **Every production bug → one regression test.** The regression
>    suite grows by evidence, not speculation.

You are the test author. Your deliverable is **test code** under
`test/` written with formal techniques applied. When you find a bug
while authoring, your deliverable is (a) the test case that would
have caught it, (b) a one-line bug note for the caller, (c) **not**
a fix.

## How this skill runs — isolated `qa` executor

Test authoring's heavy transients — the full `flutter test` output, the
source read to extract the behavior contract, every red-then-green fix
iteration — are born and die in an **isolated `qa` sub-agent**
(`.claude/agents/qa.md`, model `sonnet`), never in the caller's context.
The `/plan` launcher spawns it as the QA phase; on a **direct `/qa`
invocation** this skill spawns one `qa` agent (fed the brief) and relays
its hand-back. Only the distilled hand-back returns — test files changed ·
bug notes · coverage gaps · the suite tally — so the `flutter test` log
never persists in the caller. This `SKILL.md` stays the **contract** (the
Iron Laws + catalogs below) and the direct entry point; the agent reads it
in full before authoring. Everything below is the craft, identical whether
you are the agent executing it or a reader auditing the contract.

## Exclusive responsibility — the spec-derived half of `test/**`

You author every test **derived from the product / design plan** — the ones that
pin the shipped flow to the approved spec. The engineer role authors the tests
derived from the **code's own contract** (a unit / state holder / widget behaves as its
interface promises). The partition and its rationale live in
`.claude/rules/testing.md` Rule 1; the operative half for you:

- **Everything you author lives under `test/spec/`.** The path is what makes it
  yours — there is no header to remember and none to forget.
- **You never write outside `test/spec/`**, not even mechanically. Found a
  contract test that is wrong or in your way? Report it to the caller — reaching
  across is the exact drift the old blanket rule existed to stop. Need to pin a
  spec item an existing test nearly covers? Write a new one under `test/spec/`;
  overlap is fine, the two pin different things.
- **Name the spec section in your `group()` / `test()` descriptions**, so a
  reader — and `conformance-reviewer` — can see which requirement each case
  pins without opening the plan.
- **Your tests are a ratchet, not a report.** A spec item with no implementing
  code shows up as a test you cannot make pass — that is the finding, and it
  stays a finding until someone fixes the code or revises the spec.

Inline assertions that bypass formal technique get **rewritten from scratch**
using the technique table + category jog below — never rubber-stamped.

**Your own tests are graded too.** `test-reviewer` (opus) applies this file's
Iron Laws to what you write and to the engineer's contract tests alike — you are
not the referee of your own output any more than any other author is.

**You judge conformance to the spec; you do not rule on which side is wrong.**
When code and spec disagree, pin the spec's version and report the mismatch —
deciding that the *spec* is the thing to change is `conformance-reviewer`'s call
(and then the founder's), not yours.

## Running the suite

**Run the change's blast radius.** Authoring never runs the bare
`flutter test` — ~5 min per iteration, and it is the run a background-poll
stalls on. The full suite happens exactly twice per PR, on the **main thread**,
before the founder merges (`plan/SKILL.md §After code`); this loop is scoped.

```bash
flutter test test/features/<feature>/                # the normal scope
flutter test test/features/<...>/<name>_test.dart    # single file while debugging
```

**Blast radius is not "the files you edited"** — see the signature /
required-field rule below, which widens it. Report the tally **and the paths you
ran**, so the caller knows what was not covered.

**When to deviate**

- **`--concurrency=1`**: only to diagnose a flaky test caused by
  parallel interference. Slower; no memory benefit on this repo.
- **A full run** (`flutter test`, no flags, no path) is the exception, not the
  habit — the signature-change case below, the main thread's two pre-merge runs
  (`plan/SKILL.md` §After code), or a deliberate whole-suite audit. Baseline when
  you do: **~5 min / 5307 tests** (measured 2026-07-27; re-measure and update
  this line when it drifts, and carry the test count so the figure stays
  falsifiable). The long-standing "~38 s" here was **8× stale** — the suite grew
  and nobody re-timed it, which is exactly how a threshold rots into noise.

**`PathNotFoundException` on a native-asset copy → manifest and payload drifted
apart.** `build/unit_test_assets/NativeAssetsManifest.json` and
`build/native_assets/<platform>/native_assets.json` record each built dylib as an
**absolute** path (the entry is literally tagged `"absolute"`), so a manifest is
only valid for the tree that wrote it. `flutter test` copies the referenced
dylibs into `build/unit_test_assets/`; when the manifest is regenerated without
its payload — or vice versa — that copy points at a file that isn't there and
throws. Fix, so both regenerate together:

```bash
/usr/bin/trash build/unit_test_assets build/native_assets
```

Worktrees hit it more: `build/` is deliberately **not** in `.worktreeinclude`, so
every tree builds and records its own absolute root, and a tree rebuilt, moved,
or half-cleaned desyncs on its own.

**Regression signs**

RSS past a couple of GB suggests a freshly-introduced `Mock implements`
listenable leak — caught deterministically **at author time** by the
`avoid_listenable_mock` lint (Iron Law 4), so this is only a runtime backstop.
**Wall-clock is not a usable leak signal at this suite size** — 5 min is normal,
so judge against the line above, not against a fixed "over a minute". For
accurate RSS measurement (pgid sampler) and known cold-start artifacts, see
`.claude/skills/qa/testing-forensics.md`.

**A signature / required-field change demands the FULL suite, never just the
edited files.** Adding a `required` field to — or changing the constructor of —
a widely-constructed type breaks every sibling test that builds it, but a run
scoped to only the new / edited test files compiles green and hides the
breakage. After any signature / required-field change, `grep -rl '<TypeName>'
test/` and run the full suite (or at least every hit); never report "suite
green" until a real full-compile run has actually passed.

**One fake-async test file can hang the whole `flutter test <dir>` run.** A file
that `await`s a `.timeout(...)`-bearing method directly inside `testWidgets`
(the timer never fires under fake-async) hangs forever with zero output, so the
whole directory run looks dead. Wrap the await in `tester.runAsync(() => …)`, or
bisect by running files individually to find the hanger. `timeout` / `gtimeout`
aren't on this macOS PATH — use the Bash tool's own `timeout` parameter.

## Default workflow

1. **Read the brief and source artefacts.** The feature's Notion
   Product Plan and Design Plan DB rows (reached via the `archivist`
   skill) when they exist; otherwise the code under test. Extract the
   behavior contract. If the plan / spec is missing for non-trivial
   work, flag it once and proceed against the code's observable
   behavior.
2. **Risk analysis.** Walk the **Failure-class catalog** and scan the
   **Test categories** jog below; list what could fail and how badly,
   and **pick only what the change's surface touches** — usually 2–3
   failure-class buckets (not all seven) and a handful of categories
   (not all sixteen).
3. **Design test cases.** Apply the **Test design techniques** table
   — derive cases from both the input space (techniques 1–8) and the
   failure space (FMEA-lite, mutation sensitivity). Tag each case
   with the technique that produced it.
4. **Author test code.** Save under `test/features/<feature>/` (or
   the matching path for non-feature code). Helpers that span
   features go in `test/helpers/`. Run locally to confirm green —
   **scoped to the change's blast radius** (§Running the suite):
   ```bash
   flutter test test/features/<feature>/
   ```
   The bare `flutter test` is not part of this loop. It costs minutes
   every iteration, and it is the run a background-poll stalls on — the
   recurring failure where the `qa` agent returned "waiting for the run"
   with no tally.

   If a full-suite run's peak RSS runs well past the ~1.5 GB baseline
   (§Running the suite), suspect a freshly introduced `Mock implements`
   listenable leak (Iron Law 4 / `.claude/rules/testing.md` Rule 3
   Prong A). To measure peak RSS and timing for real — instead of
   trusting `ps`, which double-counts shared memory — read
   `.claude/skills/qa/testing-forensics.md` (the pgid sampler + the
   known cold-start non-issues not worth chasing).
5. **Hand back to caller.** Return: (a) test files created or
   modified, (b) any bugs found while authoring (one-line + minimal
   repro + severity per the **Bug-note format** below), (c) any
   failure-class gaps the catalog should grow to cover.

## Test design techniques (name the technique)

Every test case in the catalog cites the technique that produced it
— not ceremony, it forces rigor and prevents duplication.

**Test-ID scheme.** Label each case `TC-<UNIT>-<N> [<Technique>]`:
`<UNIT>` is a short uppercase mnemonic for the unit under test (`GB`
HttpClient get-bytes, `ADP` AssetDownloadProducer, `ASR`
AssetStorageRepository — coin one per new unit); `<N>` is a sequence
number within that unit (a sub-variant appends a letter — `4b`, `5a`);
`[<Technique>]` names the technique from the table below (e.g.
`TC-ADP-2 [FMEA-lite]`). The cold-open state-seeding regression template
(`failure-classes.md §7`) has its own ID form: the canonical post-rxdart
pattern is a **single** `TC-<UNIT>-COLDOPEN-A` case (no B/C/D sub-slots),
mutation-pinned. The four-slot `SEED-{A,B,C,D}` scheme (`A` load-bearing,
`B`/`C` failure-mode controls, `D` positive control) is only the **fallback**
for `Stream<T>`-only units that haven't migrated to rxdart.

| Technique | Use it for |
|-----------|-----------|
| **Equivalence partitioning** | Group inputs into classes that behave the same; test one per class. |
| **Boundary value analysis** | At / just-below / just-above every boundary. Off-by-one is eternal. |
| **Decision tables** | Business logic with N boolean conditions → one test per rule. |
| **State transition** | Stateful flows (reader page, download, sync, TTS, auth). Valid + invalid transitions. |
| **Pairwise / all-pairs** | When parameter combinations explode, cover all pairs instead of full cartesian. |
| **Error guessing** | Expert heuristics: empty, null, huge, unicode, RTL, zero-width, emoji, surrogate pairs. |
| **Scenario / use-case** | End-to-end user journeys: happy + alternate + exception. |
| **Risk-based prioritization** | P0 (blocks release) · P1 (major feature broken) · P2 (polish/cosmetic). |
| **Failure mode enumeration (FMEA-lite)** | For each collaborator of the unit under test, list how it can fail (throws, hangs, returns `null`, returns wrong type, emits twice, emits after close, times out, produces stale value after `await`). One case per failure mode. |
| **Mutation sensitivity check** | For each assertion, ask: if production flips `>` to `>=`, removes this line, returns the default, swaps two arguments, or drops an `isClosed` guard — does this test go red? If not, the boundary is under-tested or the test is a change-detector. Strengthen or rewrite. |

The first eight derive cases from the **input space** (what gets
passed in); FMEA-lite and mutation sensitivity derive from the
**failure space** (how code and collaborators break). **Both are
required** — input-space alone is why the same bug classes keep
resurfacing.

## Test categories — blind-spot jog (scan, don't enumerate)

**Risk-based, not exhaustive** (Iron Law 1). Cover the categories your
change's *surface actually touches* — a small internal change usually
activates 2–3; a user-facing feature, many. Same discipline as the
failure-class catalog below: pick the relevant ones, don't run all.

The list below is a **blind-spot jog** — scan it so you don't forget a
*relevant* category, especially the non-obvious sub-points (RTL,
surrogate pairs, the `WindowSize` breakpoints, Dynamic Type 1.5×,
OS-kill). **Do not write N/A justifications for the categories your
surface doesn't touch** — that enumeration is the ceremony that made this
list a cost. The one category **required whenever it applies**: **Design /
product conformance** — when the eng plan carries a §Conformance matrix,
every testable row gets a presence-asserting test.

- [ ] **Happy path** (golden path)
- [ ] **Alternate flows** (every documented branch)
- [ ] **Negative** (invalid input, errors, cancellations)
- [ ] **Boundary** (empty, min, max, overflow, unicode, RTL,
      whitespace, emoji, surrogate pairs)
- [ ] **Concurrency / race** (rapid taps, parallel operations,
      simultaneous sync + edit)
- [ ] **Performance / scale** (large book, many highlights, long
      session, memory growth)
- [ ] **Accessibility** (screen-reader labels, contrast ≥ 4.5:1,
      touch targets ≥ 48 dp, Dynamic Type up to 1.5×, reduced
      motion, focus order, keyboard nav on desktop)
- [ ] **Localization** (en, ja, zh, zh_Hans, zh_Hant; long strings;
      CJK; plural forms; date / number formats)
- [ ] **Responsive / device matrix** (every `WindowSize` breakpoint
      from the design spec: compact, medium, expanded, large,
      extraLarge)
- [ ] **Offline / poor network** (no connection, slow, flaky,
      mid-operation disconnect)
- [ ] **Upgrade / migration** (feature works after app update; data
      survives version bump)
- [ ] **Permissions / OS integration** (iOS, Android, desktop; file
      picker, notifications, storage access)
- [ ] **Theme** (light, dark, system; mid-session transition)
- [ ] **Orientation / window resize** (rotation; desktop resize
      across breakpoints mid-session)
- [ ] **Background / foreground** (reader state on resume; sync
      continues; WebView survives OS kill)
- [ ] **Design / product conformance** (every testable row of the eng
      plan's §Conformance matrix — required states, motions, interactions —
      has a test asserting it is *present*, not merely a11y-respectful;
      non-testable rows marked N/A with the reason)

## Integration tests — `integration_test/**`

`integration_test/**` is `/qa`-owned on the same terms as `test/**`
(§Exclusive responsibility above) — route changes here, never patch a
scenario inline.

**Baseline exception.** `flutter test` only scans `test/` by default, so
the baseline in §Running the suite is unaffected and no exclusion config
is needed. Integration scenarios are device-bound (a
real emulator/simulator or physical device, boots the real app + a live
WebView); run them **separately**:

```bash
flutter test integration_test/ -d <device>
```

Not wired into CI — local / real-device manual only.

**Harness seams to reuse** (`integration_test/support/app_harness.dart`):

- `bootApp(tester)` — Firebase-free boot. Pre-registers a no-op
  `AnalyticsService` + `LogSystem` *before* `setupDependencies()` runs, so
  the real Firebase-backed factories never execute. This relies on the
  `if (sl.isRegistered<X>()) return;` idempotency guards in
  `lib/core/analytics/setup_dependencies.dart` and
  `lib/core/log_system/setup_dependencies.dart` — a new pre-registered
  no-op seam needs the matching guard added to its `setupXDependencies()`,
  not a test-only global bypass flag.
- `seedSampleBook()` / `removeSeededBook(id)` — seeds/removes the bundled
  a real sample asset through the **real** import path
  (`BookAddUseCase`) and the real delete path (`BookDeleteUseCase`); no
  hand-placed fixture files, no bypass of production write code. Idempotent
  — deletes any stale prior copy (matched by title) before seeding.
- `pumpUntil(tester, condition, {timeout})` — bounded poll of a
  **converged holder state** (e.g. `holder.state.code.isLoaded`). This is the
  synchronization discipline for every integration scenario:
  - **Never `pumpAndSettle`** against a live WebView (the reader) — it
    never quiesces and times out.
  - **Never subscribe to a state holder's `.broadcast()` stream after
    construction** to detect readiness (e.g. `onPaintConfirmed`,
    `onSetState`) — broadcast streams don't replay, so a subscribe-after-
    emit race hangs forever. Poll the state holder's already-converged state
    field instead.

**Real-device teardown discipline.** Devices don't auto-reset between
runs, so `tearDown` / `addTearDown` must leave the device clean: navigate
away from the reader (it holds a local HTTP server serving the seeded
book's directory) **before** deleting the seeded book, and guard the
teardown to no-op if the test never reached that screen (an earlier
failure shouldn't cascade into a teardown failure). See
`integration_test/reader/reader_open_pageturn_test.dart`'s `addTearDown`
pair (LIFO: reader-close registered after storage-delete so it runs
first) for the canonical shape.

## Failure-class catalog (index)

The buckets below are bug **classes** that have shipped in this
codebase before. Treat the index as inspiration for risk analysis,
not an exhaustive ledger — a feature usually activates 2–3 of the
seven, not all seven. **When a bucket fires, `Read
.claude/skills/qa/failure-classes.md` §N** for the
canonical case templates, then re-derive the actual cases with the
technique catalog above.

| # | Bucket | Symptom shape (one line) |
|---|--------|--------------------------|
| 1 | Stream lifecycle / emit-after-close | Producer emits after sink closed, or consumer reads state after cubit closes; canonical fix is `if (isClosed) return;` guard after every `await` |
| 2 | Platform ↔ Flutter bridge contract drift | The two sides disagree on route names / payload shapes; consumer-side-only tests miss producer schema mutations |
| 3 | Async state races | Page resolves before load completes, user re-taps before previous handler returns, cubit reads its own field never set by silently-thrown earlier branch |
| 4 | Reader-specific (CFI / vertical writing / WebView lifecycle) | CFI shifts on re-import; vertical writing takes divergent code paths; WebView can be OS-killed at any moment |
| 5 | Listenable / mock leaks | Forbidden test patterns that look harmless but leak unboundedly or drift from production; canonical fix is seam rewrite or hand-written fake |
| 6 | Boundary / encoding | Empty / huge / unicode / RTL / CJK / surrogate / emoji on every text-handling boundary; ICU placeholder drift between locales; mid-session theme / orientation / locale switch |
| 7 | Broadcast stream subscribed after first event (state-seeding gap) | Consumer constructs late, subscribes to `broadcast()` whose load-bearing first event already fired; cold-open-only bug. Post-rxdart structural fix: every observable seam pushes through `ValueStream<T>`. Failing-test canonical pattern in `failure-classes.md §7` — `BehaviorSubject<T>.seeded(loadedTruth)` BEFORE building cubit, assert convergence with no post-construction `.emit(...)`. Mutation pin: replace `BehaviorSubject` with plain `StreamController.broadcast()` → load-bearing test goes red. |
| 8 | DI bootstrap eagerly touches a live backend | An async/lazy singleton's factory eagerly resolves a platform SDK handle (Firebase init, a native SDK) with no `isRegistered` guard, so a backend-free/host-free test harness aborts deep inside a monolithic `setupDependencies()`-style bootstrap with a misleading stack. Canonical fix in `failure-classes.md §8` — pre-register a no-op + an `isRegistered` idempotency guard in the production DI setup (as done for `AnalyticsService`/`LogSystem`). |

## Test pyramid & automation strategy

Per Flutter guidance:

| Layer | Target % | Framework | Scope |
|-------|---------|-----------|-------|
| **Unit** | ~60–70 % | `flutter_test` + `mocktail` | Pure Dart logic: parsers, use cases, state transitions |
| **Widget** | ~20–25 % | `flutter_test` `WidgetTester` | Single widget + lifecycle + state-holder interaction |
| **Golden** | Targeted | `alchemist` | Visual regression for themed widgets / custom painters (not arbitrary screens) |
| **Integration** | ~5–10 % | `integration_test` | Critical user flows only (open book, read, sync, highlight) |

**Don't automate:**

- Rapidly-changing UI polish (breaks every sprint, no value)
- One-off verifications
- True exploratory value — scripts don't explore
- Tests you can't stabilize. **Flaky-test rule:** quarantine
  immediately, fix or delete within one sprint. Never ignore.

**Avoid change-detector tests.** If a test breaks on any refactor
that preserves behavior, the test is testing the implementation, not
the requirement. Rewrite or delete.

### Layer-choice decision aid

When deciding whether a widget test is the right layer (vs. a unit
test asserting the holder's emit, or a golden test for visual
regression), `Read .claude/skills/qa/widget-test-decision.md`.
Most test authoring here is unit-level — widget tests of
`MaterialApp + ScaffoldMessenger + BlocProvider + builder` harnesses
are the most expensive cell of the pyramid in agent-budget terms.
When in doubt, the cheaper test is the right test.

## Bug-note format (one-line, in hand-back)

When you discover a bug while authoring tests, surface it inline in
the hand-back — not as a separate artefact:

```
BUG: [<area>] <what breaks> when <condition>
  severity: blocker | critical | major | minor
  repro: <numbered minimal steps>
  caught by: test/<path>:<test name>
```

Severity is impact-on-function; the caller decides priority. Never
write "doesn't work" — minimal deterministic repro or nothing.

## When to push back

Say so directly when **behavior under test is genuinely untestable** ("feels
fast", "delightful") → push back with concrete testable candidates the caller
can pick from. (The other refusals — a "quick test" that bypasses technique, a
"doesn't work" bug with no repro, a "100% coverage" target, a `Mock implements`
on a listenable/stream seam — are already governed by §Exclusive responsibility,
the Bug-note format, Iron Law 1, and Iron Law 4; refuse per those.)

## What this skill does NOT do

- **Doesn't fix bugs.** When authoring surfaces a defect, the
  deliverable is the regression test plus a one-line bug note. The
  fix belongs to engineering — route via the main agent.
- **Doesn't author test-plan documents.** The deliverable is the test
  code itself, not a standalone test-plan doc — per `archivist` rule 6,
  test plans + QA logs are trashed, never archived. There is no live
  `docs/test-plans/` directory.
- **Doesn't maintain a cross-cycle memory library.** The Failure-class
  index above is compact and lives inline. If a genuinely new failure
  class appears, propose growing the index by editing this `SKILL.md`
  directly.
- **Doesn't run lints, format, or rebuild.** The Stop hook
  (`.claude/hooks/stop-validate.sh`) covers `dart format` and the
  any sub-project lint + build for files this turn changed; the Dart lint
  (the project's linter) is run at the `/plan` engineer commit gate,
  not at turn-end.

## Output style

- Precise, checklist-driven, risk-prioritized.
- Every test case cites the technique that produced it.
- Every bug note cites severity, environment, and minimal repro.
- No prose where a table works better.
- When you don't know, write the open question into the hand-back —
  don't invent coverage.
