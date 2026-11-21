---
type: regex
pattern: '^skills/assistant/references/tracker\.md: .*## Close.*([Bb]efore[^.]*delet[^.]*branch[^.]*(retarget|re-target|repoint|point|move|change the base of)[^.]*(PRs?|pull requests?)[^.]*(stacked|based) on|(retarget|re-target|repoint|point|move|change the base of)[^.]*(PRs?|pull requests?)[^.]*(stacked|based) on[^.]*before[^.]*delet)'
flags: mi
---
[H3] tracker.md Close: before a merged PR's branch is deleted, every PR stacked on it gets another base.
