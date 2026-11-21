---
type: regex
pattern: '^dart\.md: - \*\*S[0-9]+\.[0-9]+-dart .*(\.then\b[^.]*violat.*\bawait\b|\bawait\b.*\.then\b[^.]*violat)'
flags: mi
arm: with-only
---
[J19] dart.md: a .then chain in place of async/await violates the rule.
