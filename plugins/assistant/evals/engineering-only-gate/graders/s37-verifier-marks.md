---
type: llm
---
[S37] PASS if the verifier text has each finding marked as opening a fix round or not, and says a finding opens one only when it changes what a user sees or does, the data, security, a behaviour the spec states, or a behaviour that has no test, while code style, test tidiness and wording do not.
FAIL if every finding opens a round, the marking is missing, or the criteria are not those.
