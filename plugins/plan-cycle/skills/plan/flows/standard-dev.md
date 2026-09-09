---
id: standard-dev
summary: "有 UI 的完整 code cycle：PM → 設計 → 工程 → 實作 → 審查 → QA → 殘留審查 → commit → 出貨 → 收尾 → retro"
inputs:
  - task-brief
nodes:
  - "triage: exempt-check"
  - "anchor: task-anchor"
  - "pm: pm-plan"
  - "design: design-spec"
  - "eng: engineering-plan"
  - "impl: implement"
  - "review: code-review"
  - "qa: qa"
  - "postqa: post-qa-review"
  - "gate: commit-gate"
  - "pr: ship"
  - "close: close-out"
  - "retro: retro"
edges:
  - "triage -> anchor"
  - "anchor -> pm"
  - "pm -> design"
  - "design -> eng"
  - "eng -> impl"
  - "impl -> review"
  - "review -> qa"
  - "qa -> postqa"
  - "postqa -> gate"
  - "gate -> pr"
  - "pr -> close"
  - "close -> retro"
---
# Flow: standard-dev（有 UI 的完整 cycle）

```
task-brief
  │
  ▼
[triage]──▶[anchor]──▶[pm]⛔──▶[design]⛔──▶[eng]⛔──▶[impl]
                                                        │
   ┌────────────────────────────────────────────────────┘
   ▼
[review]──▶[qa]──▶[postqa]──▶[gate]──▶[pr]──▶[close]──▶[retro]
```

## 節點備註

- **triage** 判豁免就到此為止——**豁免不是這條 flow 的一個節點，是不進 flow**。
- **pm / design / eng** 三個都是 ⛔ STOP：使用者核准前不得推進下游。三次核准對應
  三大原則（MECHANISM → PM、SCREEN → designer、CODE → engineer）。
- **design** 內含 translator（在 render 之前）。它**不是**獨立節點：copy → widgets →
  render 是同一塊內的迴圈，拆成節點會在 DAG 上成環，lint 會擋——那是 lint 說對了。
- **review → qa → postqa 的順序是載重的。** postqa 的 conformance lens 是*殘餘*的：
  它開場先減掉 `test/spec/` 已經釘住的每一項。在 QA 之前跑它就沒有東西可減。
- **gate** 之後才是 **pr**：commit 落地了才有東西可推。
- **retro** 每個 cycle 都跑，不是選配（強制交一個刪除候選）。

## 條件分支不在這裡

沒有 UI 的走 `code-only`。**兩條 flow，不是一條帶條件的 edge**——F3 才驗得動，而且
哪一條在跑看得出來。
