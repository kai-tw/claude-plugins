---
type: regex
pattern: '^b-fires=([13-9]|[1-9][0-9]+)$'
flags: m
arm: with-only
---
[V1] build-fix, verify-code, build-fix, verify-code with a [1.1] fix in its Logic block: the first verify-code report after the 2nd build-fix round has a [1.n] fix finding in its Logic block, no advise report follows, so the check fails with an exit that is not 2.
