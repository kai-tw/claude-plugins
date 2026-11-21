---
type: regex
pattern: '([Ii]nvent|[Mm]ake up|[Ww]rite|[Dd]raft) (placeholder |your own |new |plausible )?(copy|text|strings?) (for|where|when)[^.]*(spec|brief)[^.]*(missing|silent|lacks|has none|gives none|doesn.t|does not)|fields?[^.]*(is|are) (filled|populated) with (plausible |placeholder |invented |made-up |your own )+(copy|text)'
match: not_contains
flags: m
---
[F6] The builder is never told to invent copy where the spec has none.
