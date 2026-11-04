---
name: flutter-testing
description: >-
  Bare-name commands for Flutter/Dart test runs on a shared machine:
  `plan-test` (run a suite within a machine-wide concurrency limit), `plan-coverage`
  (every changed line executed, no `coverage:ignore` comments), `plan-mutation` (mutation
  score over the changed Dart and JS/TS files, or review mode over the changed
  lines) and `plan-mutation-review` (post review mode's survivors on a PR).
  `<cmd> --help` for flags; `references/pr-checks.md` sets them up in CI.
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
- `plan-mutation -- <scoped test command>` — needs `dart_mutants` in pubspec (the
  script prints the exact stanza when it is missing). With many changed files in
  different directories, pass `--by-dir` and a command without test paths: each
  directory's files are mutated against only their own test directory, one pass
  each, instead of every mutant running every directory's tests. A survivor replaced with
  its own text (two switch arms with one result) is equivalent: listed apart,
  not scored, not posted. While it runs the working
  tree holds live mutants; read files via `git show HEAD:<path>`. The engine's
  first line gives the mutant count and a time estimate, and each mutant line
  says how long is left; `--max-minutes n`
  stops one that will not fit, scoring nothing — that is an abort, not a score.
  Start a long run with the Bash tool's `run_in_background: true` — never `&`,
  `nohup`, `disown` or `setsid`, which the harness cannot see — then end the
  turn: the session is woken when it exits. Never `Monitor`, `tail -f` or a
  blocking wait on it.
  `plan-mutation --stop [<pid>]` stops a run (STOPPED, exit 1, nothing scored)
  and keeps the finished mutants: the same command again runs only the rest,
  while the code and tests are unchanged.
  `--diff <ref> --review <file>` is review mode: only the lines changed since
  `<ref>`, one Dart mutant a line (`--per-line n`; JS/TS runs every mutant on a
  changed line), survivors on covered lines written
  to `<file>` for `plan-mutation-review <pr> <file>`, exit 0 whatever the score
  — or, with `--fail-on-survivors`, exit 1 on any survivor, covered or not.
  Changed JS/TS package source (what its Stryker config's `mutate` list takes,
  else `<package>/src|lib/**`) goes to StrykerJS in
  that package — `@stryker-mutator/core` installed there, tests from its
  Stryker config, so no test command is needed when no Dart file changed.
  `--workers n` is its concurrency; the other engine flags are Dart-only.

Coverage measures which lines a test executes; mutation measures whether the
tests assert what those lines do. Neither replaces the other. Slot state:
`$HOME/.claude/.flutter-toolkit/slots` (`PLAN_TEST_DIR`).
