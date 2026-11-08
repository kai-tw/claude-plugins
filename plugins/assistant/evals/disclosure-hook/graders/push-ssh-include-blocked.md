---
type: regex
pattern: '^push-ssh-include=2$'
flags: m
---
[S9] git -c include.path=<file> can change the ssh command, so the push to an ssh alias is scanned (exit 2).
