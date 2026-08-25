# Failure-class example cases

`Read` this file when one or more buckets in the SKILL.md
**Failure-class catalog** are activated by the feature under test
(usually 2–3 buckets, never the whole index). Each entry below provides
canonical case templates — apply the technique catalog to derive
the cases that fit *this* feature, don't copy the examples
verbatim.

---

## 1. Stream lifecycle / emit-after-close

(a) A state-holder handler `await`s a slow IO call, the route pops, `emit()`
then fires after `close()` and throws — test drives the close
mid-`await` and asserts a clean teardown.

(b) A single-subscription `Stream` is subscribed twice — test
asserts the second subscriber gets the contract it expected (error
or replay), not silent miss.

## 2. JS ↔ Flutter bridge contract drift

(a) A native or embedded layer adds a new field to a payload and the Dart side
discards it silently — forward-compat test loads an unknown-key
fixture and asserts the consumer doesn't crash.

(b) Route name renamed on one side — fixture-driven schema test
fails on either side mutating without updating the other.

## 3. Async state races

(a) A page renders with the holder in `Initial` state because the
navigator pushed before `loadBook()` completed — test drives the
navigation race and asserts the page either gates on a loading
state or never accesses the not-yet-loaded field.

(b) Rapid double-tap on a "sync now" button — test fires two taps
in the same frame and asserts the second is debounced or queued,
not double-firing the network call.

## 4. Reader-specific (CFI, vertical writing, WebView lifecycle)

(a) Book is re-imported (different inode, same content); the saved
CFI of an annotation must still resolve to the same chunk — test
drives the re-import and asserts the resolved range matches.

(b) Reader open in `vertical-rl`, rotate to landscape, page-turn
semantics flipped — test asserts the page-turn direction follows
the writing mode, not the device orientation.

(c) WebView killed by OS while the reader is backgrounded — test
drives a foreground resume and asserts state restores from the
persisted reading position, not a blank page.

## 5. Listenable / mock leaks

(a) `class MockGoRouter extends Mock implements GoRouter` is used
because `GoRouter` extends `ChangeNotifier` — **reject** at review
(Prong A); rewrite the seam to take callbacks (`canPop` / `pop`) so
the test passes plain lambdas.

(b) `Mock implements` of a class with a public `Stream` getter —
**reject** (Prong B); use the hand-written-fake pattern in
`.claude/rules/testing.md` (real `StreamController`, `dispose` in
`tearDown`).

## 6. Boundary / encoding

(a) A parser receives a 50 MB input file on a low-memory device — test
asserts no main-isolate hang and no unbounded RSS growth.

(b) ICU placeholder count drifts between `en` and `ja` ARBs — test
asserts every `.arb` carries every placeholder declared in `en`
(and the reverse, where applicable).

(c) User switches locale mid-session — test asserts the screen
re-renders with the new locale's strings, no stale string captured
at first build.

## 7. Broadcast stream subscribed after first event (state-seeding gap)

### Symptom shape

- The holder's state stuck at constructor defaults forever after
  cold-open; UI renders the "no event yet" branch (signed-out,
  empty, loading spinner) even when the underlying truth is the
  opposite.
- Bug is cold-open-only. Warm-open and route re-mount work,
  because the producer's first event happens to land during the
  same lifecycle that constructed the consumer. The asymmetry
  is the diagnostic fingerprint.
- Existing per-holder tests "pass" because they push the event
  post-construction (`fakeObserver.add(true)` after
  `buildHolder()`) — that simulates the *opposite* of the
  real-device timing, and the bug ships unseen.

### Mechanism

`StreamController.broadcast()` does not retain or replay
events. A subscription created **after** the producer's first
emit gets nothing until the next emit. In production the
producer (OAuth state, plugin event channel, manual broadcast
bus) often fires its load-bearing initial value during app
startup — before the consumer state holder (typically a lazy
singleton or factory created on widget mount) is constructed.
The consumer's stream-derived state never converges and stays
at the state holder's `const XxxState()` defaults.

This is **not** emit-after-close (§1: producer's lifecycle),
**not** bridge contract drift (§2: schema), **not** an async
race between two writes (§3: ordering). It's a state-**seeding**
gap — the consumer never sees the value at all, because the
event happened in the past.

### Production-side rule (post-2026-05-10 — STRUCTURAL FIX)

**Every observable seam that an external producer pushes through
to consumer state holders / services must be `ValueStream<T>`-shaped
(rxdart `BehaviorSubject` underneath).** The data-source layer
holds the `BehaviorSubject<T>.seeded(initial)`, feeds it from
the underlying broadcast event source, and exposes the subject
as a `ValueStream<T>` getter. The repository / use case
pass-throughs preserve the `ValueStream<T>` typing all the way
to the consumer's `.listen(...)` call. Late subscribers receive
the cached current value as their first event; the state holder's
existing observer handler (`_onAuthSignInChanged`,
`_onPreferenceChanged`, etc.) covers both the cold-open seed
AND subsequent transitions through one emit path.

Concretely, for the auth seam: `GoogleAuthApi` holds
`BehaviorSubject<bool>.seeded(false)` fed from
`GoogleSignIn.instance.authenticationEvents`; `AuthApi`,
`AuthRepository`, and `AuthObserveSignInUseCase` all surface
`ValueStream<bool>`. `CloudSyncSettingsCubit` subscribes via
`authObserveSignInUseCase(_provider).listen(_onAuthSignInChanged)`
— no `_seedAuthState()` method, no paired
`AuthIsSignInUseCase`, no `unawaited(instance._seedAuthState())`
factory line. The first event the state holder's handler sees is the
`BehaviorSubject`'s seeded value (or the latest cached value if
the subject has been fed events since `.seeded(...)`).

This SUPERSEDES the previous `Stream<T>` + paired
`XxxIsYyyUseCase` + eager-seed dance pattern. That pattern
worked but accreted a new method per consumer state holder, a new
"current value" use case per stream, and a `_seedXxxState()`
implementation that future maintainers had to remember to add
when wiring a new broadcast subscription. The structural fix
moves the responsibility to the ONE place that owns the
external event source — the data-source layer — and every
consumer benefits without new code.

### Required test pattern (canonical, post-rxdart)

The load-bearing case for any state holder subscribing to a
`ValueStream<T>`:

(a) **Setup.** A hand-rolled fake (e.g. `FakeAuthSignInValueStream`
in `test/helpers/auth_mocks.dart`) wrapping a real
`BehaviorSubject<T>.seeded(initial)`. The seed reflects the
truth the state holder must converge to. Stub the observe-use-case
mock to return the fake's `.stream` getter via `thenAnswer((_)
=> fake.stream)` — mocktail rejects `thenReturn` for
Stream-typed values because `BehaviorSubject` IS a `Stream`.
**No `Mock implements ValueStream<T>` or `Mock implements
Stream<T>`** — Rule 3 Prong B forbids both.

(b) **Construction.** Build the state holder. Its
`.listen(...)` call subscribes to the value-stream; the
`BehaviorSubject` immediately delivers the seeded value as
the first event.

(c) **Assert.** State converges to the expected loaded shape
**without any post-construction `.emit()` call** — the load-
bearing contract is "the value-stream's cached value is the
holder's first observed event, and its existing handler
processes it correctly".

(d) **Mutation pin (load-bearing).** Replacing the production
seam's `BehaviorSubject<T>.seeded(initial)` with a plain
`StreamController<T>.broadcast()` (no replay) flips this case
red — the consumer subscribes after the producer's first event
has already fired and never sees the cached truth.

Sketch (auth seam, the canonical instance):

The worked example below uses Bloc's `blocTest` because that is the codebase the
incident happened in. **The failure class is not Bloc-specific** — any state
holder that subscribes to a broadcast stream after the first event has already
fired hits it. Translate the harness to whatever the project uses; what
transfers is the assertion shape: seed the stream *before* construction, emit
nothing during the test, and verify the holder converged anyway.

```dart
// fakeAuthValueStream.emit(...) is NEVER called in this test.
// The fake wraps a real BehaviorSubject<bool>.seeded(true);
// the state holder's subscription receives `true` as its first event
// via the BehaviorSubject's late-subscriber-replay semantics.

blocTest<CloudSyncSettingsCubit, CloudSyncSettingsState>(
  'TC-CS5-COLDOPEN-A (load-bearing MUT, structural §7 regression): '
  'value-stream seeded `true` BEFORE the cubit is built; the '
  'cubit\'s subscription delivers `true` as its first event '
  'WITHOUT any post-construction .emit() call. Mutation pin: '
  'replacing production\'s BehaviorSubject<bool>.seeded(false) '
  'with StreamController<bool>.broadcast() flips this red.',
  setUp: () {
    fakeAuthValueStream = FakeAuthSignInValueStream(seed: true);
    when(
      () => mockAuthObserveSignIn(any()),
    ).thenAnswer((_) => fakeAuthValueStream.stream);
    when(
      () => mockAuthGetUser(any()),
    ).thenAnswer((_) async => testAuthUser);
  },
  build: buildCubit,
  // No act — the value-stream's cached `true` is replayed to the
  // cubit's subscription as its first event without any intervention.
  wait: const Duration(milliseconds: 50),
  verify: (CloudSyncSettingsCubit cubit) {
    expect(cubit.state.isSignedIn, isTrue);
    expect(cubit.state.effectiveSignedIn, isTrue);
    expect(cubit.state.user, testAuthUser);
  },
);
```

### When this hypothesis fires (cite §7 in test plan)

- The holder's constructor wires `xxxObserveYyyUseCase().listen(...)`
  for any seam whose producer fires its load-bearing initial
  event during app startup (before the holder is constructed).
- Existing tests for the holder only verify post-construction
  `add(...)` / `.emit(...)` flows and lack a "cached value
  delivered to a late subscriber" case.

### Renaming checklist (post-rxdart)

The artifacts the §7 contract names per consumer have collapsed.
Old shape (paired use case + eager seed) is no longer required;
the new shape names only the value-stream itself:

- **value-stream use case** — e.g. `AuthObserveSignInUseCase`
  returning `ValueStream<bool>`.

That is the entire surface. Audit checklist when reviewing a
new consumer:

1. Producer (data-source layer) holds `BehaviorSubject<T>.seeded(...)`.
2. Domain repository + use case both type the seam as `ValueStream<T>`.
3. Consumer subscribes via `.listen(handler)`; handler covers
   both the seed-driven first event AND subsequent transitions.
4. Test fake wraps a real `BehaviorSubject<T>.seeded(...)`,
   exposes `.stream` for `thenAnswer((_) => fake.stream)`.
5. Test catalog has at least one `TC-XX-COLDOPEN-A` case
   asserting convergence with NO post-construction `.emit()`.

### Fallback pattern (for codebases that haven't migrated to rxdart yet)

The previous SEED-{A,B,C,D} canonical template — paired
`XxxIsYyyUseCase` + eager seed — is retained below for
reference. It applies when the seam is constrained to remain
`Stream<T>`-shaped (e.g. a third-party plugin's broadcast
stream that the data-source layer can't yet wrap). The
PRIMARY template for new consumers in this codebase is the
value-stream pattern above.

```dart
// FALLBACK ONLY — use when the seam is Stream<T>, not ValueStream<T>.
//
// Helpers (still ship in test/helpers/):
// - silent_broadcast_fake.dart — SilentBroadcastFake<EventType, ArgType>
// - log_system_mock.dart — setUpLogSystemMock / tearDownLogSystemMock

class FakeXxxObserveUseCase implements XxxObserveUseCase {
  final SilentBroadcastFake<EventType, ArgType> _fake =
      SilentBroadcastFake<EventType, ArgType>();

  @override
  Stream<EventType> call(ArgType parameter) {
    _fake.recordCall(parameter);
    return _fake.stream;
  }

  void emit(EventType event) => _fake.emit(event);
  Future<void> dispose() => _fake.dispose();
}

// Four cases:
//   SEED-A (load-bearing): seed reads loaded truth, observer silent
//   SEED-B (FME): seed throws → debug log, no emit
//   SEED-C (FME): close mid-await → no emit-after-close
//   SEED-D (positive control): observer.emit(...) drives transition
//
// Mutation pin: remove `unawaited(instance._seedXxxState())` from the
// factory body and SEED-A goes red.
```

### Repository incidents

Two 2026-05-10 incidents drove this class — `CloudSpaceTileCubit` (fix: dropped
the auth subscription; the per-tile holder is mount-gated by `effectiveSignedIn`
at the page level) and `CloudSyncSettingsCubit` (fix: the auth seam was rewritten
to `ValueStream<bool>` per the structural rule above, retiring the eager-seed
dance). The full dual-fix history lives in git + the decision log, not here — the
test-relevant takeaway is the COLDOPEN-A pattern + mutation pin above.

## 8. DI bootstrap eagerly touches a live backend

### Symptom shape

- A test harness that deliberately runs without a live backend (no
  Firebase project, no native SDK handle) aborts deep inside a
  monolithic `setupDependencies()`-style bootstrap, with a stack
  pointing at an unrelated call site — not at the DI registration that
  actually threw.
- The failure is bootstrap-order-dependent: it fires on the **first**
  touch of the lazy/async singleton, which may be several unrelated
  features downstream of where the harness expected the failure.

### Mechanism

An async or lazy singleton's factory eagerly resolves a platform SDK
handle (e.g. `FirebaseAnalytics.instance`, `FirebaseCrashlytics.instance`)
at construction time, with no guard against an already-satisfied seam.
A backend-free/host-free harness (integration test, host-side unit test
running outside a configured platform channel) has no way to short-circuit
that construction — the monolithic bootstrap function registers every
feature's dependencies unconditionally, so the first lazy resolution of
the SDK-backed singleton throws synchronously (e.g. `Firebase.app()`
throwing `no-app` before `Firebase.initializeApp()`), and every caller
downstream (a log call, an analytics call fired `unawaited` from deep in
a widget) throws into the zone at an unrelated call site.

### Canonical fix

Pre-register a no-op implementation of the singleton's interface in the
harness **before** the production bootstrap runs, and add an
`if (sl.isRegistered<X>()) return;` idempotency guard to the start of
that singleton's `setupXDependencies()` in production DI code (mirroring
the pre-existing `SharedPreferences` guard pattern) so the real,
backend-touching factory cleanly skips re-registration. Reject a
test-only global bypass flag (e.g. a `skipDoubleRegistration` switch) —
it silently swallows an *unintended* double-registration for any type
across the whole bootstrap, which narrows the harness's own ability to
catch a real DI mistake. The guard belongs in production code (zero
runtime behavior change — `isRegistered` is always `false` in prod), not
gated behind a test flag.

Concretely (`integration_test/support/app_harness.dart`'s `bootApp`):
`sl.registerLazySingleton<AnalyticsService>(_NoopAnalyticsService.new)`
and `sl.registerLazySingleton<LogSystem>(() =>
LogSystem(_NoopLogRepository()))` run before `setupDependencies()`; the
matching guards live in `lib/core/analytics/setup_dependencies.dart`'s
`setupAnalyticsDependencies()` and
`lib/core/log_system/setup_dependencies.dart`'s
`setupLogDependencies()`.

### Required test pattern

(a) **Setup.** Pre-register a hand-written no-op implementing the full
interface (never `Mock implements` — Rule 3 still applies even though
these particular interfaces don't expose a `Stream`/`Listenable`) for
every SDK-backed singleton the harness must keep off the live backend.

(b) **Assert (regression pin).** Removing the `isRegistered` guard from
the production `setupXDependencies()` flips a backend-free harness run
red at the first touch of that singleton — this is the mutation pin: the
guard is load-bearing, not incidental.

### When this hypothesis fires

- Any new `integration_test/**` scenario, or other backend-free harness,
  that boots the real app / real DI graph rather than injecting fakes
  per-holder.
- A monolithic `setupDependencies()`-style bootstrap where a feature's
  `setupXDependencies()` eagerly constructs (not lazily defers past first
  use) a platform SDK handle.
