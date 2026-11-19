---
type: regex
pattern: '^skill-add-fails=1$'
flags: m
arm: with-only
---
[F2] SKILL.md: otherwise a failed git worktree add is reported as it is; the branch it left is deleted and the half-made folder goes to the trash.
