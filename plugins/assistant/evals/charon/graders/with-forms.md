---
type: regex
pattern: '^with-(sudo|xargs|exec)=[^2]'
flags: m
match: not_contains
arm: with-only
---
[S4] The sudo, xargs and find -exec forms are blocked too.
