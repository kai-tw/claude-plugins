---
type: regex
pattern: '^js\.md: - \*\*S[0-9]+\.[0-9]+-js .*(inline|anonymous) object (literal )?types?[^.]*(violat.*\bclass\b|\bclass\b[^.]*violat)'
flags: mi
arm: with-only
---
[J14] js.md: an inline object type in place of a named class violates the rule.
