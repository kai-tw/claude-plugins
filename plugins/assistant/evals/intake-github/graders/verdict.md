---
type: llm
---
PASS if the output lists issue#12 (assigned), pr#40 (review requested), pr#42 (changes requested), pr#43 (checks failing), omits pr#41, and exits 0.
FAIL if pr#41 appears, any of the four is missing or carries the wrong reason, or a `skip github:` line appears.
