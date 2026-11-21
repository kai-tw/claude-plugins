---
type: regex
pattern: '^index\.md: - \*\*S2\.[0-9]+ .*(root|base|catch-all|universal) (object |exception |error )?type[^.]*violat.*(concrete|specific|exact|actual|precise) type|^index\.md: - \*\*S2\.[0-9]+ .*(concrete|specific|exact|actual|precise) type.*(root|base|catch-all|universal) (object |exception |error )?type[^.]*violat'
flags: mi
arm: with-only
---
[J6] S2: a value whose concrete type is known, declared with a root or base type, violates the rule.
