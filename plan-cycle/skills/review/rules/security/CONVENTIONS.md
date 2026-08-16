# Security rules — 維護慣例（review 子系統）

`Read` 本檔只在新增 / 修改 / 合併 / 刪除 security rule 時。

**這是什麼.** `security-reviewer` 的威脅模型規則庫，組織成**母規則（threat-model
category）+ threat sub-check** 兩層 —— 母規則是一個攻擊面 / STRIDE 類別、sub-check
是該類別下一個可逐項判定的具體 threat。目標 **OWASP MASVS L1**（消費級 reader app）；
拒絕 L2 resilience 要求當 security theater。`security-reviewer` sub agent 對審查對象
（**PM plan 的功能機制攻擊面 + engineer plan 的 threat model + code**）**逐母規則 →
逐 threat** 對照 `index.md` 旁觀審查（player ≠ referee，禁實作者自審）。

**判定模式（threat-model 特性，與 pm 不同處）.** 每個 threat sub-check 不是二元
passed/違規，而是**三級判定**：
- **passed** — 該 threat 目前已被防禦（隔離 / 校驗 / 上限 / 最小權限 / 揭露已就位）。
- **warning** — 前瞻性風險或低後果 gap（今日輸入不可利用、或同 sink 已有更大 hole、
  或屬「未告知」而非「未授權」）；回報但不阻擋。
- **critical** — 攻擊路徑今日成立、後果高（逃逸 / 永久 clobber / PII egress / 超範圍
  權限 / 注入）；阻擋。
逐 threat 標級後，**所有 warning / critical 回報 engineer / 實作者修正，迴圈重審，
直到所有 threat = passed** 才放行。禁 deferred & dismiss。

**檔案格式.** 規則庫是單一檔案 `index.md`；一個 threat-model category 佔一節，不
另立 detail 檔 —— 不存在第二份需要同步的檔案。Body：
- `## P<N> — <title>`
- `**Principle:**` 母規則通則 1–2 句（含該類別的 STRIDE 對應），+ 一行「逐 threat 判
  passed/warning/critical、迴圈至全 passed」的判定模式提示。
- 每個 threat 一條 bullet ——
  `- **P<N>.k <threat 名>**（← NNN）— Check: <一行判準（含已防禦條件 + 違規時
  的分級）>. Example: <≤1 句>`。
- 母規則只含單一 threat 時（如 P5 / P6），該 threat 一樣攤平成同一種 bullet：
  `- **P<N>.1 …** — Check: …` + `**Example:**`。
- 完整 CWE / MASVS / Detection-signal 原始推導見 **git 歷史**。

**收斂原則（重要）.** rule 是**通則的整理**，不是 lessons 的照搬。新增前先問「這是不是
某個既有 category 的特例 / 某個 STRIDE 類別下的新 threat？」是 → 掛成該母規則的一個
threat sub-check，**不要**新增 sibling 母規則。`.claude/rules/` 精神：先講通則、合併
特例、避免長變體表。母規則數量 = 收斂後的攻擊面類別數（目前 6：內容解析 / 身分憑證 /
資料保護隱私 / 雲端後端 / 平台入口 / 供應鏈），對齊 STRIDE × 攻擊面，不硬湊不照抄條數。

**learning 更新法.** 審查中發現新 threat / learning：
1. **先查** `index.md` 是否已有相似 category / threat。
2. **有 → 合併**（擴充既有母規則或某 threat 的 Check / Example / 分級條件，不新增
   檔 / 項）。
3. **無但屬某 category 的新 threat → 加一條 threat sub-check** 到該母規則。
4. **無且是全新攻擊面 → 新增一個 `## P<N+1>` 節**（N = 目前最大；刪除留下的洞不回填）。
5. 過時 / 被平台預設消除的 threat（如某 OS 版本後不再適用）**可刪**。

> 不 append-only、不保永久編號 —— rule 以「當前一致、已收斂的 threat-model
> checklist」為目標，歷史軌跡在 git。
