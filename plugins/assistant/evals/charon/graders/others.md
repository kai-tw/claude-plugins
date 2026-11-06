---
type: regex
pattern: '^with-(git-rm|rmdir|quoted)=[^0]'
flags: m
match: not_contains
arm: with-only
---
git rm, rmdir and a quoted mention pass.
