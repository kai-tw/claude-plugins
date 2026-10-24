---
type: regex
pattern: '^review: \[\{"path":"lib/a\.dart","line":2,"body":"Mutant survived: [^]]*\}\]$'
flags: m
arm: with-only
---
The review file is still written first, with only the survivor a test reaches.
