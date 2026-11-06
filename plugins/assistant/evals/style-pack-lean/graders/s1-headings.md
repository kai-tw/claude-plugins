---
type: regex
pattern: '^heading='
flags: m
match: not_contains
arm: with-only
---
[S1] Every `##` heading in dart.md, csharp.md and js.md is the rule number alone (`## S11`).
