# Engineer rules — 維護慣例（per-role）

`Read` 本檔只在新增 / 修改 / 合併 / 刪除 engineer rule 時。

**這是什麼.** engineer role 的規則庫，組織成**母規則（principle）+ sub-check** 兩層 ——
母規則是通則、sub-check 是可操作的具體判準。它是**起草約束**：engineering plan 沒有
`rules-audit` 逐條走這張清單，判斷歸 Phase 8.5 的 `blueprint-reviewer`（維度 + 橫切檢查）、
機械比對歸 `../scripts/plan_lint.sh`。所以**新增一條規則時要同時回答它由誰把關** ——
折進哪個 blueprint 維度、或是不是一項 script 檢查；答不出來的那條，寫下去也不會有人執行。

**檔案格式.** 規則庫是單一檔案 `../references/rules.md`；一條母規則佔一節，不再另立
detail 檔 —— index 與 detail 已合一，不存在第二份需要同步的檔案。Body：
- `## P<N> — <title>`
- `**Principle:**` 母規則通則 1–2 句（正面、可檢查）。
- 每個 sub-check 一條 bullet ——
  `- **P<N>.k <子題>** — Check: <一行判準（含違規條件）>. Example: <≤1 句>`。
- 母規則本身就是單一可檢查原則時，可省分項，直接一條 `**Check:**` + `**Example:**`。

**收斂原則（重要）.** rule 是**通則的整理**，不是 lessons 的照搬。新增前先問「這是不是某條
既有 principle 的特例？」是 → 掛成該 principle 的 sub-check，**不要**新增 sibling 母規則。
`.claude/rules/` 精神：先講通則、合併特例、避免長變體表。engineer lessons 用 corrective
pattern（具體結構）作答，不像 PM lessons 用 probing question —— sub-check 的 Check 要點到那個
結構（per-key serial executor、`copyWith`、relocate 每個 guard），不只描述症狀。

**learning 更新法.** rule audit 或 plan 撰寫中發現新 learning：
1. **先查** `../references/rules.md` 是否已有相似 principle / sub-check。
2. **有 → 合併**（擴充既有 principle 或某 sub-check 的 Check / Example，不新增檔 / 項）。
3. **無但屬某 principle 的新維度 → 加一條 sub-check** 到該母規則。
4. **無且是全新母原則 → 新增一個 `## P<N+1>` 節**（N = 目前最大；刪除留下的洞不回填）。
5. 過時 / 被取代的 rule / sub-check **可刪**。

> 不再 append-only、不保永久編號 —— rule 以「當前一致、已收斂的 checklist」為目標，
> 歷史軌跡在 git。
