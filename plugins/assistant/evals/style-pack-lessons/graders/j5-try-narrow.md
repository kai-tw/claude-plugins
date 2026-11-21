---
type: regex
pattern: '^index\.md: - \*\*S7\.[0-9]+ .*\btry\b`?[^.]*(wrap|cover|enclos|span|contain)[^.]*(code|statements?|lines?|calls?|work)[^.]*(cannot|can.t|does not|doesn.t|never) throw[^.]*violat'
flags: mi
arm: with-only
---
[J5] S7: a try that also covers code that cannot throw violates the rule.
