---
type: regex
pattern: '^bad-[a-z]+=[^2]'
flags: m
match: not_contains
arm: with-only
---
每一條 polling 指令都以 exit 2 擋下。
