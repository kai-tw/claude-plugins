---
type: regex
pattern: '^js\.md: - \*\*S[0-9]+\.[0-9]+-js .*(union of string literals|string[- ]literal (type )?unions?)[^.]*(violat.*\benum\b|\benum\b[^.]*violat)'
flags: mi
arm: with-only
---
[J13] js.md: a union of string literals in place of an enum violates the rule.
