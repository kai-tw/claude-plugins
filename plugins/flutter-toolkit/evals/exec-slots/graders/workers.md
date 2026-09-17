---
type: regex
pattern: '^workers=2$'
flags: m
arm: with-only
---
launcher 把 --workers 3 換成 3 個 slot，超過預算就拒絕。
