# PR 摘要 — one screen, six blocks, every line clickable

Built from the verifier reports; the founder reads this, not the diff and not the
reports. Anything a linter or a passed check already settled is one line.

```
# <Task> — PR #<n>            <project> · <sha>

## 邏輯
- <user scenario>: <entry file:line> → <decision point file:line> → <outcome>
## 資料串接
- <source file:line> → <transform file:line> → <sink file:line> · 可能為空/舊格式：<where>
## Code style
- <deviation file:line> · 接受理由：<the review-dismiss line verbatim>   (lint-caught items never appear)
## 錯誤處理
| 失敗事件 | 接住於 | 使用者看到 | log |
## As built vs as decided
- <deviation from the brief's 系統設計 + reason> or 無偏離
## 測試
- <scenario> → <test file:line> · 缺：<scenario or failure event with no test> or 無

## 其他（自動驗證）
security passed · naming passed · coverage <n unexecuted lines, each named> · mutation <score>/80   (or `no coverage/mutation tool` from the adapter)
## Debt
- <one line each, task id>
```
