---
type: regex
pattern: '^index\.md: - \*\*S1[16]\.[0-9]+ .*\b(endpoint|request handler)s?\b[^.]*(more than one|two or more|several|multiple) (things|jobs|operations|actions|effects|tasks)[^.]*violat|^index\.md: - \*\*S1[16]\.[0-9]+ .*\bendpoint\b[^.]*(does|do|performs?) (exactly |only )?one (thing|job|operation|action)'
flags: mi
arm: with-only
---
[J10] S11 or S16: an endpoint that does more than one thing violates the rule.
