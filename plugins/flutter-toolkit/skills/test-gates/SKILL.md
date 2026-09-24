---
name: test-gates
description: >-
  Three bare-name commands for Flutter/Dart test runs on a shared machine:
  `plan-test` (run a suite inside a machine-wide slot budget), `plan-coverage`
  (every changed line executed, no exemptions) and `plan-mutation`
  (mutation score over the changed Dart and JS/TS files). `<cmd> --help` for flags.
  TRIGGER: run tests · coverage · mutation · Stryker · who is holding a test slot
allowed-tools:
  - Bash
---

# Test gates

- `plan-test test/features/<x>/` — scoped run; `--full` for the whole suite;
  `--status` lists slot holders; `--exec <cmd…>` holds one slot around a command.
  Never the bare `flutter test` / `dart test`: several sessions share this
  machine's memory, and the plugin's `test-gate` hook denies them.
- `plan-coverage -- <scoped test command>` — per **line**, not per percent: each
  changed `lib/**.dart` line is executed. No exemptions: a changed file carrying
  `// coverage:ignore-*` (or the retired `// coverage-ignore:`) is blocked too.
  A file with no coverage record is UNREACHED (blocks) unless an import-only
  probe shows it has no executable line — NO-CODE, which passes. Runs with
  branch coverage, so a `throw const …` body no test entered is a gap; a throw
  arm of `??` / `?:` is unmeasurable and blocks until rewritten as a statement.
- `plan-mutation -- <scoped test command>` — needs `dart_mutants` in pubspec (the
  script prints the exact stanza when it is missing). While it runs the working
  tree holds live mutants; read files via `git show HEAD:<path>`. The plan line
  estimates the run and each mutant line says how long is left; `--max-minutes n`
  stops one that will not fit, scoring nothing — that is an abort, not a score.
  A long run goes in the background with output to a file; wait on it with
  `plan-mutation --wait <pid>` (Bash timeout 600000, repeat while it exits 1),
  never `Monitor` or `tail -f` — each copy lives until the run ends.
  Changed JS/TS package source (`<package>/src|lib/**`) goes to StrykerJS in
  that package — `@stryker-mutator/core` installed there, tests from its
  Stryker config, so no test command is needed when no Dart file changed.
  `--workers n` is its concurrency; the other engine flags are Dart-only.

Coverage grades the reach, mutation grades what was reached; neither replaces
the other. Slot state: `$HOME/.claude/.flutter-toolkit/slots` (`PLAN_TEST_DIR`).
