---
id: post-qa-review
kind: skill
summary: "QA 之後的殘留審查：conformance 殘餘 / 一致性 / 測試設計"
consumes:
  - spec-tests
produces:
  - residual-report
stop: "false"
skill: review
---
# Block: post-qa-review

> 進 `spec-tests` · 出 `residual-report`

dispatcher 在 `${CLAUDE_PLUGIN_ROOT}/skills/review/SKILL.md` §Post-QA 列。
本塊只講拼裝面。

## 為什麼一定排在 `qa` 之後

它的 conformance lens 是**殘餘的**：開場先 `ls test/spec/`，把已經被測試釘住的每一項
減掉——因為**一個永久會紅的測試強於一次 point-in-time verdict**。

排在 QA 之前跑，它就沒有東西可減，於是把整份 spec walk 重推一遍，而且重複掉它本來
被收窄去互補的那個 ratchet。**這個順序是載重的，不是偏好。**

## 拼裝注意

- 它需要的是 diff **加上** 核准過的計畫、計畫點名的 sibling、以及 `test/**` 的清單。
  缺這些它會拿不到能減的東西。
- report-only，跟 `code-review` 一樣的 verdict 協議。

## 驗收

三個 lens 都走過（conformance 殘餘 / 一致性 / 測試設計），逐項有 verdict。
