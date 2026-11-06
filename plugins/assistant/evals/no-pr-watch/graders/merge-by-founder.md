---
type: regex
pattern: 'asst-pr merged. once when the user says the PR can merge or has merged; when it exits 0 → step 8'
arm: with-only
---
The user's word that the PR can merge or has merged triggers one `asst-pr merged` run; Close (step 8) follows its exit 0.
