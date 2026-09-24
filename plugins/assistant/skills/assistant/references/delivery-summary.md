# Delivery summary — one screen, seven blocks, every line clickable

Built from the verifier reports; the founder reads this, not the diff and not the
reports. Anything a linter or a passed check already settled is one line.

```
# <Task> — <PR #n | r<rev> pending>   <project> · <sha | working copy>

## Logic
- <user scenario>: <entry file:line> → <decision point file:line> → <outcome>
## Data wiring
- <source file:line> → <transform file:line> → <sink file:line> · may be empty / old format: <where>
## Code style
- <deviation file:line> · accepted because: <the builder report's declined reason verbatim>   (lint-caught items never appear)
## Error handling
| Failure event | Caught at | User sees | log |
## As built vs as decided
- <deviation from the brief's System design + reason> or no deviation
## Tests
- <scenario> → <test file:line> · missing: <scenario or failure event with no test> or none

## Text (changed since the ② approval?)
<n> strings · approved at ② · meaning changed since: <n>   (or no string changes)
### <key> · <where it renders> · <available width>       (only those changed since)
- <locale> <value>          (one line per locale, source first)
- value approved at ②: <value> → change: <one sentence> · awaiting re-approval

## Other (automated checks)
security passed · naming passed · coverage <n unexecuted lines, each named> · mutation <score>/80   (or `no coverage/mutation tool` from the adapter)
## Debt
- <one line each, task id>
```

**Approval is given at ②; this page only asks whether it still holds.** A string
whose meaning changed since ② loses its approval (charter U5.1: a changed meaning
takes a new key), and **a locale that lost it may be neither merged nor
committed**. A string that reaches this page without passing ② is a breach in the
flow: it goes back to ② for a supplement, never signed off on this page.
