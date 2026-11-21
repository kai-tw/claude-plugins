---
type: regex
pattern: '^agents/verifier\.md: .*\(0 pre-existing outside the boundary / lint-catchable '
flags: m
---
The verifier's scoring line gives 0 only to pre-existing behaviour outside the boundary, so an inside-the-boundary base-branch defect is not scored away.
