---
type: regex
pattern: '^    cd \./proj && claude plugin install d@m --scope project && claude plugin update p@m --scope project$'
flags: m
arm: with-only
---
When the update fails, reason gives the full manual command, dependency install included.
