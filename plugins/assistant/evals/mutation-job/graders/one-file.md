---
type: regex
pattern: '^plan-mutation --workers 2 --files lib/a\.dart -- flutter test @ '
flags: m
arm: with-only
---
--files lands right before the test command, so it names only the file.
