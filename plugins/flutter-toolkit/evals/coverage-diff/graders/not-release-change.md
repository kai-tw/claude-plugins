---
type: regex
pattern: '^release: .*lib/b\.dart'
flags: m
match: not_contains
---
With --diff release, the release branch's own change is out of scope.
