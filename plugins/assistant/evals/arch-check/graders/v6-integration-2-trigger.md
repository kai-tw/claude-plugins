---
type: regex
pattern: '^b-integration-2: .*(verify-code-4([^0-9].*)?architecture|architecture.*verify-code-4([^0-9]|$))'
flags: mi
arm: with-only
---
[V6] The line that asks for the architecture check names verify-code-4, not verify-code-3 that reviewed the integration slice.
