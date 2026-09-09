---
id: code-review
kind: skill
summary: "code 階段審查：語意 / 架構 / lint 抓不到的，＋ sink 觸發的安全隱私"
consumes:
  - code-changes
produces:
  - review-report
stop: "false"
skill: review
---
# Block: code-review

> 進 `code-changes` · 出 `review-report`（逐 finding 有 verdict）

dispatcher 在 `${CLAUDE_PLUGIN_ROOT}/skills/review/SKILL.md`。本塊只講拼裝面。

## 這一節點是 audit matrix 的 code 那一列

`code-reviewer`（① 每次 code 改動都跑）＋ `security-privacy-reviewer`
（② **boundary-gated 在 diff 自己的 sink 訊號**上——純移除的 diff 整個跳過）。
兩者 trigger 與 tier 都不同，所以是兩次 spawn 而不是一個更大的 agent。

## 拼裝注意

- **這一塊不能改 code。** 它 report-only；哪些 finding 要動由 caller 裁。
- verdict 協議是 FIX / DISMISS-with-rationale / ESCALATE / DEFER，逐 finding。
- 每一趟都要貼到 PR 上，**零 finding 也要貼**——否則「沒跑」和「跑完沒事」
  從 PR 上長得一樣。

## 驗收

每個 finding 都有寫下來的 verdict；有 `critical` 就要有一次 re-review 確認乾淨。
