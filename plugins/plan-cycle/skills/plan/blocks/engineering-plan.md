---
id: engineering-plan
kind: skill
summary: "工程計畫：事實帳 / Classes / 資料流 / 遷移 / Conformance（⛔ 使用者核准）"
consumes:
  - product-plan
produces:
  - engineering-plan
stop: "true"
skill: engineer
---
# Block: engineering-plan

> 進 `product-plan`（有 UI 時 `design-spec` 是上游 ancestor）· 出 `engineering-plan`
> · **⛔ STOP**：使用者核准前不得寫第一行 code。

任務書在 `${CLAUDE_PLUGIN_ROOT}/skills/engineer/SKILL.md` Phases 1–10。
本塊只講拼裝面。

## 為什麼 `consumes` 只宣告 `product-plan`

`standard-dev` 和 `code-only` 兩條 flow 都要能滿足 F3。有 UI 時 `design-spec` 是
`eng` 節點的上游 ancestor，它的 produces 自然可用；沒有 UI 時這一塊照樣要跑——
**非 UI 的工作跳過設計與翻譯，不跳過工程計畫。**

## 拼裝注意

- 它跑**自己的一輪**（同樣三階段），因為它在 DAG 上位於 translator 下游，範圍取決於
  上游出了什麼。
- 缺上游產物就**停下來往上游路由**，不要自己編（Iron Law 1）。
- 核准是對**列舉出來的 task list** 核准，而且是 sticky 的：實作照那份清單跑，
  偏離就走 divergence。

## 驗收

`plan-lint <plan>` 無 HARD failure ＋ `engineer-plan-reviewer` 無 `critical`
＋ Notion row 落地且 fetch 得回來。
