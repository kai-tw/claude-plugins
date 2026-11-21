---
type: regex
pattern: '^agents/verifier\.md: .*([Ii]nside|[Ww]ithin) the[^.]*boundary[^.]*base branch[^.]*(`fix`|Fix)[^.]*`list`'
flags: m
---
[R3] The verifier reports a base-branch defect inside the boundary as an ordinary finding (`fix` or `list`) that opens a fix round, not as out of scope.
