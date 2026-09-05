# Privacy rules — 維護慣例（review 子系統）

`Read` 本檔只在新增 / 修改 / 合併 / 刪除 privacy rule 時。

**這是什麼.** `privacy-reviewer` 的 data-minimization 規則庫，組織成**母規則
（minimization axis）+ sub-check** 兩層 —— 母規則是一個 GDPR-mapped 最小化軸 / 一個跨
切面 meta 面向、sub-check 是該軸下一個可逐項判定的具體 check。目標：把離開裝置的
user-derived 資料壓到「達成已記錄 outcome 所需的最小」；拒絕「之後可能有用」的蒐集。
`privacy-reviewer` sub agent 對 **diff + 商店宣告**逐軸 → 逐 check 對照 `index.md`
旁觀審查（player ≠ referee，禁實作者自審）。**計畫不審**——每條 check 都錨在
collection-site `file:line` 或 log 樣板上；「該不該收」是計畫期的 PM 規則 `P8`。

**判定模式（與 security 相同的三級 + 迴圈）.** 每個 sub-check 三級判定：
- **passed** — 該 collection-site / 欄位在此軸已最小化 / 合規。
- **warning** — 「未告知」或「可降未降」的前瞻風險（attestation gap、可用更低識別度替代
  但未用、保留略長但低敏感）；回報但不阻擋。
- **critical** — 今日成立的最小化違反 / 高敏感外洩（sensitive PII egress、無 purpose、
  attestation 謊報、stable id 無揭露、PII 經 log 字串插值滲漏）；阻擋。
逐項標級後，所有 warning / critical 回報 PM / engineer / 實作者修正，迴圈重審，**直到所有
check = passed** 才放行。禁 deferred & dismiss。

**檔案格式.** 單一檔 `index.md`；一個 axis / meta 面向是檔內一個 `## P<N>` 節。節內：
- `## P<N> — <title>（GDPR 對應）`
- `**Principle:**` 母規則通則 1–2 句 + 一行三級判定提示。
- 每個 sub-check 一項 ——
  `**P<N>.k <name>** — Check: <一行判準（含合規條件 + 違規分級）>. Example: <≤1 句>`。
- 母規則含表（如 P4 Sensitivity tier ladder）時，表放該節。

**收斂原則.** rule 是 minimization 通則的整理，不是 rubric 條文的照搬。新增前先問「這是不是
某個既有 axis 的特例？」是 → 掛成該軸的一個 sub-check，不要新增 sibling 母規則。母規則 =
GDPR 五軸（Purpose / Necessity / Retention / Sensitivity / Attestation）+ 一條跨切面
meta，不硬湊。

**單一檔.** `index.md` 就是完整規則庫，沒有第二份需要同步的檔案。新增 / 修改 / 合併 /
刪除時直接編輯對應的 `## P<N>` 節即可；不要為了分工再拆出第二個檔案。

**learning 更新法.**
1. 先查 `index.md` 是否已有相似 axis / check。
2. 有 → 合併（擴充既有 check 的條件 / 分級，不新增項）。
3. 無但屬某 axis 的新面向 → 加一條 sub-check。
4. 無且是全新 minimization 軸 → 在 `index.md` 新增一個 `## P<N+1>` 節（N = 目前最大；
   刪除的洞不回填）。
5. 過時 check（平台 / 法規變更）可直接刪除該節內對應項目。

> GDPR 原則在此當 *rubric*、非合規認證目標（同 privacy-reviewer 既有立場）。rule 以
> 「當前一致的 minimization checklist」為目標，歷史軌跡在 git。
