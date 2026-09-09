---
id: ship
kind: native
summary: "推 branch、開 PR、評測試強度（coverage / mutation）並貼上 PR"
consumes:
  - landed-commit
produces:
  - shipped-pr
stop: "false"
---
# Block: ship

> 輸入 `landed-commit`＝過了 commit gate 的 commit；輸出 `shipped-pr`＝開好的 PR
> ＋貼在上面的測試強度報告。
> **在 worktree 裡跑。** 這一塊結束後就停——其餘收尾等 merge（見 `close-out`）。

## 開 PR，然後評測試強度

0. **Open the PR (from the worktree).** Push the branch, then open the PR with a
heredoc body (never `--body` — embedded newlines and CJK mangle):

```bash
git push -u origin <branch>
gh pr create --base "$BASE" --title "<conventional-commit title>" --body-file - <<'EOF'
Fixes #<issue>

Implements <Notion task URL> (→ Product + Design + Engineering Plan rows)

## Plan-stage gates
| Gate | Verdict | Findings |
|---|---|---|
| pm-plan-reviewer | passed / n-a | 0 |
| engineer-plan-reviewer | passed | 2 critical resolved, 1 warning accepted |
| feasibility-reviewer | passed | 0 |
| design-plan-reviewer | n-a — no design phase | — |
EOF
```

The `Fixes #<issue>` line is what closes the cycle's GitHub issue (§Step 2) on
merge, and the Notion URL is the planning trail (Iron Law 4). Omit the `Fixes`
line only when the cycle genuinely has no issue.

**The gate table is one row per plan-stage gate, and `n-a` needs its reason.**
These four run before a PR exists, so a comment cannot carry them (the
diff-stage reviewers post their own — `review/SKILL.md §Posting findings to
the PR`). Without the table the founder is merging code whose plan-stage
verdicts are visible only inside a session that is about to end, and a gate
that was silently skipped looks exactly like one that passed. Report the
verdict and the finding counts, not the reports — those live in the Notion
rows.

**`Fixes` fires only on a MERGE into the DEFAULT branch.** With
`worktree.baseRef: head`, `$BASE` is whatever branch the session sat on — so a
worktree opened from a non-default base produces a PR whose `Fixes` line
silently never fires (GitHub shows "will close when merged into `<base>`", and
that merge never reaches `main`). Two cases need the issue closed by hand at
close-out: **`$BASE` is not the default branch**, and **the work landed without
a PR at all** (a local fast-forward). Check the issue's state before reporting
the cycle complete rather than assuming the keyword did it. `<branch>` is the name
read back in §Worktree isolation and `$BASE` is the base captured there
(satisfies Iron Law 4). **Committing and opening this PR do not need user
approval** — the worktree branch targets `$BASE` (`main`) as a review artifact
the user reviews + merges themselves, so fire `git push` + `gh pr create`
directly (no `AskUserQuestion` gate). Capture the returned PR number and
record it: `plan-cycle pr-opened <PR#> "$BASE"` — **run it from the worktree**,
which is where it reads the branch name that Step 6.6's teardown is verified
against (`pr-opened <PR#> <base> <branch>` if you must call it from elsewhere).

**Then grade the tests and post the report** — scoped the way the change is.
Coverage alone measures ~20 min (`bin/plan-coverage`) and mutation carries no
time bound at all (`mutation.sh` has no dry-count mode) — long enough to hit
the Bash tool's own cap if run as a blocking call. Run it with
`run_in_background: true` and wait for the completion notification
(`founder-corrections.md`'s harness-auto-notify rule — this is the main
thread, not a dispatched sub-agent, so it applies here); `Monitor` if you
want to watch it live:
```bash
plan-qa-report -- flutter test test/features/<feature>/
```
Coverage and mutation, one comment on the PR, and the `qa-green` mark that
stops the ledger's test-strength gate blocking turn-end. `/review` and lint
already ran because gates stop the turn without them; this is the gate for the
two that ask whether the tests are worth anything, and it is the reason
`pr-opened` is not the last thing this step does.

**Then stop — the rest of Step 6 waits for the merge.**

**The founder merges, not you** — Step 6.0 opens the PR and the full-suite
report (§After code) is already on it; pressing the button stays theirs.
