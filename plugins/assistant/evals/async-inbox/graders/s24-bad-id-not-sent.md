---
type: regex
pattern: '^s24-bad-id-not-sent=1$'
flags: m
arm: with-only
---
[S24] Answering a question whose id is outside [A-Za-z0-9_-]{1,64} writes nothing and wakes no session.
