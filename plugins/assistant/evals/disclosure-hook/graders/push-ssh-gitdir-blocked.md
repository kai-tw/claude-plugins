---
type: regex
pattern: '^push-ssh-gitdir=2$'
flags: m
---
[S9] git --git-dir=<path> push leaves the ssh host unresolved (it changes which config git reads), so the push is scanned (exit 2).
