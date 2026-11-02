---
type: regex
pattern: '^gh workflow run release.yml --ref main -f sha=[0-9a-f]{40}$'
flags: m
arm: with-only
---
release starts release.yml from the default branch with a full commit SHA.
