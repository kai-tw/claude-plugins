---
id: task-anchor
kind: skill
summary: "建 TaskList task ＋ GitHub issue，作為所有計畫的錨點"
consumes:
  - triage
produces:
  - task-anchor
stop: "false"
skill: archivist
---
# Block: task-anchor

> 輸入 `triage`＝非豁免的判級結果；輸出 `task-anchor`＝TaskList task URL
> ＋（會產生 PR 時）GitHub issue URL。
> 本塊沒有 Notion MCP —— **一切 Notion 寫入都經 `archivist` skill**。

## 一個 feature 一個錨點

Every feature's planning artifacts link to **one** anchor: its **TaskList
task**. `/plan` is the sole task-creator — this step runs once per feature,
and **once per sibling** when the PM phase splits a big ask into several
(`pm/SKILL.md` §Split into sibling tasks), never a second mechanism.

- **Task exists:** note its URL; carry it through the cycle. Leave its **Stage**
  untouched.
- **No task:** create it by **invoking the `archivist` skill** (this skill has
  no Notion MCP — `/archivist` is the Notion gateway). Tell it to add a TaskList row
  with a **Title Case** Name, a Status, the Area (a `lib/features/` folder name),
  and **Stage = "Product Plan"**. It returns the task URL.

## GitHub issue 在同一步開

**A cycle that will produce a PR gets a GitHub issue, created alongside the
task** — same predicate as the worktree (§Step 3: does this cycle write app
code?), so it is not a new judgment call. Plan-only cycles and `Tracing` rows
get none: with no PR there is nothing for it to anchor.

```bash
gh issue create --title "<the task's Name>" --body "<problem + Notion task URL>"
```

Then have the `archivist` set the task's **`GitHub Issue`** property to the
returned URL. If the work *started* from an existing issue (a user-filed report),
link that one instead of opening a second.

**The issue is a pointer, not a copy.** Its body carries the problem statement
and the Notion task link — never the plan. The plan lives in Notion and revs
there; a body that restates it becomes a second source of truth that drifts the
first time the plan changes (§Plan integrity `I2`, applied across systems).

**Who owns what:** Notion owns `Status` / `Stage` / `Area` / `Trigger` and the
three plan relations; the issue owns the git side — PR linkage, `Fixes #N`
auto-close, commit references. Neither mirrors the other's state.

DB ids / schema live only in `/archivist`'s `notion-kb.md`; reference the DBs and
the task **by name** — never hardcode a Notion id here.
