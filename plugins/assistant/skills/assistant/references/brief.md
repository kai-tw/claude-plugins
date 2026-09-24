# Decision brief — the one page the founder approves

Under 40 lines. Every line is a decision, never a description. Two marks:
`Needs you` (intent: scope, a trade-off, product behaviour) · `Decided` (listed
for veto, silence accepts). Once answered, each `Needs you` line ends with `Picked A`
(or B); the filed brief is the record, so a line without a choice is unfiled.
Labels and marks are written in the founder's language (SKILL.md §Language); later
steps find sections by meaning, so a filed brief may carry them in any language.

```
# <Task> — Decision brief            <project> · <tier> · <date>

## Intent
- Needs you  <the fork, one line> — A: <option> / B: <option> · Recommend <A|B>: <why, one clause> · Cost of the wrong pick: <one clause>
- Decided <the ruling, one line> · Reason: <one clause>

## System design
```mermaid
flowchart LR   %% only cross-layer edges; new nodes marked (NEW)
```
- Ownership: <each NEW thing — why new, which layer, who owns its state>
- Data flow and state: <source → sink; shared state: who writes, does order matter>
- Boundaries: <persisted format / schema / API touched? old version behaviour> or none
- Rejected alternatives: <one line + its cost>

## Screens (UI in scope only)
- <screens × states the contact sheet will show>

## Budget and debt
- review <0|1> · fix 2 · upload 2
- Known debt: <none, or one line each>
```
