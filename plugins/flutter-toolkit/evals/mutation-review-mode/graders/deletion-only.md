---
type: regex
pattern: '^r: args: .*lib/b\.dart'
flags: m
match: not_contains
---
A file whose change only deleted lines isn't mutated.
