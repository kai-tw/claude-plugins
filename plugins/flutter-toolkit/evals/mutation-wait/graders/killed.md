---
type: regex
pattern: '^killed: rc=3$'
flags: m
arm: with-only
---
The marker's pid is dead but the marker remains: returns 3, since the tree may still hold a mutant.
