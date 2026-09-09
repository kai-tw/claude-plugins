# The `.design.dart` marker — who owns a presentation widget

The designer ships real presentation widgets, and `tool/design_mockups`-style
harnesses mount *those exact classes* to render the reviewed states. That makes
one file two things at once: the design artefact and the shipped UI.

Nothing in a widget's class name says which. An engineer wiring the screen sees
`OnboardingKeyBackupStep(...)` at a call site and has no signal that editing it
forks what ships from what was reviewed — silently, because no render re-runs at
implementation time.

**The convention: a designer-shipped widget lives in a file named
`*.design.dart`.**

```
onboarding_key_backup_step.design.dart   ← designer's; contract below
onboarding_view.dart                      ← engineer's; owns the Scaffold
```

## Why the filename, not the class name or a directory

Every Dart project already reads a dotted filename suffix as "this file is not
yours to hand-edit" — `.g.dart`, `.freezed.dart`. `.design.dart` inherits that
reading for free. It shows up in the import line and in the file tree, and it
costs no class rename, so call sites, tests and mockup specs stay untouched.

⚠️ **The semantics differ, and the difference is the dangerous direction.** A
`.g.dart` edit is destroyed by the next build, which teaches the lesson
immediately. A `.design.dart` edit **survives**. So the marker does not mean
read-only; it means **changing it is a design-stage action**, not something to
slip into an implementation commit.

A directory (`presentation/design/`) also works and is what a path-partitioned
project may already use for test ownership. It is weaker here for one reason:
the marker's job is to be visible at the moment of temptation, and the file the
engineer has open is the import line, not the directory listing.

## The one cost it does carry — check before adopting

Any lint that derives an expected class name **from the filename** misfires on the
suffix. `kai-packages`' `public_class_names_its_file` strips only a trailing
`.dart`, so it compares the class against `foo.design` and reports every marked
file.

⚠️ Exempting them (`exemptFiles: [.design.dart]`) silences it but turns the
**whole rule** off for those files — the second-public-class check short-circuits
with the filename half — so nothing then catches an unrelated class added to one.
That is a stopgap; the fix is teaching the rule to strip a marker segment. Grep
for filename-derived rules before adopting the suffix, and if you take the
exemption, record that it is temporary.

## The contract a `.design.dart` file is under

Exactly what `design_lint.sh` checks — no more, so the marker never promises
something unenforced:

- `StatelessWidget`. `StatefulWidget` only for `vsync`.
- No import of repository / service / cubit / bloc / provider / DI container.
- No inline state read (`context.read`/`watch`, `BlocBuilder`, `Consumer<`,
  `StreamBuilder`, `FutureBuilder`, Riverpod's `ref.watch`/`read`/`listen` or a
  `Consumer*Widget` base).
- Receives lifecycle controllers as parameters; never constructs one.
- No hardcoded colour.
- A class doc comment carrying **§States** (each state and what enters it),
  **§Seam** (each parameter / callback and the behaviour expected of it) and
  **§Reuse** (查過 `<既有元件>` → `<為何不重用>`); **§Interaction** and **§A11y**
  are advisory, since a static widget may have no intent to record.

State arrives as constructor parameters; actions leave as callbacks.

## Why the contract is in the file and not in a plan

These are the three things the source cannot say. In the file they sit where the
engineer wiring the widget already reads, a diff shows them changing next to the
change, and `design_lint.sh` can enforce them — which is what lets them be a
contract rather than a description.

## Two findings a reviewer must NOT file against these files

- **"Too many parameters."** The parameters *are* the state matrix the mockups
  enumerate. Collapsing `readiness` / `outcome` / `hasViewed` into one object, or
  trimming them, deletes render states nobody then looks at. The thing to review
  is the **caller**: does the logic that gathers those parameters have a visible
  home, or is it buried in a widget-returning private method?
- **"No provider access, so it can't show real data."** That is the enabling
  constraint, not an omission. The render harness mounts these widgets with no DI
  container at all; a widget that reached for one would throw on mount and could
  never be photographed.

## Why the marker makes the lint stronger

`design-lint <dir>` has to be pointed at the right paths by whoever remembers to
run it, and a `presentation/` directory holds engineer-owned widgets too. With
the suffix, the lint discovers its own inputs — run it with no arguments and it
sweeps every `*.design.dart` under the tree. That turns a design-phase gate into
one any later phase (implementation, review, CI) can re-run without carrying a
list of filenames forward.
