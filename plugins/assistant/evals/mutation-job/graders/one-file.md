---
type: regex
pattern: '^plan-mutation --workers 2 --keep-dir [^ ]+ --files lib/a\.dart -- flutter test '
flags: m
arm: with-only
---
--keep-dir and --files land right before the test command, so the run names only the claimed file.
