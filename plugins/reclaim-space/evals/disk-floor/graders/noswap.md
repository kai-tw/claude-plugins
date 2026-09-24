---
type: regex
pattern: '^noswap_bytes=0$'
flags: m
match: contains
arm: with-only
---
沒有 swap volume（Linux、雲端 VM）時門檻不成立，放行。
