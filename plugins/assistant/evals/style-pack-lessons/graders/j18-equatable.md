---
type: regex
pattern: '^dart\.md: - \*\*S[0-9]+\.[0-9]+-dart .*(==|hashCode|equality)[^.]*violat.*\bEquatable\b|^dart\.md: - \*\*S[0-9]+\.[0-9]+-dart .*(==|hashCode|equality)[^.]*\bEquatable\b[^.]*violat|^dart\.md: - \*\*S[0-9]+\.[0-9]+-dart .*\bEquatable\b[^.]*violat'
flags: mi
arm: with-only
---
[J18] dart.md: object equality written by hand instead of with Equatable violates the rule.
