---
type: regex
pattern: '^index\.md: - \*\*S16\.[0-9]+ .*(only static[^.]*namespace|namespace[^.]*only static)[^.]*violat'
flags: mi
arm: with-only
---
[J2] S16: a type with only static members used as a namespace violates the rule.
