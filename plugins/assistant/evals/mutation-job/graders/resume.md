---
type: regex
pattern: '^plan-mutation .*--files lib/a\.dart -- flutter test @ TIP1 in WS/src/wt from 2 journal line\(s\)$'
flags: m
arm: with-only
---
A swept file resumes at its pinned commit, with the journal it saved, though main has moved on.
