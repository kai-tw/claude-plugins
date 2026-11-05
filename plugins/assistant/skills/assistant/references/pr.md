# The task's PR — from ready to merged

Read at step 7, before the delivery summary. Git only; on svn the task ends in
`svn commit` (asked) after the delivery summary.

## Ready

Rewrite the PR's title and body from the delivery summary first (`gh pr edit`): the
draft's describe the plan, not what shipped.

A backend change an app relies on reaches production only after the app task that
calls it filed `device: passed`: the backend task's delivery summary names that app
task and quotes its `verify-device` first line, and until it reads `device: passed`
the merge (or, where the project config sets `base_branch:`, the release that carries
it) isn't offered.

Then run `asst-pr ready <slug> <worktree>` to take the PR out of draft. A draft means
work is still in progress, so a delivery summary sent while the PR is a draft tells
the user it's done when it can't be merged yet. Whatever `ready` refuses on is
unfinished work: finish it, don't deliver around it. Every `asst-pr` outcome ends with
a `next:` line; do what it says. Nothing waits for you: one not settled yet (CI still
running, the PR still open) names the look to schedule once with `CronCreate`
(`recurring: false`), and you end the turn — nothing else reports a passing run or a
merge, and you never wait in a loop. Tasks' PRs are looked at side by side, each
on its own schedule.

## Merge

Merging or asking for changes is the user's. A request for changes re-enters step 5,
and every question the user raises on the PR is fixed in that PR, along with every
other place that has the same problem. Told to merge one PR, squash-merge that PR
only, pinned to the head you checked (`gh pr merge <n> --squash --match-head-commit
<sha>`).
