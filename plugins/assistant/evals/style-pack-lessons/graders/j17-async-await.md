---
type: regex
pattern: '^js\.md: - \*\*S[0-9]+\.[0-9]+-js .*(\.then\b[^.]*violat.*\bawait\b|\bawait\b.*\.then\b[^.]*violat)'
flags: mi
arm: with-only
---
[J17] js.md: a .then chain in place of async/await violates the rule.
