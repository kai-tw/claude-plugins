# Decision brief — the one page the user approves

Read at step 3, and at step 1 to split a task. Write it from the investigation's findings and open questions, and the spec
pages the task touches, read first; you write it, and a drafter you delegate to gets those pages.
File every version, before a review or the user sees it, with `asst-report put <slug> brief --worktree <worktree>`;
a brief it refuses goes to no one. Before writing it, run `asst-cite <worktree> <investigation report path>`: re-check a FAIL row
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

One page the user reads in one sitting, the case table aside. Every other line is a decision, never a description. Two marks:
`Needs you` (intent: scope, a trade-off §Choosing the design leaves to the user, product behaviour) · `Decided` (your own
engineering call, listed for veto; the user's silence never makes it theirs).
Every product behaviour the task adds or changes — what the user sees, or how a
feature behaves — quotes its spec page verbatim; one the task keeps as is gets
a link to its page section, never a restatement. A behaviour or a case-table cell the
spec doesn't decide, or a spec that conflicts with what the code shows: if the PM can see
the tracker, first ask the user whether to open a question row for the PM; if not, or declined, it
is a `Needs you`;
agreed, create a tracker row without `Parent item` (a row with sub-items other than slice rows is a split's
parent, never dispatched): Name = the comment prefix `references/notion.md` gives, plus a one-line summary of the question;
body = a link to the spec page section, the passage quoted verbatim, then the question;
`Status=Deferred`, condition "the PM answers". The task row turns `Next`, `Blocked by` it;
further discussion goes in its page comments. The PM answers there, updates the spec page
and moves the row to the tracker's done status; the scheduler pass that sees this re-reads
the page, then closes the question row, and the task row carries on at its `Stage`
(`references/tracker.md`). Either
way the spec question carries a concrete example from the code (`file:line`: what the
app does in that case); once the page is updated, re-read it and quote it — never write the rule yourself, in the brief, a `Decided` line or a decision. Once answered, each `Needs you` line ends with `Picked A`
(or B), re-filed; the filed brief is the record, so a line without a choice is unfiled.
Before writing a `Needs you`, check it: read the linked pages and the spec pages adjacent to them; see whether two rules together already decide it; search the decision log, earlier briefs and tracker rows for it.
A limit of the code is not a spec question: it goes in the brief's design. Existing behaviour no spec page backs is not a precedent, and is not asked about either. A case the user has ruled out gets no question about its UI.
Unless the project config sets `spec: none`, the brief opens with `Spec pages read`, each page
and the last-edited time it showed, and every `Needs you` line carries a spec field: the passage
that comes closest, verbatim, and why it doesn't decide this, or the sections checked that say nothing, then the pages and records checked.
When the project config sets `architecture:`, read that document in the task's worktree
and cite it by path and section heading, never copying its text. A design that
departs from what the architecture document states is `Needs you`, citing the section,
and the departing option rewrites that section in the same task's diff, and that file joins the task statement's boundary; where the
document says nothing, `Decided` stays allowed.
Labels and marks are written in the user's language (SKILL.md §Language); later
steps find sections by meaning, so a filed brief may carry them in any language, except
`Spec pages read`, `last edited`, `Needs you` and `spec:`, which `asst-report` checks as written below.
The design covers the cases shown to happen and nothing more: a NEW thing, check,
retry, fallback or lock with no evidence on the `Evidence` line is cut.
Steps the brief runs in order (a deploy, a data migration): check each step against the state the earlier steps leave and the states in which the investigation found the tool fails; a step that fails on an earlier step's state means the order is wrong.
A deploy-time value the task adds or moves (the identity the code runs as, an environment variable, a region) cites on the `Evidence` line the `file:line` where the deploy sets it.
A name a ruling gives a new thing (a class, an export, a file) is checked against style-pack and the project's rules before the brief goes to the tester or builder, and written in the form style-pack and the project's rules allow: where those rules forbid top-level functions, `Class.member`.
When another of the user's projects already made the same choice, recommend the same and cite where it was made, unless a fact shows it cannot work here. Citing it follows SKILL.md §Disclosure.
When the lower layer can be built first, build the lower layer first, never an interim bridge.

```
# <Task> — Decision brief            <project> · <tier> · <date>

## Spec pages read
- <page title or path> · last edited <the time the page shows>

## Intent
- Needs you  <the open question, one line> — A: <option> / B: <option> · Recommend <A|B>: <why, one clause> · Cost of the wrong pick: <one clause> · Measured cost (a choice between designs): A: <…> / B: <…> · spec: "<verbatim quote>" — <why it doesn't decide this> | spec: none in <the sections checked> · checked: <pages and records>
- Decided <the ruling, one line> · Reason: <one clause>

## System design
```mermaid
flowchart LR   %% only cross-layer edges; new nodes marked (NEW)
```
- Ownership: <each NEW thing — the closest existing units and why each can't be reused, why new, which layer, who owns its state, the architecture section it follows (path § heading)>
- Data flow and state: <source → sink; shared state: who writes, does order matter>
- Boundaries: <persisted format / schema / API touched? old version behaviour> or none
- Evidence: <each NEW thing, check, retry, fallback or lock → the case it handles · where that case is shown to happen (file:line · experiment · issue)>
- Fit: <the chosen design against criteria 1–3, each with its evidence>
- Rejected alternatives: <each one: the criterion it fails · the evidence>

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

## Choosing the design

A design fits when it passes all four, checked in this order:

1. Spec and rulings. It does what the spec page says, agrees with the user's rulings, and doesn't build on a data shape that a ruling or a scheduled tracker row will replace.
2. Ownership. Each piece of data is held by the layer that produces it and can keep it valid. No other layer keeps a copy that goes stale when the owner changes.
3. Project conventions. Both kinds: written rules (the files `rules:` and `architecture:` name, and style-pack); codebase patterns (how the closest existing features already do the same kind of thing, cited at `file:line`: two independent sites, or one and say it's the only one). When a written rule and a pattern disagree, the rule wins. A pattern built on a shape that criterion 1 replaces doesn't count.
4. Simplest. Among designs that pass 1–3, the one with the fewest new concepts (types, states, counters, conversions), then the fewest files touched.

Every rejected alternative names the criterion it fails and the evidence: a spec quote, `file:line`, or a measurement. "Not smaller" or "more work" without a measurement is not evidence.
When two alternatives both pass 1–3, criterion 4 decides, with a measurement when size or speed is the difference. It's a `Needs you` only when they'd change what the user sees, waits for or pays for, or when no measurement can separate them; the question then states each one's measured cost.

## A request split into sub-tasks

A request one brief cannot hold becomes a parent row holding the request
in its body, and under it one sub-item per task statement, in order (`Parent item` the
parent): each its own row and worktree, each later one
`Status=Next`, `Blocked by` the sub-item it waits for. The parent is never dispatched. The split itself is a `Decided` in the
first brief.
