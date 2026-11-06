---
name: flutter-testing
description: >-
  Bare-name commands for Flutter/Dart test runs on a shared machine:
  `plan-test` (run a suite within a machine-wide concurrency limit) and `plan-coverage`
  (every changed line executed, no `coverage:ignore` comments). Mutation testing is
  the engine's own command (`dart run dart_mutants`, `npx stryker run`).
  `<cmd> --help` for flags; `references/pr-checks.md` sets the checks up in CI.
  TRIGGER: run tests · coverage · mutation · Stryker · who is holding a test slot · PR checks · CI runner
allowed-tools:
  - Bash
---

# Flutter testing

- `plan-test test/features/<x>/` — scoped run; `--full` for the whole suite;
  `--status` lists slot holders; `--exec <cmd…>` holds one slot around a command.
  Never the bare `flutter test` / `dart test`: several sessions share this
  machine's memory, and the plugin's `require-plan-test` hook denies them. A run on an
  Android device (`-d <serial>`) that is locked or asleep is refused before it
  starts, since it would hang behind the lock screen: ask for it to be unlocked.
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
  takes a test slot only once a changed Dart file needs measuring; a change with
  none passes without waiting for one.
- Mutation: Dart → `dart run dart_mutants` (flags in its `--help`; `--test-command` is
  required; needs `dart_mutants` in `dev_dependencies`), JS/TS → `npx stryker run`, each with its own reports.
  dart_mutants keeps its own machine-wide slots (`$DART_MUTANTS_SLOTS`,
  `$DART_MUTANTS_SLOT_DIR`), separate from plan-test's. Start a long run
  with the Bash tool's `run_in_background: true` — never `&`, `nohup`, `disown` or
  `setsid`, which the harness cannot see — then end the turn: the session is woken
  when it exits. Never `Monitor`, `tail -f` or a blocking wait on it.

Coverage measures which lines a test executes; mutation measures whether the
tests assert what those lines do. Neither replaces the other. Slot state:
`$HOME/.claude/.flutter-toolkit/slots` (`PLAN_TEST_DIR`).
