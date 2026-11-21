---
type: regex
pattern: '^agents/verifier\.md: .*whole[^.]*file[^.]*not (just|only)[^.]*hunks?[^.]*:[^.]*(passes|hands|forwards)[^.]* on[^.]*parallel lists?[^.]*(null|flag)'
flags: m
---
[B5] verifier.md: blocks 1 and 2 judge the shape of each whole file the diff touches, not only its hunks — a unit that only passes things on, parallel lists, state encoded in a null or a flag.
