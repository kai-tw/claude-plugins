---
type: llm
---
PASS if the tool refuses because no --root was given, exits 1, and nothing reached ntn.
FAIL if it printed a dry-run plan, guessed a root, or the error is an ntn auth/workspace error (that means it tried to talk to Notion).
