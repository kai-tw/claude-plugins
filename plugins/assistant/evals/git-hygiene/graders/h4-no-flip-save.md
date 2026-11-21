---
type: regex
pattern: '(never|not|n.t|skip|without|no need to) (to )?(sav|stor|writ|copy)(e|es|ing)?[^.]*(git diff|untracked)|git diff.? (alone|only)|, which (excludes|omits|skips) staged'
match: not_contains
flags: mi
---
[H4] The save is never skipped, and never narrowed to the unstaged diff.
