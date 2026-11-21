---
type: regex
pattern: '[Ee]stimates?,? (may|can|is fine to|are fine to|is allowed to|are allowed to|is ok to) (be )?((worded|written|shown|stated|phrased|presented) )?as (an? )?(promise|guarantee|commitment)|[Ee]stimates? (may|can) (promise|guarantee)'
match: not_contains
flags: m
---
[F4] An estimate is never allowed to read as a promise.
