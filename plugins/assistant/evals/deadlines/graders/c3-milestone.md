---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/tracker\.md|agents/builder\.md): .*milestone[^.]*(never|not|do not|don.t)[^.]*(change|edit|modif|write)[^.]*Current state|Current state[^.]*(date|deadline)[^.]*milestone'
flags: mi
---
[C3] a GitHub milestone is never edited; the user's date goes in the issue row's Current state and wins over the milestone.
