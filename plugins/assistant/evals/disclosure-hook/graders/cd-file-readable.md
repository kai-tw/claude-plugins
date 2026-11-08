---
type: regex
pattern: 'body.txt is unreadable'
match: not_contains
flags: m
---
[S10] A body file that exists under the cd directory is never called unreadable.
