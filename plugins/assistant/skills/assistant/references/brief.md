# Decision brief — the one page the founder approves

Under 40 lines. Every line is a decision, never a description. Two marks:
`需要你` (intent: scope, a trade-off, product behaviour) · `自行裁定` (decided; listed
for veto, silence accepts). Once answered, each `需要你` line ends with `選 A`
(or B); the filed brief is the record, so a line without a choice is unfiled.
Write the template's labels verbatim — later steps find sections of the filed brief by them.

```
# <Task> — 決策簡報            <project> · <tier> · <date>

## 意圖
- 需要你  <the fork, one line> — A: <option> / B: <option> · 推薦 <A|B>：<why, one clause> · 選錯的代價：<one clause>
- 自行裁定 <the ruling, one line> · 理由：<one clause>

## 系統設計
```mermaid
flowchart LR   %% only cross-layer edges; new nodes marked (NEW)
```
- 歸屬：<each NEW thing — why new, which layer, who owns its state>
- 資料流與狀態：<source → sink; shared state: who writes, does order matter>
- 邊界：<persisted format / schema / API touched? old version behaviour> or 無
- 否決的替代：<one line + its cost>

## 畫面（UI in scope only）
- <screens × states the contact sheet will show>

## 預算與 debt
- review <0|1> · fix 2 · upload 2
- 已知 debt：<none, or one line each>
```
