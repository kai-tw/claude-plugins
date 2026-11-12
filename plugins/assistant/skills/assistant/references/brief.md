# Decision brief — the one page the user approves

Read at step 3. Write it from the investigation's findings and open questions, and the spec
pages the task touches, read first. Before writing it, run `asst-cite <worktree> <investigation report path>`: re-check a FAIL row
in the code once; still failing, it enters the brief as `unverified`. When the design hinges on
whether a case happens and no finding shows it, measure it once in the code or by an experiment;
a case still unshown is cut, not handled.

When the design adds a class, a dependency or a persisted format, or the project config sets
`architecture:`, one `verifier` `brief-review` on the draft first, so the user is asked once, all
`Needs you` in one message — a question is never marked `Decided` for lack of room. Once
approved, append the brief to the task row's body — the approved design every later step reads
without your context — and file each answered engineering question as a decision (Context ·
Decision · Consequence, the rejected option and its cost in Consequence; `references/tracker.md`).
A product behaviour a later round needs changed is a spec question asked as below, and the code
changes once you've re-read the updated page.

Under 40 lines, the case table aside. Every other line is a decision, never a description. Two marks:
`Needs you` (intent: scope, a trade-off, product behaviour) · `Decided` (your own
engineering call, listed for veto; the user's silence never makes it theirs).
Every product behaviour the task adds or changes — what the user sees, or how a
feature behaves — quotes its spec page verbatim; one the task keeps as is gets
a link to its page section, never a restatement. A behaviour or a case-table cell the
spec doesn't decide, or a spec that conflicts with what the code shows: first ask the
user whether to open a question row for the product side; declined, it is a `Needs you`;
agreed, create a tracker row without `Parent item` (a row with sub-items is never
dispatched): Name = the comment prefix `references/notion.md` gives, plus a one-line summary of the question;
body = a link to the spec page section, the passage quoted verbatim, then the question;
`Status=Deferred`, condition "the PM answers". The task row turns `Next`, `Blocked by` it;
further discussion goes in its page comments. The PM answers there, updates the spec page
and moves the row to the tracker's done status; the scheduler pass that sees this re-reads
the page, then closes the question row (`references/tracker.md`). Either
way the spec question carries a concrete example from the code (`file:line`: what the
app does in that case); once the page is updated, re-read it and quote it — never write the rule yourself, in the brief, a `Decided` line or a decision. Once answered, each `Needs you` line ends with `Picked A`
(or B); the filed brief is the record, so a line without a choice is unfiled.
When the project config sets `architecture:`, read that document in the task's worktree
and cite it by path and section heading, never copying its text. A design that
departs from what the architecture document states is `Needs you`, citing the section,
and the departing option rewrites that section in the same task's diff, and that file joins the task statement's boundary; where the
document says nothing, `Decided` stays allowed.
Labels and marks are written in the user's language (SKILL.md §Language); later
steps find sections by meaning, so a filed brief may carry them in any language.
The design covers the cases shown to happen and nothing more: a NEW thing, guard,
retry, fallback or lock with no evidence on the `Evidence` line is cut.

```
# <Task> — Decision brief            <project> · <tier> · <date>

## Intent
- Needs you  <the open question, one line> — A: <option> / B: <option> · Recommend <A|B>: <why, one clause> · Cost of the wrong pick: <one clause>
- Decided <the ruling, one line> · Reason: <one clause>

## System design
```mermaid
flowchart LR   %% only cross-layer edges; new nodes marked (NEW)
```
- Ownership: <each NEW thing — why new, which layer, who owns its state, the architecture section it follows (path § heading)>
- Data flow and state: <source → sink; shared state: who writes, does order matter>
- Boundaries: <persisted format / schema / API touched? old version behaviour> or none
- Evidence: <each NEW thing, guard, retry, fallback or lock → the case it handles · where that case is shown to happen (file:line · experiment · issue)>
- Rejected alternatives: <the simplest design that could work, and the evidenced case it fails; any other, one line + its cost>

## Scenarios
- S<n> <what the user does> → <what they see or keep>
- F<n> <a failure event> → <what the user sees, and the state left behind>
- B<n> <a boundary from Boundaries: empty · old format · order · limit> → <the expected result>

## Case table (the investigation's, every combination of the interleaving conditions; else omitted)
| C<n> | Conditions | Base branch (file:line) | Spec's rule | After the change |

## Screens (UI in scope only)
- <screens × states the screens page will show>

## Debt
- Known debt: <none, or one line each>
```

## A request split into sub-tasks

A request one brief cannot hold becomes a parent row holding the request
in its body, and under it one sub-item per task statement, in order (`Parent item` the
parent): each its own row and worktree, each later one
`Status=Next`, `Blocked by` the sub-item it waits for. The parent is never dispatched. The split itself is a `Decided` in the
first brief.
