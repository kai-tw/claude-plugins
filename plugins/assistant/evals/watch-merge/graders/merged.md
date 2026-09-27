---
type: regex
pattern: '^merge=merged acme/lib#7 exit=0$'
flags: m
arm: with-only
---
A merge of the watched PR is reported and ends the watch; the merge of #8 and the push to #7 before it are ignored.
