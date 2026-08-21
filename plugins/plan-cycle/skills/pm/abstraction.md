# Product Abstraction Level

`Read` this file when translating a brief or drafting a plan.

---

Plans speak in **problems, users, outcomes, scope, and trade-offs**.
Never in exception class names, file paths, method signatures, layer
wiring, native API names, line numbers, state field names, or
repository / use-case / data-source class names.

A plan that leaks implementation vocabulary pre-commits engineering
decisions before the problem is validated, rots the moment a class is
renamed, and loses readers who aren't engineers. The plan should still
be correct if every class in the codebase were renamed tomorrow.

## Translating incoming briefs

When a brief drops implementation noise, translate it down before writing:

| Brief says | You hear |
|---|---|
| `TranslationUnsupportedPairException` doesn't carry the locale | When the pair can't be translated, the user can't see what was detected |
| The state holder nulls `state.result` at `translation_state.dart:348` | When the source matches target, we drop the detected language before the user sees it |
| Add a `detectLanguage` method to `TranslationPlatformDataSource` | Detect the language as its own step, not as a side-effect of translating |
| Apple `NLLanguageRecognizer` / ML Kit `google_mlkit_language_id` | Both platforms offer standalone language detection |
| Plumb through the domain exception | The detection result needs to survive across all error states |

Plan from the right column. The left column belongs in the design spec.

## What product context is allowed

- **Platform capability boundaries** ("iOS 18+ only", "ML Kit cold-loads on Android") — affects scope and degradation. **Yes.**
- **Latency / resource costs at user-perception level** ("~50 ms", "~30 MB first use") — affects success metric and risk. **Yes.**
- **Cross-cutting commitments** (i18n, accessibility, offline, privacy) — **yes.**
- **Class / method / file names, line numbers, native API identifiers, library names** — **no.**
