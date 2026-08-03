# PM rules — 維護慣例（per-role）

`Read` 本檔只在新增 / 修改 / 合併 / 刪除 PM rule 時。

**這是什麼.** PM role 的規則庫，組織成**母規則（principle）+ sub-check** 兩層 —— 母規則
是通則、sub-check 是可操作的具體判準。`blueprint-reviewer` 以 checklist mode 在 PM plan
**撰寫後、給 user 看 OQ 前**逐 principle → 逐 sub-check 對照 `../references/rules.md` 旁觀審查
（player ≠ referee，禁 PM 自審）；任何違規**當場修正、禁 deferred & dismiss**，迴圈至全 passed。
新增一條規則時要同時想清楚它**可被旁觀者查證**——查不動的那條不是規則，是偏好。

**檔案格式.** ruleset 是**單一檔案** `../references/rules.md`；一條母規則佔其中一節。節：
- `## P<N> — <title>`
- `**Principle:**` 母規則通則 1–2 句（正面、可檢查）。
- 每個 sub-check 一項 —— `**P<N>.k <子題>** — Check: <一行判準（含違規條件）>. Example: <≤1 句>`。
- 母規則本身就是單一可檢查原則時（如 P6），可省 sub-check 條列，直接 `**Check:**` + `**Example:**`。

**收斂原則（重要）.** rule 是**通則的整理**，不是 lessons 的照搬。新增前先問「這是不是某條
既有 principle 的特例？」是 → 掛成該 principle 的 sub-check，**不要**新增 sibling 母規則。
`.claude/rules/` 精神：先講通則、合併特例、避免長變體表。

**index 已併入 detail（重要）.** `../references/rules.md` 本身就是完整 ruleset —— 沒有
分離的 per-principle 檔案需要同步，**不要**再切出第二個檔案。新增 / 修改 / 合併 / 刪除
母規則或 sub-check 一律直接編輯本檔對應的 `## P<N>` 節。

**learning 更新法.** 審查中發現新 learning：
1. **先查** `../references/rules.md` 是否已有相似 principle / sub-check。
2. **有 → 合併**（擴充既有 principle 或某 sub-check 的 Check / Example，不新增檔 / 項）。
3. **無但屬某 principle 的新維度 → 加一條 sub-check** 到該母規則。
4. **無且是全新母原則 → 新增** `## P<N+1>` 一節（N = 目前最大；非新增檔案；刪除留下的洞不回填）。
5. 過時 / 被取代的 rule / sub-check **可刪**（就地刪掉該節或該條即可，沒有第二處要同步）。

> 不再 append-only、不保永久編號 —— rule 以「當前一致、已收斂的 checklist」為目標，
> 歷史軌跡在 git。
