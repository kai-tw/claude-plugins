---
type: llm
---
[S37] PASS if references/verify.md opens a fix round only for findings marked as opening one, never for a builder's `debt:` line, sets no cap on the number of fix rounds, and when it judges another round will not settle what is left, turns the remaining `fix` findings into one `Needs you` line.
FAIL if any kept finding or `debt:` line opens a round, a fixed cap on rounds is set, or the leftover is dropped or spread over several lines.
