---
type: regex
pattern: '^push-ssh-cfgenv-sp=2$'
flags: m
---
[S9] git --config-env <name>=<var> (space form) push leaves the ssh host unresolved, so the push is scanned (exit 2).
