---
type: regex
pattern: '^(default|pr|named): title NG Assistant'
flags: m
match: not_contains
arm: with-only
---
A profile without `title_prefix` gets no prefix.
