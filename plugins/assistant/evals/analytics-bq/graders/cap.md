---
type: regex
pattern: '^query .*--maximum_bytes_billed=1000000000 '
flags: m
arm: with-only
---
Every query is capped at 1 GB billed.
