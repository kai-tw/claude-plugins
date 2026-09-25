---
type: regex
pattern: '^new: args: .* --journal \S+/plan-mutation-[0-9]+-dart\.jsonl '
flags: m
arm: with-only
---
With dart_mutants 0.5.0 the engine gets a journal outside the repo.
