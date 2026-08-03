# Engineering Abstraction Level

`Read` this file when translating an upstream brief (Phase 1) or
running the Phase 8 audit self-check.

The engineering plan sits below the product plan and the design
spec. The other two stay at semantic / outcome / layout level; the
engineering plan is where concrete code-level identifiers land.
Crossing the line in either direction breaks the trail: too
high-level and the implementer reinvents the design at typing
pressure; too low-level and the plan rots the moment a class is
renamed.

---

## What you CAN reference (engineering vocabulary)

- **File paths** — `lib/features/<feature>/domain/use_cases/...`,
  `lib/core/connectivity_system/data/repositories/...`. Cite line
  numbers when pointing the implementer at existing code
  (`book_list_notifier.dart:82`); omit line numbers in *forward-
  looking* sketches (new code's line numbers don't exist yet).
- **Class / interface / use-case names** — `BookRepository`,
  `BookAddUseCase`, `BookAddUseCaseParam`, `CloudSyncServiceImpl`,
  `ExploreLatestShelfNotifier`. Full feature-prefixed names per
  `.claude/rules/naming.md §Naming`.
- **Exception class names** — `BookSyncException`,
  `BookSyncOfflineException`, `TranslationUnsupportedPairException`.
  All extending `AppException` (lint-enforced
  `domain_exception_extends_app_exception`).
- **State field names** — `state.tabIndex`,
  `state.isOffline`, `state.code.isLoading`. These are
  engineering-owned; the design spec speaks of "the loading state",
  the engineering plan names the field that holds it.
- **DI registrations** — `sl.registerLazySingleton<X>(...)`,
  `setup_dependencies.dart` updates, the `sl<T>()` call sites
  per `restrict_sl_scope`.
- **Native / platform-channel surfaces** — `MethodChannel`,
  `EventChannel`, platform-API identifiers (`NLLanguageRecognizer`,
  `MlKitTranslator`, `UITextInteraction`, `Connectivity()`). The
  design spec abstracts these as "system reports X"; the
  engineering plan names the API.
- **Platform bridge contracts** — channel names, message JSON
  shape, error signal envelope when a bridge is touched.
- **Lint rule identifiers** — `avoid_layer_violation`,
  `avoid_emit_after_await`, `prefer_named_subscription_callbacks`,
  etc. Naming the rule that will fire is more durable than "the
  linter will complain."
- **Package / library names** — `package:rxdart` scope discipline
  (BehaviorSubject / ValueStream / Subject allowed in `domain/`,
  operator surface forbidden), `package:googleapis`,
  `package:flutter_slidable`, etc.
- **Test seam shapes** — two-callback injection, narrow interface,
  hand-written fake template. Per the project's state-management rule §
  Collaborator Seams`.
- **Stream-type details** — `Stream<T>` vs `ValueStream<T>`,
  `BehaviorSubject<T>`, `StreamSubscription<T>`, `cancelOnError`,
  `onDone`. Plus the named-method-reference rule for
  `Stream.listen` callbacks inside state holders.
- **Build / format / lint commands** — `the project's lint command
  lib`, `flutter gen-l10n`, any sub-project build. When a
  phase has a verification step, name the command.

## What you do NOT reference

- **Product-problem rephrasing** — "the user wants to read offline,
  so we should ...". The product plan owns the problem statement;
  the engineering plan owns the implementation. Cite the plan path
  + section, don't redraft.
- **Layout / token / breakpoint decisions** — "compact view shows
  a `Card` with `surfaceContainer` background, 16dp padding". The
  design spec owns layouts; the engineering plan implements them.
  If the engineering plan needs to talk about UI, cite the spec
  section.
- **Visual-state vocabulary disconnected from a state field** —
  "the disabled state" without naming which state field
  drives it, or "the loading variant" without naming the
  `LoadingStateCode` value. Engineering must name the field; the
  spec named the variant.
- **Aesthetic adjectives** — "make it cleaner", "better DX",
  "more idiomatic". Either it composes / passes lint / measures
  better, or it doesn't. Name the rule, the lint identifier, or
  the measurement.
- **Roadmap / sequencing of unrelated work** — engineering plans
  cover one feature's implementation. Cross-feature roadmaps
  belong in product plans.

## Edge cases

- **State field names in design spec** — when the design
  spec accidentally names a `state.<field>`, that's a leak in
  the spec. Engineering can still cite it (the spec was the
  source); flag the leak as a designer-role follow-up but don't
  block on it.
- **`State` suffix** — engineering plans freely use `State`
  for state classes (`BookshelfState`, `ReaderState`).
  The design spec's "four states (default / empty / loading /
  error)" uses *State* in a different sense — that's design
  vocabulary. Both meanings coexist; context disambiguates.
- **Material 3 widget types** — M3 widget names (`Card`,
  `FilledButton`, `BottomSheet`) are design vocabulary, but the
  engineering plan freely uses them when sketching widget code.
  No leak — the design spec chose the M3 widget, the engineering
  plan instantiates it.

## Self-check before saving the plan

Walk the draft once and check that each section sits at the right
abstraction:

- **`## Summary`** — semantic prose, 1–2 sentences: what's being
  built + why, with links to the upstream product / design rows.
  Does **not** redraft the product problem.
- **`## Composition`** — a Mermaid graph of the blocks + their
  wiring (block→block injection / call). Nodes are feature-prefixed
  class names. The shape, not the detail.
- **`## Decisions`** — load-bearing engineering rulings as bullets,
  in semantic / outcome terms ("split state because the existing
  emit path races"), never "line 142 looked like this".
- **`## Risks`** — engineering risks (libraries, platforms, races,
  perf, supply chain), each with a concrete mitigation (zero
  residual). Not product risks.
- **`## Migration impact`** — concrete schema / API / lint impacts
  vs the last release tag.
- **`## Blocks`** — the block table: per block, class name +
  method-signature list (no bodies) + file (NEW/MOD/DEL) + layer +
  SOP. Full feature-prefixed names per `naming.md §Naming`.
- **`## Data flow`** — sequence per scenario, code-flow level;
  reference blocks by name. Cite line numbers for *existing* code,
  named identifiers for new.
- **`## Error handling`** — a one-line policy + the 7-column matrix
  + race sub-table, every row evidence-cited.
- **`## Tasks`** — phase letters + tasks, atomic-PR / atomic-commit
  mode, pre-gate audit tasks for risky phases.

A plan that reads at the wrong abstraction in any section is
either ghostwriting an upstream artifact (route the content back
to the PM role / the designer role) or hand-waving an engineering decision
(rewrite the section concretely).

The plan should still be **useful** if half the cited class names
were renamed tomorrow. The identifiers are entry points for the
implementer; the *load-bearing decisions* are in the prose
("split state because the existing emit path has a race with
account switch"), and decisions survive renames.
