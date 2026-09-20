# 交付摘要 — one screen, seven blocks, every line clickable

Built from the verifier reports; the founder reads this, not the diff and not the
reports. Anything a linter or a passed check already settled is one line.

```
# <Task> — <PR #n | r<rev> pending>   <project> · <sha | working copy>

## 邏輯
- <user scenario>: <entry file:line> → <decision point file:line> → <outcome>
## 資料串接
- <source file:line> → <transform file:line> → <sink file:line> · 可能為空/舊格式：<where>
## Code style
- <deviation file:line> · 接受理由：<the builder report's declined reason verbatim>   (lint-caught items never appear)
## 錯誤處理
| 失敗事件 | 接住於 | 使用者看到 | log |
## As built vs as decided
- <deviation from the brief's 系統設計 + reason> or 無偏離
## 測試
- <scenario> → <test file:line> · 缺：<scenario or failure event with no test> or 無

## 文字（本次新增或變更之字串）
<n> 字串 · 來源 <source locale> · 其餘 <locales> · 未核可 <n>   (or 無字串改動)
### <key> · <算繪於何處> · <可用寬度>
- <locale> <value>          (one line per locale, source first)
- 核可：待核可 | OK

## 其他（自動驗證）
security passed · naming passed · coverage <n unexecuted lines, each named> · mutation <score>/80   (or `no coverage/mutation tool` from the adapter)
## Debt
- <one line each, task id>
```

**未核可之語系，不得合併亦不得提交**——核可以語系為單位，由 founder 在本頁逐語系給。
對造成語意改變之修改，原核可失效（母法 U5.1：語意改變者應改 key）。
