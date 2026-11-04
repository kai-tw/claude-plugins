---
type: llm
---
PASS if the answer says the check command is `npm test`, the verifier reads `docs/glossary.md` as the glossary, and the config file is left as it is.
FAIL if it says the project has no check command or no glossary, or that `gate:` / `strings_canon:` must be renamed first.
