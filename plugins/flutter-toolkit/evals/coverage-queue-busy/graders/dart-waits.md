---
type: regex
pattern: '^code: took=([5-9]|[1-5][0-9])s$'
flags: m
arm: with-only
---
A change with a Dart file waits at least TEST_QUEUE_WAIT seconds for a slot, and not without bound.
