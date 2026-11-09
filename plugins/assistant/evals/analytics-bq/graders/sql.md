---
type: regex
pattern: '^query .*SELECT COUNT\(\*\) AS n FROM `demo-project\.analytics_123\.events_\*`$'
flags: m
arm: with-only
---
sql fills {events} in with the export tables.
