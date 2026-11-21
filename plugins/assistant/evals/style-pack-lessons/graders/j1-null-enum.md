---
type: regex
pattern: '^index\.md: - \*\*S[23]\.[0-9]+ .*\bnull\b`?[^.]*(stands? for|means?|represents?|encodes?|signals?)[^.]*(specific|particular|distinct|named)[^.]*(result|outcome|case|state)[^.]*(\benum\b[^.]*violat|violat.*\benum\b)'
flags: mi
arm: with-only
---
[J1] S2 or S3: a `null` that stands for one specific result violates the rule; an enum member says it.
