---
type: regex
pattern: '^noswap_bytes=0$'
flags: m
match: contains
arm: with-only
---
With no swap volume (Linux, cloud VMs) the minimum does not apply, so it passes.
