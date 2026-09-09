---
id: commit-gate
kind: skill
summary: "commit 前的各腳：codegen / lint / tests / 計畫對帳 / review / 裝置驗證"
consumes:
  - review-report
  - residual-report
produces:
  - landed-commit
stop: "false"
skill: commit-gate
---
# Block: commit-gate

> 進 `review-report` ＋ `residual-report` · 出 `landed-commit`

任務書在 `${CLAUDE_PLUGIN_ROOT}/skills/commit-gate/SKILL.md`——它是 commit 紀律的
**SSOT**，各腳的定義只在那裡。本塊只講拼裝面。

## 為什麼它 consumes 兩份報告

commit 的前提是**兩層審查都收斂了**：code 階段那一列（`review-report`）和 QA 之後
那一列（`residual-report`）。少一份就是在還沒被審完的 diff 上 commit。

## 拼裝注意

- 它是**每個 phase 都跑**（scoped 到那個 phase 的 diff），不是 cycle 結尾跑一次。
- 測試那一腳在契約階段有一個窄化版本（`plan-test-first`：只有 stub 紅才算過）。
- 它**落地 commit，不結束 cycle**——PR、Feature Archive、trash task 是後面三塊。

## 驗收

各腳全綠 ＋ `git diff --cached` 只有預期的檔案（進 index 的內容自己讀一次，
不要盲 commit）。
