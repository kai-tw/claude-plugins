---
type: regex
pattern: '^old: args: .*--journal'
flags: m
match: not_contains
---
dart_mutants 0.4.0 has no --journal, so it is not passed one.
