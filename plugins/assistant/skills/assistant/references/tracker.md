# The tracker — where tasks live, every turn's scheduler pass, Close

## Where

Where tasks live follows the project's convention, read from its CLAUDE.md: Notion
(`references/notion.md`); GitHub or any other through the environment's tool; a file board by
editing `.claude/.assistant/board.md` (columns Slug, Name, Status, Stage, Blocked by, Parent item)
and `tasks/<slug>/brief.md`. None found: ask the user once and write the answer into its CLAUDE.md.

## Rows

One row per task: Status is In Progress · Next · Backlog · Deferred, `Stage` mapped as: task
statement → Product Plan · brief → Engineering Plan · screens → Design Plan · build →
Implementation · verify → Review · deliver → QA; a tracker lacking these fields uses labels or lists.
`Blocked by` names only the rows it waits for, and a `Next` row needs one; a row that waits on
something outside the tracker is `Deferred`, its condition in the body. When a row closes, a
`Next` row whose last blocker it was turns `In Progress`: one not yet started (a later sub-task of
a split) starts at the investigation, one a question row blocked carries on at its `Stage`; a
parent whose last sub-item it was closes too.

The decisions you file are engineering decisions (design, structure), one entry per question, to
Notion's `decision-log`; with any other tracker, to `.claude/.assistant/kb/decisions/<slug>.md`.

## The scheduler pass

Every turn: the live rows, answered spec question rows and new candidates → file them → advance
or dispatch each live row → surface new `Needs you` lines together. Live = `In Progress`, apart
from a parent, whose sub-items are the work. A Close changes the tracker, so the pass runs again
until no row advances — the turn ends at a `Needs you`, a blocker or a quiet tracker, never at a
Close. A row's progress is what the tracker and the disk hold, not what you remember:
`asst-report summary` shows every task's newest report of each kind; a row whose awaited report
isn't there and has no agent of yours on it in `ListAgents` → dispatch it again. `digest` is one
line per row. A spec question row is answered once the PM moves it to the tracker's done status:
re-read its spec page, then close it (`references/brief.md`).

Candidates are untracked work waiting on the user in task sources named in the project's
CLAUDE.md like the tracker (on GitHub: assigned issues, review requests, own PRs with changes
requested or red checks). A row ends its `Name` with the source ref (`… (pr#42)`); a candidate
whose ref already ends a row `Name`, any status, is not new. Each new candidate is one
`Needs you` line — take it (task statement, row `Status=In Progress`) or pass (row
`Status=Backlog`) — so a ref is asked once. A source that can't be read is named, with the
reason, in the turn's `Needs you` lines, not taken as no candidates.

## Close

Once the PR has merged, the task row is deleted (closed where it can't
be) and no record of the task is kept — a row never moves to `Shipped`. Delete the PR's worktree,
local branch and remote branch, unasked, once `HEAD` matches the merged PR's head.
