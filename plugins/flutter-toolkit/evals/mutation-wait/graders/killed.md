---
type: regex
pattern: '^killed: rc=3$'
flags: m
arm: with-only
---
marker 裡的 pid 已死而 marker 還在：回 3，tree 可能還留著 mutant。
