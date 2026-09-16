---
name: test-gates
description: >-
  Three bare-name commands for Flutter/Dart test runs on a shared machine:
  `plan-test` (run a suite inside a machine-wide slot budget), `plan-coverage`
  (every changed line executed, or its exception named) and `plan-mutation`
  (mutation score over the changed files). `<cmd> --help` for flags.
  TRIGGER: run tests · coverage · mutation · who is holding a test slot
allowed-tools:
  - Bash
---

# Test gates

- `plan-test test/features/<x>/` — scoped run; `--full` for the whole suite;
  `--status` lists slot holders; `--exec <cmd…>` holds one slot around a command.
  Never the bare `flutter test`: several sessions share this machine's memory.
- `plan-coverage -- <scoped test command>` — per **line**, not per percent: each
  changed `lib/**.dart` line is executed or carries `// coverage-ignore: <reason>`.
- `plan-mutation -- <scoped test command>` — needs `dart_mutants` in pubspec (the
  script prints the exact stanza when it is missing). While it runs the working
  tree holds live mutants; read files via `git show HEAD:<path>`.

Coverage grades the reach, mutation grades what was reached; neither replaces
the other. Slot state: `$HOME/.claude/.plan-cycle/slots` (`PLAN_TEST_DIR`).
