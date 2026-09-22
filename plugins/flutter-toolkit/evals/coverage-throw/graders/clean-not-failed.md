---
type: regex
pattern: '^FAIL .*lib/c\.dart$'
flags: m
match: not_contains
arm: with-only
---
全部執行過的檔案不判 FAIL。
