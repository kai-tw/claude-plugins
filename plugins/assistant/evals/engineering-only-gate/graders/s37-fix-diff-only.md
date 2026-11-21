---
type: llm
---
[S37] PASS if references/verify.md sends the verifier only the fix commit's diff on a fix round's re-review, plus the whole case table.
FAIL if a fix round sends the whole diff back again, or the case table is left out. The one `verify-code` on the whole task's diff before ready, after a fix round or a base merge, is not a fix round's re-review.
