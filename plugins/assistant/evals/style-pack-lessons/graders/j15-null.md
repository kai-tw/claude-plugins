---
type: regex
pattern: '^js\.md: - \*\*S[0-9]+\.[0-9]+-js .*\bundefined\b`?[^.]*(instead of|rather than|in place of) `?null\b[^.]*violat|^js\.md: - \*\*S[0-9]+\.[0-9]+-js .*(declar|assign|initiali|set)[a-z]*[^.]*\bundefined\b`?[^.]*violat[^.]*\bnull\b'
flags: mi
arm: with-only
---
[J15] js.md: a value declared empty with undefined instead of null violates the rule.
