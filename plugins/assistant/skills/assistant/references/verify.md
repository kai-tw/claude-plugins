# Verify — step 6, and every fix round after it

Read once the integration's last slice, or an `exempt` task's edit, is committed, and again for each fix round.

## The checks, in parallel on the diff

- The code review: one `verifier`, report kind `verify-code`.
- The security checks: the `security-guidance` hooks, which run unattended, and the project's
  own sink rules, when it has them.
- Line coverage on the diff: every changed line executed, with no coverage-ignore comments.
  A project with no test framework has no coverage to run: skip it, say so in the delivery
  summary, never a finding or a fix round.
  Find the project's coverage command (CLAUDE.md, CI config, package scripts) and run it in the
  background, filing its output with `asst-report put <slug> verify-coverage --worktree <worktree>`.
  When the PR's CI measures it, run nothing, and read its log before the delivery summary.
- On-device tests, when the project has them: you run them the project's way, following `references/on-device.md`; a platform with
  no phone connected waits, named.

Mutation runs only in the PR's CI. A failed verify is reported as failed.

An `exempt` diff skips the code review: check it yourself — it changes only what the task
statement names, and stays a typo, a constant or a log — and pipe your verdict line, starting
`exempt:`, into `asst-report put <slug> verify-code --worktree <worktree>`; otherwise re-tier it
`small`. Every other `verify-*` report is the verifier's: you never write one yourself, whatever
the round.

## Posting to the PR

Post each filed `verify-*` report to the task's PR as a comment whose first line is
`assistant-report <slug> <kind>-<n> @ <short sha>`, then the full report on a private repo
(`PRIVATE` or `INTERNAL`); on any other, only "Filed, not posted: this repo is not known to be private."

## Fix rounds

Only a `fix` finding opens a fix round; a `list` finding, or a builder's `debt:` line, never
opens one alone (the builder may fix it in a round that is opening anyway). The builder applies
code fixes; a finding about a test goes to the tester. Every fix round — a CI-driven one
too (coverage gaps, mutation survivors) — goes back to the verifier for its own diff only (its
commit's; on svn, the round's `svn-<report kind>-<n>.diff` against the one saved before it), plus the
whole case table.

When the task had a fix round or merged its base, run `verify-code` once more before the PR goes ready, on the whole task's diff (`origin/<base>...HEAD`; on svn, plain `svn diff`, against BASE: the task never commits, so it holds the whole task and no upstream commit; saved like the round diffs), plus the whole case table.

A `low confidence` finding about the design rather than a single line, is never silently dropped: it goes on the delivery summary.

A finding comes back when a round meant to fix it is followed by a `fix` finding with the same file, same rule.
When one comes back, dispatch the `advisor` once, with the remaining `fix` findings, the fix rounds' diffs, the brief
and the task statement; one advisor per finding, never a second for the same finding. Its `advise` report goes into the
next builder's dispatch, which fixes as advised. When the round on its advice still leaves findings, they become one `Needs you` line with the advise report's path. A new `fix` finding from that round opens a fix round as usual.

A trade-off goes to the user now as a `Needs you`, never into another review round.

## Found outside the boundary

Anything found outside the task's boundary (SKILL.md §Boundaries) is never fixed here: create a
row for it at once (`Status=Backlog`, its body saying what was found and by which task); the next
message to the user names that row. When a check should have caught the defect earlier, the same
message proposes the process fix: which agent, rule or check to change, in one line.
