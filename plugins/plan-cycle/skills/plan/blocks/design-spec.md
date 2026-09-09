---
id: design-spec
kind: skill
summary: "設計規格＋widgets＋renders，翻譯在 render 前跑完（⛔ 使用者核准）"
consumes:
  - product-plan
produces:
  - design-spec
stop: "true"
skill: designer
---
# Block: design-spec

> 進 `product-plan` · 出 `design-spec`（聯絡表 ＋ widgets（含合約）＋ ARB）
> · **⛔ STOP**：使用者核准前不得推進下游。

任務書在 `${CLAUDE_PLUGIN_ROOT}/skills/designer/SKILL.md`。本塊只講拼裝面。

## translator 在本塊內部，不是獨立節點

copy → widgets → render 是**同一塊內的迴圈**：翻譯在 render **之前**跑完，
所以 render 上看到的是真文案。拆成 DAG 節點會成環，`plan-flow lint` 會擋——
那是 lint 說對了。

為什麼 render 要真文案：假的 placeholder 正好蓋掉 render 存在的理由（會換行的 CJK、
會溢出的長 locale），而 founder 是**看著它在版面上**簽核文案，不是看一份字串清單。

`translator` 擁有整條 ARB 字串（key、`app_en.arb` 原文、四個譯本）；engineer 那邊
只接 ICU ＋ `gen-l10n` ＋ 呼叫點。

## 拼裝注意

- **這一塊是第一個寫 repo 檔案的節點**（它出 widgets），所以 **worktree 在它之前建**
  （`plan/worktree.md`）。
- 與 `pm-plan` 共用一輪（見那一塊）。
- ja / zh_Hant 要 founder 簽核——LLM 會編，MT 控不住敬語與 CJK 語域。

## 驗收

`design-lint` 全綠（腳本，對著出貨的 widgets 跑）＋ renders 已發成聯絡表（designer
Phase 7——⛔ 核准看的就是它）＋ Notion row 落地。
