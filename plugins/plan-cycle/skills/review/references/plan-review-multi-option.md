# engineer-plan-reviewer — multi-option plans

Read from `agents/engineer-plan-reviewer.md` Stage 3 / Stage 4 only when the
plan carries more than one option.

For **multi-option** plans: build a comparison table (findings × options),
**recommend one option** with a one-paragraph rationale — what drove the call,
what trade-off the caller is buying — and name the tie-breaker when two are
genuinely close. An option carrying a `critical` is not recommendable.

Report: one option block per option (the single-option format), then:

```markdown
## Option B — <name>

[same structure]

## Comparison

| Dimension | A | B | C |
|---|---|---|---|
| 10. Abstraction/reuse/ownership | — | 1 critical | 1 warning |
| 11. Migration & back-compat | 1 warning | — | — |

Counts by severity, never a total — a total re-creates the threshold §Severity
removed. An option carrying a `critical` is not recommendable.

### Trade-offs

- A's only open item is a migration warning; nothing blocks it.
- B leaves the persisted schema untouched but adds a second home for a datum an
  existing entity already owns — that is its `critical`.
- C is clean on both, and buys it with a heavier package surface.

## Recommendation

**Option A**, with the three improvements above applied before
implementation. Driving factor: A's migration gap is fixable in-plan;
B's ownership gap requires deciding which entity owns the datum first.
```
