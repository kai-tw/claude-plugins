---
type: regex
pattern: 'missing or stale: verify-code\(none\) verify-coverage\(none\) verify-text\(none\)'
flags: m
arm: with-only
---
沒有報告時列出所有必要的驗證項目：coverage 有設、diff 碰到 ui_strings，所以 text 也要。
