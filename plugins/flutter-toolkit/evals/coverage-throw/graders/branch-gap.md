---
type: regex
pattern: 'lib/a\.dart:3 .*block never entered'
flags: m
arm: with-only
---
An if block with BRDA 0 (containing a throw const) is listed as a gap.
