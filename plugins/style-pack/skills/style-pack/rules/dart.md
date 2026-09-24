# Style rules — Dart / Flutter statute layer

Loaded when: the diff contains `.dart`. Each rule must hang under an existing charter
`S<N>`; if it cannot, amend the charter first (`CONVENTIONS.md`).

## S2 — A name must still reveal its owner, kind and category once it leaves its declaration

- **S2.1-dart A type name is ordered `<owner><concept><kind>`, and the owner is decided by
  purpose** — Check: does the type (private ones too) begin with its owner? A type a feature
  owns uses that feature's name; one shared across features uses the single reserved word the
  regulation layer sets; one that exists because of a single platform API uses the platform
  name (`Ios` / `Android`), by its purpose, not its compile scope. Where the concept noun
  already contains the feature name, do not repeat the prefix. A misplaced or missing owner
  violates this rule. The kind-word vocabulary is set by the regulation layer.
- **S2.2-dart A widget whose name ends in a Material / Cupertino component name must be that
  component** — Check: does something named `…Card`, `…Chip`, `…BottomSheet` or the like
  inherit, compose or directly render that component? One that looks alike without using it
  violates charter S2.6; use another word from the regulation layer's table instead. So does
  a namespace class with a static `build(context, …)` posing as a widget.

## S3 — Every collapse must be justified at each consumption point

- **S3.1-dart A clearable nullable field's `copyWith` parameter must be `T? Function()?`** —
  Check: does the nullable field's `copyWith` need to express "clear to null"? If it does and
  the parameter is declared `T?`, it violates this rule: "not given" and "set to null" both
  arrive as `null`, and `x ?? this.x` always resolves that ambiguity as keep. Only monotonic
  fields that go from null to a value and never back keep `T?` (there is no clear to express;
  wrapping is mere noise). Use a pure Dart function type, not Flutter's `ValueGetter` — the
  domain layer must not import Flutter, and clearable nullable fields appear most often in
  that layer.

## S4 — A persisted value's meaning must not depend on position or manual upkeep

- **S4.1-dart Persist an `enum` with `toString()`** — Check: what form does the `enum` write
  out? `.index` violates charter S4.1 (sequence position). `.name` violates this rule: this
  language's persisted form is `toString()` (`Foo.bar`), whose type prefix makes the stored
  value carry its own namespace, and with both forms in use, one store holds two encodings
  that a reader cannot tell apart without reading both ends. Per charter S4.2 the cost is
  stated at the enum's declaration: renaming a member or the type is a data migration, and
  **`toString()` must not be overridden** — overriding it rewrites the storage format, and
  silently. The reader still needs a `wildcard` branch to fall back on unknown values.

## S5 — Silently aborting a flow must state the trigger and the flow skipped

- **S5.1-dart Fire-and-forget must be explicit with `unawaited()`** — Check: is the call
  whose result is not awaited wrapped in `unawaited()`? A bare call violates this rule — in
  source a bare call looks exactly like a forgotten `await`, and `unawaited()` makes the
  decision a written word. Its reason is stated separately per charter S5.2.

## S6 — Comments answer WHY and attach to the nearest declaration

- **S6.1-dart A tag takes the form `// <tag>: <one line>`** — Check: is the tag a line
  comment, is the tag lowercase alphanumeric directly followed by a colon, and does the one
  line after it give both the reason and where it will be resolved? A tag inside dartdoc
  (`///`) violates this rule: dartdoc is the type's public contract, a tag is temporary
  state, and the two have different lifetimes. The whitelist and its scanner are listed by
  the regulation layer (S6.7).

## S7 — Failure handling must match the kind of failure

- **S7.1-dart Change type at the boundary with `Error.throwWithStackTrace`** — Check: when
  translating an exception inside `catch (e, s)`, is it thrown with
  `Error.throwWithStackTrace(mapped, s)`? Throwing it with `throw mapped(e)` violates this
  rule: `throw` resets the stack to the translation line, so crash reporting points at the
  boundary, not the frame that actually failed.

## S9 — Resources must be bounded, and the bound stated when written

- **S9.1-dart A `compute()` payload must be smaller than the work it saves** — Check: how
  large is the payload sent to the isolate? `compute()` deep-copies its payload, so shipping a
  large object graph to save a cheap computation violates this rule — the copy cost is the
  new bound, and it does not appear in the code that was moved.

## S10 — A set recorded at compile time must not be bypassed by runtime lookup

- **S10.1-dart What renders through a portal does not inherit its lexical context** — Check:
  does the widget rendered through a portal (`showDialog`, `showModalBottomSheet`,
  `Draggable.feedback`, `OverlayEntry`, any `Overlay.of(context).insert`) read an
  `InheritedWidget` its host does not provide? If so, it violates this rule: it hangs off the
  app-root `Overlay`, so every layer between the caller and the host — `BlocProvider`,
  `Theme`, `Material`, `MediaQuery`, `Directionality` — is absent. The failure **shows only at
  runtime**, with no compile error and no lint. Two ways out, in order: the widget does not
  read its own `context` at all, with data and callbacks passed in by the caller; or
  explicitly re-bridge, one by one, each layer its subtree actually reads.
  The default answer is "yes" — any non-trivial widget reads at least `Theme` and `Material`.

## S11 — A piece of state has exactly one write path

- **S11.1-dart How a stream is consumed must match its lifetime** — Check: is the stream
  one-shot (ends once sent) or long-lived (never ends)? One-shot consumed with `.listen()`
  violates this rule: on the next call the previous subscription is still alive, so the same
  state has two write paths, and the `cancel` boilerplate never runs. Long-lived consumed with
  `await for` also violates this rule: the loop never returns, so its caller (often a
  constructor) never completes either.
- **S11.2-dart A notifying controller is itself a state holder** — Check: does the state
  holder have a framework-provided notifying controller (`TextEditingController`,
  `ScrollController`, `PageController`, `FocusNode`) among its fields? If so, it violates
  charter S11.3 — two lifecycles and two state machines get bound together, and neither can be
  tested alone. The controller belongs with the screen unit that owns it, created and disposed
  with it; the state holder keeps only its value.

## S16 — An object owns one capability, and its interface is the only boundary

- **S16.1-dart Where a visual structure matches a framework component's slots, use that
  component** — Check: does this code hand-assemble with `Row` / `Column` / `Stack` a
  structure a framework component already provides (leading icon + title + subtitle, icon +
  label + tap, a rounded tappable raised surface)? If so, it violates charter S16.2 — the
  hand-made version inevitably misses the component's built-in spacing, alignment,
  accessibility, `dense` mode, theme integration or tap feedback, and no tool flags these
  gaps. Project design tokens are no reason to hand-build: the component's override hooks
  exist precisely for them. Hand-assembly may be used only when no framework component fits
  the shape.
