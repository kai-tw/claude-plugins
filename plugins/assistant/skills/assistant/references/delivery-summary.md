# Delivery summary — one screen, eight blocks, every line clickable

Built from the verifier reports, with string values from the builder's `strings:`
blocks unless a text finding changed them; the user reads this, not the diff and not the
reports. Anything a linter or a passed check already settled is one line.

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
- <scenario> → <test file:line> · missing: <scenario or failure event with no test> or none
## On device
- <platform>: <passed | failed | not run — why> on <phone>   (or none: the project has no on-device tests)

## Text (changed since the screen review?)
<n> strings · approved at the screen review · meaning changed since: <n>   (or no string changes)
accepted as drafted: <this task's line and the `all` line from `asst-strings rate`>
### <key> · <where it renders> · <available width>       (only those changed since)
- <locale> <value>          (one line per locale, source first)
- value approved at the screen review: <value> → change: <one sentence> · awaiting re-approval

## Other (automated checks)
security passed · naming passed · coverage <n unexecuted lines, each named>   (or `no coverage tool` from the project config)
```

**Approval is given at the screen review; this page only asks whether it still holds.** A string
whose meaning changed since the screen review loses its approval (core rule U5.1: a changed meaning
takes a new key), and **a locale that lost it may be neither merged nor
committed**, at the same level as a destructive action (SKILL.md §Dispatch rules). A string that reaches this page without passing the screen review is a breach in the
flow: it goes back to the screen review for a supplement, never signed off on this page.
