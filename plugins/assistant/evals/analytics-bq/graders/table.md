---
type: regex
pattern: '^query .*FROM `novelglide\.analytics_123\.events_\*` WHERE _TABLE_SUFFIX BETWEEN .*INTERVAL 90 DAY'
flags: m
arm: with-only
---
events reads the export tables over the asked window.
