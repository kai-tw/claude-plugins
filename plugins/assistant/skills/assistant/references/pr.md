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
unfinished work: finish it, don't deliver around it.

- Exit 3: CI is still running, or it never ran (a draft whose checks all skipped is
  taken out of draft so CI runs, and is still not done). Start `asst-pr watch <slug>
  <worktree>` with `run_in_background: true` and end the turn; its exit wakes the
  session, and nothing else reports a passing run. One watch per PR; tasks' PRs are
  watched side by side. On 0 run `ready` again; on 3 (its 60-minute timeout) watch
  again; on 2 it couldn't watch (it needs the `cli/gh-webhook` gh extension), so
  schedule one `asst-pr checks` a few minutes out (`CronCreate`, `recurring: false`)
  instead. Never wait in a loop.
- Exit 2: no PR is possible here (no usable `gh`, no GitHub remote). The delivery
  summary carries that line as a `Needs you`, and the PR is the user's to open.

## Merge

Once `ready` exits 0, start `asst-pr watch <slug> <worktree> --merge` with
`run_in_background: true`. It exits when the PR merges or closes: 0 merged → step 8;
1 closed unmerged → tell the user; 3 (its 24-hour timeout) watch again; 2 it couldn't
watch, so step 8 waits for the user's word.

Merging or asking for changes is the user's. A request for changes re-enters step 5,
and every question the user raises on the PR is fixed in that PR, along with every
other place that has the same problem. Told to merge one PR, squash-merge that PR
only, pinned to the head you checked (`gh pr merge <n> --squash --match-head-commit
<sha>`).
