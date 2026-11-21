---
type: regex
pattern: '^agents/builder\.md: .*\b(never|not|don.t)\b[^.]*(assume|rely)[^.]*hook[^.]*(check|run)|^agents/builder\.md: .*(run|runs)[^.]*check[^.]*(yourself|own)[^.]*before[^.]*commit'
flags: m
---
[A5] The builder runs the project checks itself before committing and never assumes the commit hook will.
