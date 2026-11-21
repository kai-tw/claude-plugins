---
type: regex
pattern: '(never|not|n.t|don.t|do not|refuse to|without) (to )?(delete|retarget|re-target|repoint) |(even|regardless)[^.]*(tip|head)|branch -D|(and|then|also) delete (any|every|all) (other )?local branch'
match: not_contains
flags: mi
---
[H3] Close never skips the retarget or the prune, and never deletes a branch whose tip is not the merged PR head.
