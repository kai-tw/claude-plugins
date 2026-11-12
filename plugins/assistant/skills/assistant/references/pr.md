# The task's PR — from ready to merged

Read at step 7, before the delivery summary. Git only; on svn the task ends in
`svn commit` (asked) after the delivery summary.

## Ready

Rewrite the PR's title and body from the delivery summary first: the
draft's describe the plan, not what shipped.

Then mark the PR ready, once CI has passed on HEAD
(where CI skips drafts, mark it ready first so CI runs) and every
`verify-*` report is newer than HEAD. A draft means work is still in progress, so a
delivery summary sent while the PR is a draft tells the user it's done when it can't
be merged yet. A failed check or a stale report is unfinished work: finish it, don't
deliver around it. Nothing waits for you: while CI is still running, schedule one
look with `CronCreate` (`recurring: false`) and end the turn — nothing else reports
a passing run, and you never wait in a loop. Tasks' PRs are looked at side by side, each
on its own schedule.

## Merge

Merging or asking for changes is the user's. A request for changes re-enters step 5,
and every question the user raises on the PR is fixed in that PR, along with every
other place that has the same problem. Told to merge one PR, squash-merge that PR
only, pinned to the head you checked (its sha), so a later push is not merged unchecked.
