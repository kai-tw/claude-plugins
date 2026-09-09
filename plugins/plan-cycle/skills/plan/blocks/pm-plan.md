---
id: pm-plan
kind: skill
summary: "產品計畫：問題 / 對象 / 成功指標 / 範圍 / 非目標（⛔ 使用者核准）"
consumes:
  - task-anchor
produces:
  - product-plan
stop: "true"
skill: pm
---
# Block: pm-plan

> 進 `task-anchor`（TaskList task URL）· 出 `product-plan`（核准過的 Product Plan row）
> · **⛔ STOP**：使用者核准前不得推進下游。

任務書在 `${CLAUDE_PLUGIN_ROOT}/skills/pm/SKILL.md`。本塊只講拼裝面。

## caller 要備齊的

- `task-anchor` —— 沒有 task 就沒有東西掛計畫，不要先寫再補。
- 使用數據基線（`exempt-check` 第 1 步已拉）——「該不該做」的任務缺它就是憑感覺。

## 拼裝注意

- **與 `design-spec` 共用一輪。** 兩份產物各自獨立（兩個 DB row、兩套規則），
  合併的是**輪次**：背對背草擬、一批 ① Sanity、**一次** Resolve、一次 ② Adversarial、
  一起 finalize。分開跑會讓第二輪的 battery 去審一份第一輪答案即將作廢的草稿。
- 非 UI 的 cycle 就沒有 designer 那半，這一輪退化成只有 PM 計畫。
- PM 把一個大需求拆成數個 sibling task 時，**每個 sibling 各跑一次 `task-anchor`**
  （`pm/SKILL.md` §Split into sibling tasks），不是另一套機制。

## 驗收

`product-plan` 落地 = Notion row 存在且 fetch 得回來（不信 `✓`），Stage 已推進。
核准是**使用者對列舉出來的內容**核准；「看起來不錯」不算。
