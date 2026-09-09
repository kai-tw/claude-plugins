---
id: qa
kind: skill
summary: "spec 衍生測試（test/spec/**），把出貨流程釘在核准的計畫上"
consumes:
  - code-changes
produces:
  - spec-tests
stop: "false"
skill: qa
---
# Block: qa

> 進 `code-changes` · 出 `spec-tests`（`test/spec/**`）

任務書在 `${CLAUDE_PLUGIN_ROOT}/skills/qa/SKILL.md`。本塊只講拼裝面。

## 樹的分界是路徑，不是作者

`test/spec/**` 是本塊的，`test/**` 其餘全部是 engineer 的（contract-derived）。
**兩邊都不寫進對方的樹**（`testing.md` Rule 1）。

## 拼裝注意

- 它從**核准過的 product / design plan** 衍生測試，不是從 code 衍生——所以它需要
  stub 只是為了有東西可呼叫，這也是它排在介面存在之後、任何實作滿足它之前的理由。
- 它跑的是**改動的 blast radius**，不是整套；不 background 再輪詢。
- 沒有新可觀察行為的 phase 可以跳過它（決定在 `implement` 塊，撰寫時逐 phase 下）。

## 驗收

caller 讀 hand-back 的**兩件事**：tally ＋**它實際跑過的路徑清單**。路徑清單比改動
範圍窄（改簽名 / 改必填欄位是典型），就退回去加寬——scoped 的一跑會編譯綠、把
sibling 的破壞藏起來。
