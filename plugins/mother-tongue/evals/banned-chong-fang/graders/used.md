---
type: regex
pattern: '^used=\[.*重播攻擊→重放攻擊.*防重播→防重放'
flags: m
arm: with-only
---
A reply that writes a replay attack as 重播攻擊 and its guard as 防重播 is blocked, and 重放 is offered for both.
