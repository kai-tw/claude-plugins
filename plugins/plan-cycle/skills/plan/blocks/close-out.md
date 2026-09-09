---
id: close-out
kind: skill
summary: "Feature Archive row ＋ trash task row ＋ 驗證兩者都落地"
consumes:
  - shipped-pr
produces:
  - feature-archive
stop: "false"
skill: archivist
---
# Block: close-out

> 輸入 `shipped-pr`＝已 merge 的 PR；輸出 `feature-archive`＝Feature Archive row URL
> ＋已驗證消失的 task row。
> **這一塊在 merge 之後才跑**，而且沒有它 cycle 就沒結束（Iron Law 7）。

## 為什麼等 merge

> **Steps 1–7 run AFTER the merge lands, not at PR-open.** Close-out archives
> what **shipped**; a Feature Archive row written for an unmerged PR describes
> work that may still be reworked or dropped, and trashing the task row that
> early leaves the rework with nothing to track. Nothing is lost by waiting: the
> Notion plan rows and the review reports posted on the PR (`review/SKILL.md`
> §Posting findings to the PR) hold the whole record until then.
>
> The close-out gate arms on the **merge**, not on the PR opening —
> `plan-cycle.sh check` watches for the squash commit's `(#N)` on
> `origin/$BASE`, so turn-end starts blocking only once there is genuinely
> something to close out — arming at PR-open instead blocks every turn-end
> across the founder-review window demanding work that cannot yet be done.
1. Invoke the `archivist` skill to create a **Feature Archive** row — a **synthesis**
   (problem / final approach / key decisions / outcome), **not** a verbatim dump.
1a. **Repoint the GitHub issue before the task is trashed.** Close-out deletes
   the Notion task, so the issue's `Implements <task URL>` link is about to die.
   Comment on the issue with the **Feature Archive row URL** — the durable record
   — then let the merge's `Fixes #N` close it (or close it by hand if the PR
   didn't carry the line). Skip when the cycle had no issue.
2. Have the archivist **trash the task row** — `ntn pages trash <id> --yes`
   (close-out **deletes** the task; its Status / Stage are irrelevant). `/plan`
   task bodies carry no `<!-- archivist-generated -->` marker, so the guarded

## 步驟

builder refuses — trash it by hand, after eyeballing it is the right cycle's task.
3. **Verify, don't assume.** Have the archivist **fetch the Feature Archive row
back** to confirm it exists, and **confirm the task row is gone** (the trash
landed) — don't trust the `✓`. Same fetch-back discipline the engineer
close-out uses. An unconfirmed archive does not count.
4. **Cite it in the closing report** — the `Close-out:` line must carry the
Feature Archive row URL + the **confirmed-trashed task row** + the
safe-to-delete list (see §Closing report); the `PR:` line carries the PR URL.
**No Close-out citation → the cycle is still open** (cite-or-it-didn't-happen,
per Iron Law 7).
4a. **Check for unblocked siblings.** If this task shares an **Area** with any
 `Deferred` sibling (`pm/SKILL.md` §Split into sibling tasks), invoke the
 `archivist` skill to check whether that sibling's **Trigger** names this
 task. If it does, say so in the closing report and propose promoting it
 to `Next` — don't leave a satisfied Trigger unnoticed on the board.
5. Report back to the user which local artifacts (if any) are now safe to delete
manually.
6. **Tear down the isolated checkout — merge-aware.** Check the PR's merge state
first (`gh pr view <PR#> --json state,mergeCommit`), then branch. **In a cloud
session there is no worktree**: every `ExitWorktree` below is instead
`git checkout $BASE` + `git branch -D <branch>` (only once merged), and the
remote-branch deletion is identical. The `clear` gate checks worktree and
branches separately, so it already accepts either shape.
- **Not yet merged** (close-out reached early — you got here without the
  gate, or the merge isn't visible on the local `origin/$BASE` yet):
  `ExitWorktree action: "keep"`. Commits are pushed; keep the branch +
  worktree for review follow-ups. Report the worktree path and note it will be
  removed once the PR merges. **Never auto-remove an unmerged worktree.**
- **Already merged** (the usual case — close-out follows the merge): the
  branch's work is safely on the base, so tear it down. First confirm the
  change actually landed on `origin/$BASE` (`state` is `MERGED` + a
  `mergeCommit`; spot-check a changed file on `origin/$BASE`), then
  `ExitWorktree action: "remove"` — this deletes the worktree **and its
  local branch** — and fast-forward local `$BASE` (`git fetch && git merge
  --ff-only origin/$BASE`) so the main tree reflects the merge. **Then delete
  the now-stale remote branch:** `git push origin --delete <branch>`.
  `ExitWorktree remove` only drops the *local* worktree branch; the pushed
  `origin/<branch>` survives the merge (a squash/rebase merge rewrites SHAs,
  and head-branch auto-delete is off on this repo), so without this it lingers
  as dead history. Removing a merged worktree **and deleting its remote
  branch** need no extra approval (the work is already on the base); the
  `ExitWorktree` requires `discard_changes: true` only because the
  squash/merge commit's SHA differs from the local branch commit — expected
  and safe once `MERGED` is confirmed.
- **`ExitWorktree` is session-scoped.** It acts only on a worktree created by
  `EnterWorktree` **in the current session** — for a worktree from a prior or
  ended session (the common "PR merged earlier, now tear it down" case) it is
  a **silent no-op**, not a success. Don't read that no-op as "done"; fall
  back to raw git: `git worktree remove <path> [--force]` then `git branch -D
  <branch>`. And if the remote branch is already gone (a per-PR delete button,
  or a prior teardown already ran `git push origin --delete`), that is
  "already done" — not an anomaly to chase.

On a merged cycle **`plan-cycle clear` checks all three against git** — the
worktree, the local branch, `origin/<branch>` — and refuses while any survives.
Clearing is the last moment anything asks: the ledger dies with it, so a
worktree left standing past this point is never mentioned again.
7. **File the runner-feedback entry** via the `feedback-ledger` skill — in the
**main tree**, after the worktree exit (never committed to a feature branch).
`--cycle` **must carry the cycle's ledger slug** (`plan-cycle.sh status`
shows it): `plan-cycle.sh clear` greps the entries for that slug and
**refuses** on a shipped (pr-opened) cycle until it exists, so a dropped 6.7
can't pass silently.

```bash
plan-feedback add process \
  --source runner --cycle <slug> --title "Cycle retro: <slug>" <<'BODY'
…gate R/H/L · 量測列（founder findings 分 reuse／一致性／其他 · --diff 對帳差異 · 復發 bug）· friction · the mandatory subtraction candidate…
BODY
```

The Stop hook handles the "time for a retro" reminder — don't add one to the
closing report.


(Close-out **trashes** the task row rather than setting a terminal Stage / Status —
those track live progress during the cycle, not its end. See `/archivist`.)
