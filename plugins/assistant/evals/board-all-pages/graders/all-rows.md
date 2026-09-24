---
type: regex
pattern: '^\{"count":5,"names":\["Task 1","Task 2","Task 3","Task 4","Task 5"\]\}$'
flags: m
arm: with-only
---
query gets all five rows across the three pages, not stopping at the first.
