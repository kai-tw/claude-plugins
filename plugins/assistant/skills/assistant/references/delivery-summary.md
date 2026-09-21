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

## 文字（②核可之後有無變動）
<n> 字串 · 核可於 ② · 此後語意有變者 <n>   (or 無字串改動)
### <key> · <算繪於何處> · <可用寬度>       (只列此後有變動者)
- <locale> <value>          (one line per locale, source first)
- ②核可之值：<value> → 變動：<一句> · 重新待核可

## 其他（自動驗證）
security passed · naming passed · coverage <n unexecuted lines, each named> · mutation <score>/80   (or `no coverage/mutation tool` from the adapter)
## Debt
- <one line each, task id>
```

**核可在 ② 給，本頁只問它還成不成立.** 語意自 ② 以來有變者，原核可失效（母法 U5.1：
語意改變者應改 key），**失效之語系不得合併亦不得提交**。未經 ② 就走到本頁的字串，是流程
破口，退回 ② 補件，不在本頁補簽。
