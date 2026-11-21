---
type: regex
pattern: '^index\.md: - \*\*S16\.[0-9]+ .*\b(bool|boolean|flag)\b`?[^.]*parameter[^.]*(switch|select|choos|toggl)[^.]*violat[^.]*(two|separate) entry points'
flags: mi
arm: with-only
---
[J3] S16: a bool parameter that switches between two behaviors violates the rule; split it into two entry points.
