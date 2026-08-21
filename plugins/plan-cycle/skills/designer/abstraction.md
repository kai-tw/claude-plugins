# Design Abstraction Level

`Read` this file when translating a brief (Phase 1) or running the
Phase 6 self-check.

---

## What you CAN reference (design vocabulary)

- **Material 3 widget types** — `Card`, `FilledButton`, `IconButton`,
  `AppBar`, `BottomNavigationBar`, `NavigationRail`, `BottomSheet`,
  `Dialog`, `Slidable`, `TabBar`, `ListTile`, `InkWell`, etc. These
  name shapes in the design language.
- **Shared widgets from the design system** — anything under
  `lib/app/widgets/` or `lib/features/shared_components/`
  (`CommonDeleteDialog`, `CommonLoadingWidget`, `CommonProgressDialog`,
  `DownloadProgressButton`, `LocaleListTile`, etc.). Naming one is the
  design call "reuse this exact widget".
- **Design tokens** — color-scheme roles (`primary`, `surfaceContainer`,
  `onSurfaceVariant`), text-theme roles (`titleMedium`, `bodyLarge`),
  spacing-scale values (`4.0`, `8.0`, `12.0`, `16.0`, `24.0`), radius
  values (`4.0`, `8.0`, `16.0`, `24.0`, `36.0`), `WindowSize` enum
  classes.
- **Material icons by name** — `Icons.close_rounded`, `Icons.copy_rounded`.
- **ARB localization keys** — the keys name user-visible strings the
  design depends on.

## What you do NOT reference

- **Feature-internal Dart class names** — `TranslationNotifier`,
  `TranslationState`, `_TranslationCard`, `_Half`,
  `TranslationPickerButton`, `BookshelfPageState`. These belong to
  engineering's class hierarchy, not the design system.
- **State field names** — `state.detectedSource`,
  `state.sourceLocaleOverride`, `state.code`. Describe the semantic
  condition instead: "when the system has a confident detection result";
  "when the user has overridden the source language".
- **File paths and line numbers** — `lib/features/.../...`,
  `notifier.dart:348`. Even when citing prior specs, use the spec's section
  number (`§4.8.3`), never line numbers.
- **Layer-wiring vocabulary** — "data source", "repository", "use case",
  "platform channel", "JNI bridge". Engineering's vocabulary belongs in
  the engineering plan, not the design spec.
- **Exception class names** — `TranslationUnsupportedPairException`.
  Describe the user-facing outcome: "when the language pair isn't
  supported on the device".
- **Native API identifiers** — `NLLanguageRecognizer`, `MlKitTranslator`,
  `UITextInteraction`. The implementer picks whichever API produces the
  user experience you specified.

## Self-check before saving the spec

Search your draft for: `Cubit`, `Bloc`, `Notifier`, `Provider`, `Repository`, `DataSource`, `UseCase`,
`Exception`, `.dart`, line-number colons, native framework names,
`state.<fieldName>`. Each hit is engineering vocabulary leaking. Rewrite
at the design abstraction or move to the **Hand-off to engineering**
section.

A class suffix `State` referring to the four-state UI concept (default /
empty / loading / error) is **fine** — that's design vocabulary. A class
suffix `State` naming a state-holder's state class is the leak.

The spec should still be **correct and useful** if every non-shared class
in the codebase were renamed tomorrow.

## When you depend on a system fact

State the semantic condition in plain language. If engineering needs an
unambiguous hand-off, end the spec with a short **Hand-off to
engineering** section: a one-line product contract per fact ("the design
depends on a per-sheet detection result the implementer captures however
fits the architecture"). The hand-off is the boundary; the engineering
plan does the class sketch on the other side.
