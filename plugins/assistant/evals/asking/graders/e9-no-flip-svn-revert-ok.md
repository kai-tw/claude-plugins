---
type: regex
pattern: 'svn revert.? (is|are) (fine|allowed|ok|okay|permitted|safe)|(may|can) (run|use) .?svn revert|approved, undone by .?svn revert|undone by (an? )?.?svn revert'
match: not_contains
flags: m
---
[E9] SKILL.md: `svn revert` is never allowed as the way to undo your own changes.
