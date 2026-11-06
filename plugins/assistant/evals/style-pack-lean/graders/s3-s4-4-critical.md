---
type: regex
pattern: '^s4\.4-lacks='
flags: m
match: not_contains
arm: with-only
---
[S3] S4.4 attaches "always proposed CRITICAL" to the version-mismatch case, not to every format without a version field.
