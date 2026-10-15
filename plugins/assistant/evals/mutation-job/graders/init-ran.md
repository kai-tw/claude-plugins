---
type: regex
pattern: '^generated: yes$'
flags: m
arm: with-only
---
worktree_init runs in the job's worktree before plan-mutation, so what git ignores is there.
