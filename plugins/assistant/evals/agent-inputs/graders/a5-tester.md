---
type: regex
pattern: '^agents/tester\.md: .*\b(never|not|don.t)\b[^.]*(assume|rely)[^.]*hook[^.]*(check|run)|^agents/tester\.md: .*(run|runs)[^.]*check[^.]*(yourself|own)[^.]*before[^.]*commit'
flags: m
---
[A5] The tester runs the project checks itself before committing and never assumes the commit hook will.
