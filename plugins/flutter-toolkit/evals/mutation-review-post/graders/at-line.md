---
type: regex
pattern: '"comments":\[\{"path":"lib/a\.dart","line":5,"side":"RIGHT","body":"Mutant survived: y"\}\]\}$'
flags: m
arm: with-only
---
Each survivor is a comment at its line; the one already on the PR isn't posted again.
