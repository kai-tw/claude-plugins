# The tracker — where tasks live, every turn's scheduler pass, Close

## Where

Where tasks live follows the project's convention, read from its CLAUDE.md: Notion
(`references/notion.md`); GitHub or any other through the environment's tool; a file board by
editing `.claude/.assistant/board.md` (columns Slug, Name, Status, Stage, Blocked by, `Due` (YYYY-MM-DD or blank), Parent item)
and `tasks/<slug>/brief.md`. None found: ask the user once and write the answer into its CLAUDE.md.

## Rows

One row per task (slice rows, below, are not tasks and carry no `Stage`): Status is In Progress · Next · Backlog · Deferred, `Stage` mapped as: task
statement → Product Plan · brief → Engineering Plan · screens → Design Plan · build →
Implementation · verify → Review · deliver → QA; a tracker lacking these fields uses labels or lists.
`Blocked by` names only the rows it waits for, and a `Next` row needs one; a row that waits on
something outside the tracker is `Deferred`, its condition in the body. When a row closes, a
`Next` row whose last blocker it was turns `In Progress`: one not yet started (a later sub-task of
a split) starts at the investigation, one a question row blocked carries on at its `Stage`; a
split's parent whose last sub-item it was closes too. When only one task runs at a time (`Dispatch rules`, low disk) and several `Next` task rows come free together, the one with the earliest `Due` turns `In Progress` and the others become `Blocked by` it; a row with no deadline goes last, the same date in creation order.

Open the row body with a dated "Current state" paragraph, never stacked under older ones: when the state changes, replace it whole. Properties carry no task content (`Blocked by` and `Due` only order the schedule), a `Deferred` row's condition included: the problem, the fix and the progress go in the body.

The decisions you file are engineering decisions (design, structure), one entry per question, to
Notion's `decision-log`; with any other tracker, to `.claude/.assistant/kb/decisions/<slug>.md`.

## Slices

Once the brief is approved (a `small` task: once you rule it), each builder slice gets its own slice row, and a `fix` slice gets one when it is cut: a sub-item of the task row, `Name` `<slug>/<n> <what it does>`, `Status=Next`, where a Name that starts with its parent's slug, a `/` and a number tells a slice row apart from a split's sub-task, whose Name may hold a `/` of its own. The slice row's body holds its estimated hours as an `Estimate: <n>h` line outside Current state, their only home: the task statement carries none; carry that line into every rewrite of the body. Slices that must run in order are chained by `Blocked by`; ones that can run in parallel are not. A slice row skips what a task row does on its own: a `Next` one needs no `Blocked by`, closing one never turns the next `In Progress`, none starts at the investigation, and none counts in the earliest-`Due` order.

Dispatching a slice's builder turns its row `In Progress`, the start date and time in its Current state. After a builder's `partial` report the slice row stays, back to `Next` with the start time cleared from its Current state and its `Estimate:` line rewritten as the hours left. Once its builder commits and the checks pass, delete the slice row, as you do a slice the user agreed to cut; when the task row closes, its slice rows are deleted with it.

A task row with slice rows is still the task: the brief, screen review, verify and PR run on it, and its slices share its worktree. Once its last slice row is deleted, the task row stays open for verify and the PR.

On GitHub a slice row is a checklist item in the task issue's body, `- [ ] <n> <what it does> · <hours>h`, its start time added at dispatch, ticked once done and removed when cut, never a sub-issue, which would notify every watcher.

## The scheduler pass

Every turn: the live rows, answered spec question rows and new candidates → file them → advance
or dispatch each live row → surface new `Needs you` lines together. Live = `In Progress`, apart
from a split's parent, whose sub-items are the work. A Close changes the tracker, so the pass runs again
until no row advances — the turn ends at a `Needs you`, a blocker or a quiet tracker, never at a
Close. A row's progress is what the tracker and the disk hold, not what you remember:
`asst-report summary` shows every task's newest report of each kind; a row whose awaited report
isn't there and has no agent of yours on it in `ListAgents` → dispatch it again. An `In Progress` slice row that a filed builder report names on its first line is updated from that report, never dispatched again; only a report filed after the row's start time counts. After an interrupted turn a background agent may already be dead: before calling it still running, check its transcript for new progress; being in `ListAgents` alone does not count, and no new progress means dispatch it again. `digest` is one
line per task row, slice rows set aside. A spec question row is answered once the PM moves it to the tracker's done status:
re-read its spec page, then close it (`references/brief.md`).

Candidates are untracked work waiting on the user in task sources named in the project's
CLAUDE.md like the tracker (on GitHub: assigned issues, review requests, own PRs with changes
requested or red checks). A row ends its `Name` with the source ref (`… (pr#42)`); a candidate
whose ref already ends a row `Name`, any status, is not new. Each new candidate is one
`Needs you` line — take it (task statement, row `Status=In Progress`) or pass (row
`Status=Backlog`) — so a ref is asked once. A source that can't be read is named, with the
reason, in the turn's `Needs you` lines, not taken as no candidates.

Delete without asking a row whose subject is gone (code removed, reported failure vanished) once source or CI confirms it, and say what you checked. A row that only looks affected by someone else's open ruling is not deleted.

While a request has a scope `Needs you` unanswered, nothing under it is dispatched.

## Deadlines

A row's deadline is its date column (Notion's Due, a file board's `Due`, on GitHub the user's date in the issue's Current state, else the milestone's date; there it is the `Deadline: YYYY-MM-DD` line, never the paragraph's own date). Every pass, run `date` and read each row's deadline from the row, so a date the PM changed counts from the next pass. A board without a `Due` column (Notion: a date property) reads as no deadline; add the `Due` column only to a file board, on its first write, and never change a Notion database's schema. A task with no deadline still gets its slice rows but skips the late check.

When the user gives a deadline, write it in the row's date column; when it differs from the date the row holds, the user's latest word replaces the row's date. A GitHub milestone is shared by many issues, so never edit it: write the user's date as that line in the issue's Current state, which wins over the milestone, and carry it into every rewrite of Current state.

When a task's remaining hours (the estimates of its open slice rows, an `In Progress` one minus the time since its start) exceed the hours left before the end of its deadline day, that turn gets one `Needs you` line with the estimated finish date and the scope that can be cut. Read the estimates and start times from the slice rows on the tracker, never from memory. Speed up first what leaves the deliverable whole (reordering the schedule, a higher model or effort, slices in parallel); any cut to its scope or checks is asked, never taken.

## Close

Once the PR has merged (svn: once the user's `svn commit`, asked, has run), the task row is
deleted (closed where it can't be) and no record of the task is kept — a row never moves to
`Shipped`. Delete the PR's worktree, local branch and remote branch, unasked, once `HEAD` matches
the merged PR's head; an svn working copy is never deleted.
Before deleting a merged PR's branch, retarget every PR stacked on it to that merged PR's base. Then run `git fetch --prune` and delete each local branch whose upstream is gone and whose PR shows merged, only when the branch's tip is that PR's head, as above; any other branch is kept and named in the report. Judge merged by the PR's state, never by `git merge-base`, because a squash-merged branch is not an ancestor of the base.
When the task ran on a branch in the main checkout, there is no worktree: switch the main checkout back to the default branch right before the branch is deleted.
