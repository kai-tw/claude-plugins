---
type: regex
pattern: '(never|not|n.t|no need to|need not) (be )?(check|compar)(e|es|ed|ing)? (each|every|an?|the) (ordered )?steps?|(not|never|n.t) (mean|show)s? (that )?the (order|sequence) is wrong'
match: not_contains
flags: mi
---
[G1] Ordered steps are never exempt from the check, and a step failing on an earlier step's state is never read as a fine order.
