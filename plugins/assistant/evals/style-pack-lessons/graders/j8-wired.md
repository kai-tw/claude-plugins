---
type: regex
pattern: '^index\.md: - \*\*S(4|10)\.[0-9]+ .*generator[^.]*must[^.]*(\bCI\b[^.]*worktree|worktree[^.]*\bCI\b)'
flags: mi
arm: with-only
---
[J8] S4 or S10: the generator must run in CI and in worktree setup.
