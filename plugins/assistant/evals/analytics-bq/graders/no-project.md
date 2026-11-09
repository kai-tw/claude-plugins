---
type: regex
pattern: 'asst-analytics: no --project <gcp-project>: .*CLAUDE\.md names it\.\s+noproj=2'
arm: with-only
---
Without --project it stops with exit 2 and says where the project id comes from.
