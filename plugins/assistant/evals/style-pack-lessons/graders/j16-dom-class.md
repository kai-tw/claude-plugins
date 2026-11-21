---
type: regex
pattern: '^js\.md: - \*\*S[0-9]+\.[0-9]+-js .*(read|deriv|infer|check|query|recover)[a-z]*[^.]*state[^.]*\b(DOM|element|CSS)\b[^.]*\bclass.*violat'
flags: mi
arm: with-only
---
[J16] js.md: reading state back from a DOM class violates the rule.
