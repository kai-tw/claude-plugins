---
type: regex
pattern: '^index\.md: - \*\*S16\.[0-9]+ .*(wrapper|function|helper)[^.]*(called|used|invoked)[^.]*(only once|once|from (only )?one (site|place|call site|caller)|from a single (site|call site|caller))[^.]*violat|^index\.md: - \*\*S16\.[0-9]+ .*violat[^.]*(wrapper|function|helper)[^.]*(called|used|invoked) (only )?(once|from (only )?one (site|place|call site|caller)|from a single (site|call site|caller))'
flags: mi
arm: with-only
---
[J2] S16: a wrapper called from only one site violates the rule.
