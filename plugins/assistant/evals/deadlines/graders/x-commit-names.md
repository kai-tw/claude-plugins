---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*commit,? (ending and )?naming (the|its|your) slice|commit messages?[^.]*nam[^.]*slice'
match: not_contains
flags: mi
---
[B2] no rule makes a commit message name its slice.
