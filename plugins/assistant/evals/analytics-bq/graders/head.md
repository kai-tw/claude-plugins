---
type: regex
pattern: '^\{"op":"events","project":"novelglide","dataset":"analytics_123","days":90,"count":2\}$'
flags: m
arm: with-only
---
events finds the one analytics_<property> dataset and says what it read.
