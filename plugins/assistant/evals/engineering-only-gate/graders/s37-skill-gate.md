---
type: llm
---
[S37] PASS if SKILL.md's verify step opens a fix round only for findings marked as opening one, never for a builder's `debt:` line, allows at most two fix rounds, and turns what is left after the second into one `Needs you` line.
FAIL if any kept finding or `debt:` line opens a round, the cap is missing or is not two, or the leftover is dropped or spread over several lines.
