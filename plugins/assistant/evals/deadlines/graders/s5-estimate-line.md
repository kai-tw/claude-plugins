---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*slice(.s)? row.s body (holds|carries|keeps) (its )?estimated hours as an? .?Estimate: <n>h.? line outside Current state[^.]*; carry (that|the|this) line into every rewrite'
flags: mi
---
[S5] the estimate is an `Estimate: <n>h` line outside Current state, carried into every rewrite of the body.
