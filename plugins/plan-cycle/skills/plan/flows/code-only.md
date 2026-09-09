---
id: code-only
summary: "沒有 user-visible surface 的 cycle：跳過設計與翻譯，其餘與 standard-dev 相同"
inputs:
  - task-brief
nodes:
  - "triage: exempt-check"
  - "anchor: task-anchor"
  - "pm: pm-plan"
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
  - "pm -> eng"
  - "eng -> impl"
  - "impl -> review"
  - "review -> qa"
  - "qa -> postqa"
  - "postqa -> gate"
  - "gate -> pr"
  - "pr -> close"
  - "close -> retro"
---
# Flow: code-only（無 UI 的 cycle）

```
task-brief ──▶[triage]──▶[anchor]──▶[pm]⛔──▶[eng]⛔──▶[impl]──▶[review]
                                                                    │
              [retro]◀──[close]◀──[pr]◀──[gate]◀──[postqa]◀──[qa]◀──┘
```

## 與 standard-dev 的唯一差別

少了 `design` 節點，所以 `eng` 直接吃 `pm` 的 `product-plan`。**engineer 那一階不會
因此變成選配**——非 UI 的工作跳過設計與翻譯，不跳過工程計畫。

`engineering-plan` block 的 `consumes` 只宣告 `product-plan`，正是為了讓這兩條 flow
都能滿足 F3；有 UI 時 `design-spec` 是 `eng` 的上游 ancestor，它的 produces 自然可用。
