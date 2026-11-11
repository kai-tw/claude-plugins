# Style rules — Dart / Flutter language rules

## S2

- **S2.1-dart A type name is ordered `<owner><concept><kind>`, and the owner is decided by
  purpose** — Check: a type (private ones too) that does not begin with its owner violates
  this rule. A type a feature owns uses that feature's name; one shared across features uses
  the single reserved word the project rules set; one that exists because of a single
  platform API uses the platform name (`Ios` / `Android`), by its purpose, not its compile
  scope. Where the concept noun already contains the feature name, do not repeat the prefix.
  The project rules set the list of type suffixes.
- **S2.2-dart A widget whose name ends in a Material / Cupertino component name must be that
  component** — Check: something named `…Card`, `…Chip`, `…BottomSheet` or the like that does
  not inherit, compose or directly render that component violates core rule S2.6; use another
  word from the project rules' table instead. So does a namespace class with a static
  `build(context, …)` posing as a widget.

## S3

- **S3.1-dart A clearable nullable field's `copyWith` parameter must be `T? Function()?`** —
  Check: a nullable field whose `copyWith` needs to express "clear to null" and declares the
  parameter as `T?` violates this rule: "not given" and "set to null" both arrive as `null`,
  and `x ?? this.x` always resolves that ambiguity as keep. Only monotonic fields that go from
  null to a value and never back keep `T?`. Use a pure Dart function type, not Flutter's
  `ValueGetter`; the domain layer must not import Flutter.

## S4

- **S4.1-dart Persist an `enum` with a hand-written code** — Check: an `enum` written out with
  `.index` violates core rule S4.1 (sequence position); with `.name` or `toString()` it
  violates core rule S4.2 (the member's identifier). The S4.2 mapping must be one `switch`
  expression over the members with no `_` or `default` branch, so a missing member is a
  compile error; a `Map` literal violates this rule, since a missing key reads back `null`
  only at runtime. Decode walks `values` through that `switch` and falls back on an unknown
  code.
  Adopting codes: a store that already holds `.name` or `toString()` strings takes codes
  equal to today's stored strings, so nothing migrates; a store that held `.index` needs a
  frozen index→member table (S4.5) and a migration (S4.4).

## S5

- **S5.1-dart Fire-and-forget must be explicit with `unawaited()`** — Check: a call whose
  result is not awaited and is not wrapped in `unawaited()` violates this rule. Its reason is
  stated separately per core rule S5.2.

## S6

- **S6.1-dart A tag takes the form `// <tag>: <one line>`** — Check: the tag must be a line
  comment, lowercase alphanumeric and directly followed by a colon, and the one line after it
  must give both the reason and where it will be resolved. A tag inside dartdoc (`///`)
  violates this rule: dartdoc is the type's public contract, a tag is temporary state.

## S7

- **S7.1-dart Change type at the boundary with `Error.throwWithStackTrace`** — Check: when
  translating an exception inside `catch (e, s)`, throwing it with `throw mapped(e)` instead
  of `Error.throwWithStackTrace(mapped, s)` violates this rule: `throw` resets the stack to
  the translation line.

## S9

- **S9.1-dart A `compute()` payload must be smaller than the work it saves** — Check: a
  `compute()` payload that is a large object graph shipped to save a cheap computation
  violates this rule: `compute()` deep-copies its payload, and the copy cost is the new bound,
  which does not appear in the code that was moved.

## S10

- **S10.1-dart What renders in an overlay or a new route does not inherit the caller's
  inherited widgets** — Check: a widget rendered in an overlay or a new route
  (`showDialog`, `showModalBottomSheet`, `Draggable.feedback`, `OverlayEntry`, any
  `Overlay.of(context).insert`) that reads an `InheritedWidget` its host does not provide
  violates this rule: it is mounted under the app-root `Overlay`, so every inherited widget
  between the caller and the host — `BlocProvider`, `Theme`, `Material`, `MediaQuery`,
  `Directionality` — is absent. Two ways out, in order: the widget does not read its own
  `context` at all, with data and callbacks passed in by the caller; or provide again, one by
  one, each inherited widget its subtree actually reads. Any non-trivial widget reads at least
  `Theme` and `Material`.

## S11

- **S11.1-dart How a stream is consumed must match its lifetime** — Check: a one-shot stream
  (ends once sent) consumed with `.listen()` violates this rule: on the next call the previous
  subscription is still alive, so the same state has two write paths, and the `cancel`
  boilerplate never runs. A long-lived stream (never ends) consumed with `await for` also
  violates this rule: the loop never returns, so its caller (often a constructor) never
  completes either.

## S16

- **S16.1-dart Where a visual structure matches a framework component's slots, use that
  component** — Check: code that hand-assembles with `Row` / `Column` / `Stack` a structure a
  framework component already provides (leading icon + title + subtitle, icon + label + tap, a
  rounded tappable raised surface) violates core rule S16.2: the hand-made version misses the
  component's built-in spacing, accessibility or tap feedback. Project design tokens are no
  reason to hand-build: the component's override hooks exist precisely for them. Hand-assembly
  may be used only when no framework component fits the shape.
