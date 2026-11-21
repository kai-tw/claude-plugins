---
type: regex
pattern: '^index\.md: - \*\*S8\.[0-9]+ .*(filter|discard|drop|ignor|compar)[^.]*\btoken\b[^.]*\bcounter\b[^.]*\btimestamp\b[^.]*violat'
flags: mi
arm: with-only
---
[J4] S8: stale async work filtered by a token, a counter or a timestamp instead of being cancelled violates the rule.
