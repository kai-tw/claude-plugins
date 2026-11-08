---
type: regex
pattern: '^push-ssh-cfgenv=2$'
flags: m
---
[S9] git --config-env=core.sshCommand=<x> push leaves the ssh host unresolved, so the push is scanned (exit 2).
