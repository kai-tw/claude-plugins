---
type: regex
pattern: '^skills/assistant/references/verify\.md: .*whole task.s diff \(`origin/<base>\.\.\.HEAD`; on svn,[^.]*`svn diff`[^.]*BASE'
flags: m
---
[RC] verify.md: on svn the whole task's diff is a plain `svn diff`, against BASE — the task never commits, so it holds the whole task and no upstream commit.
