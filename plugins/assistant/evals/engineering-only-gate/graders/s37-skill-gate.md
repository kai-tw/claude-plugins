---
type: llm
---
[S37] PASS if references/verify.md opens a fix round only for findings marked as opening one, never for a builder's `debt:` line, sets no cap on the number of fix rounds, and, when a `fix` finding comes back in verify-code after the fix round meant to fix it (same file, same rule), dispatches the `advisor` once for it before anything goes to the user; only the findings the round on the advisor's advice still leaves become one `Needs you` line, with the advise report's path.
FAIL if any kept finding or `debt:` line opens a round, a fixed cap on rounds is set, the leftover goes to the user without the advisor dispatched first, or the leftover is dropped or spread over several lines.
