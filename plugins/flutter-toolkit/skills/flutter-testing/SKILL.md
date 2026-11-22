---
name: flutter-testing
description: >-
  `plan-coverage` for Flutter/Dart projects: runs the given test command and checks that
  every changed line was executed, with no `coverage:ignore` comments. Mutation testing is
  the engine's own command (`dart run dart_mutants`, `npx stryker run`).
  `<cmd> --help` for flags; `references/pr-checks.md` sets the checks up in CI.
  TRIGGER: run tests · coverage · mutation · Stryker · PR checks · CI runner
allowed-tools:
  - Bash
---

# Flutter testing

- `plan-coverage -- <scoped test command>` — per **line**, not per percent: each
  changed `lib/**.dart` line is executed. No `coverage:ignore` comments: a changed
  file carrying `// coverage:ignore-*` (or the retired `// coverage-ignore:`) is
  blocked too.
  Two exceptions are built in, and the report counts the lines each leaves out:
  drift table definitions (column getters of a class extending drift's `Table`),
  and const constructor declarations with no logic, whose line the VM records or
  not depending on what the run loads (one whose initializer list branches or
  asserts is still measured). Exceptions are added to the script only, never to
  project code.
  A file with no coverage record is NOT-LOADED (blocks) unless the import-only
  test shows it has no executable line — NO-CODE, which passes. Runs with
  branch coverage, so a `throw const …` body no test entered is a gap; a `throw`
  inside `??` / `?:` is unmeasurable and blocks until rewritten as a statement.
  `--diff <ref>` measures the lines changed since `<ref>` — a PR's base, in CI. It
  runs the test command only once a changed Dart file needs measuring; a change with
  none passes without running it.
- Mutation: Dart → `dart run dart_mutants` (flags in its `--help`; `--test-command` is
  required; needs `dart_mutants` in `dev_dependencies`), JS/TS → `npx stryker run`, each with its own reports.
  dart_mutants keeps its own machine-wide slots (`$DART_MUTANTS_SLOTS`,
  `$DART_MUTANTS_SLOT_DIR`). Start a long run
  with the Bash tool's `run_in_background: true` — never `&`, `nohup`, `disown` or
  `setsid`, which the harness cannot see — then end the turn: the session is woken
  when it exits. Never `Monitor`, `tail -f` or a blocking wait on it.

Coverage measures which lines a test executes; mutation measures whether the
tests assert what those lines do. Neither replaces the other.
