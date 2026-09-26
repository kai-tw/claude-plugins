---
type: regex
pattern: 'NOT READY — this repo is not known to be private, and #7 publishes'
flags: m
arm: with-only
---
ready refuses a PR body that names a private repo.
