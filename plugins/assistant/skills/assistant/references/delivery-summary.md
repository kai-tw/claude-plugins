# Delivery summary — one screen, eight blocks, every line clickable

Built from the verifier reports and the builder reports (`debt:`, `declined:` lines);
the user reads this, not the diff and not the reports. Anything a linter or a passed
check already settled is one line.

```
# <Task> — <PR #n ready | r<rev> pending>   <project> · <sha | working copy>

## Logic
- <user scenario>: <entry file:line> → <decision point file:line> → <outcome>
## Data flow
- <source file:line> → <transform file:line> → <sink file:line> · may be empty / old format: <where>
## Code style
- <deviation file:line> · accepted because: <the builder report's declined reason verbatim>   (lint-caught items never appear)
## Error handling
| Failure event | Caught at | User sees | log |
## Built vs approved design
- <deviation from the brief's System design + reason> or no deviation
## Tests
- <scenario> → <test file:line> · missing: <scenario, failure event or case-table cell with no test> or none   (or none: the project has no test framework)
## On device
- <platform>: <passed | failed | not run — why> on <phone>   (or none: the project has no on-device tests)
## Listed, not fixed
- <file:line> — <the `list` finding or the builder's `debt:` line in one line>   (or none)

## Other (automated checks)
security passed · naming passed · coverage <n unexecuted lines, each named>   (or `no coverage tool found`)
```
