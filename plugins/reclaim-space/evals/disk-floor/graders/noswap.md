---
type: regex
pattern: '^noswap_bytes=0$'
flags: m
match: contains
arm: with-only
---
With no swap volume (Linux, cloud VMs) the floor does not apply, so it passes.
