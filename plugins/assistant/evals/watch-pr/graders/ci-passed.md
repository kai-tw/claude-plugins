---
type: regex
pattern: '^cipass=ci passed acme/lib#7 exit=0$'
flags: m
arm: with-only
---
CI finishing green on the watched PR is reported; a requested suite and another branch's completed suite before it are not.
