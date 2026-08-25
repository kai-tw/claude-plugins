# Consistency rules — 維護慣例（review 子系統）

`Read` 本檔只在新增 / 修改 / 合併 / 刪除 consistency rule 時。

**這是什麼.** `consistency-reviewer` 的跨 feature 一致性規則庫，組織成**母規則
（一致性類別）+ sub-check** 兩層——母規則是一種「不一致」的形狀（第二真相源 /
機制檢查點分歧 / 能力重複實作）、sub-check 是該形狀下一個可逐項判定的具體檢查。
`consistency-reviewer` sub agent 對審查對象（**diff + engineering plan 的同儕
row + 同儕 feature 實作**）**逐母規則 → 逐 sub-check** 對照 `index.md` 旁觀審查
（player ≠ referee，禁實作者自審）。

**判定模式.** 與 security pack 相同的**三級判定**：
- **passed** — 該項一致（走 canonical home / 檢查點與同儕等價 / 走邊界 helper）。
- **warning** — 派生單點可控、差異有理由但未寫明、機制表缺表本身。回報但不阻擋。
- **critical** — 第二真相源可獨立變動、同儕檢查點無理由缺項、繞過 canonical entry
  point、`為何要新增` 的答案經覆核為假。阻擋。
逐項標級後，**所有 warning / critical 回報 engineer / 實作者修正，迴圈重審，直到
全 passed** 才放行。禁 deferred & dismiss。

**基線 vs 機制表.** 基線（`index.md`）只收換一個專案仍成立的通則；**哪些機制算
cross-cutting、canonical entry point 在哪、檢查點清單**是專案事實，放專案的
`.claude/rules/consistency.md` 機制表（格式見 `index.md` 開頭）。這與 privacy
pack 的分工同構——軸是通用的，事實表是專案的。沒有機制表時 C2 標無法判定並回報
建表為 warning，**不要**把無法判定寫成 passed。

**檔案格式.** 規則庫是單一檔案 `index.md`；一個一致性類別佔一節，不另立 detail
檔。Body：
- `## C<N> — <title>`
- `**Principle:**` 母規則通則 1–2 句（含與其他 gate 的分工），+ 一行判定模式提示。
- 每個 sub-check 一條 bullet ——
  `- **C<N>.k <名>** — Check: <一行判準（含分級條件）>. Example: <≤1 句>`。

**收斂原則（重要）.** rule 是通則的整理，不是 lessons 的照搬。新增前先問「這是不是
某個既有類別的特例？」是 → 掛成該母規則的 sub-check，不新增 sibling 母規則。母規則
數量 = 收斂後的不一致形狀數（目前 3：第二真相源 / 機制分歧 / 能力重複），不硬湊。

**learning 更新法.** 審查（或 founder 在 PR）發現新的不一致形狀：
1. **先查** `index.md` 是否已有相似類別 / sub-check。
2. **有 → 合併**（擴充 Check / Example / 分級條件，不新增檔 / 項）。
3. **無但屬某類別的新形狀 → 加一條 sub-check** 到該母規則。
4. **無且是全新形狀 → 新增一個 `## C<N+1>` 節**。
5. 復發 bug 的教訓優先落到**專案機制表的檢查點欄**（那是它復發的 feature 面），
   基線只收形狀。retro 量測列的「復發 bug」計數是這一步的觸發器。

> 不 append-only、不保永久編號——rule 以「當前一致、已收斂的 checklist」為目標，
> 歷史軌跡在 git。
