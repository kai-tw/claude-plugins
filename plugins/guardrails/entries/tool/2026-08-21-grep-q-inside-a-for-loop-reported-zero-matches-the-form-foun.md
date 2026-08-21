---
category: tool
source: agent
date: 2026-08-21
title: grep -q inside a for loop reported zero matches; the || form found 43
---

NOT DIAGNOSED — filed so it is not lost.

    for s in $syms; do grep -rqw "$s" lib --include='*.dart' && continue; ...; done
      → printed nothing

    for s in $syms; do grep -rqw "$s" lib --include='*.dart' || { echo "$s"; }; done
      → found 43

Same predicate, opposite results, and the first form silently claimed "every
symbol resolves". I switched to the `||` form and moved on without finding the
cause, so there is no rule to write yet: a pattern without a root cause would
either miss the real trigger or fire on healthy loops.

Consume this only after the cause is known.
