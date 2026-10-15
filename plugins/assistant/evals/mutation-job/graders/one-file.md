---
type: regex
pattern: '^plan-mutation --workers 2 --keep-dir WS/state/wt/SHA/lib_a\.dart --files lib/a\.dart -- flutter test @ SHA '
flags: m
arm: with-only
---
--keep-dir and --files land right before the test command, and the run is at the merge commit.
