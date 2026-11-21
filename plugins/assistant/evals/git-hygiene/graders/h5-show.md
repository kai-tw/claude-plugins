---
type: regex
pattern: '^agents/builder\.md: .*(sed|script|rename)[^.]*(read|check|inspect|verify|look at)[^.]*git show HEAD:<path>[^.]*(not|never|rather than|instead of) (only |just )?(the )?(working (tree|copy|directory)|files? on disk)'
flags: mi
---
[H5] builder.md: after a scripted bulk edit (sed, a rename), what was committed is checked with git show HEAD:<path>, not only the working tree.
