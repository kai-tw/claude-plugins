---
type: regex
pattern: 'lib/a\.dart:3 .*block never entered'
flags: m
arm: with-only
---
BRDA 為 0 的 if 區塊（裡面是 throw const）列為缺口。
