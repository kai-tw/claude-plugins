# UX rules — 維護慣例（review 子系統）

`Read` 本檔只在新增 / 修改 / 合併 / 刪除 UX rule 時。

**這是什麼.** `ux-reviewer` 的 usability 規則庫，組織成**母規則（usability axis）+
sub-check** 兩層 —— 母規則是一個可用性面向（收斂並對映 Nielsen heuristics + cognitive
walkthrough，加上本專案 reading-first 的取向）、sub-check 是該軸下一個可逐項判定的具體
check。目標：一個 first-time 使用者能**看懂、完成、逃離**每個 flow，而不困惑、不卡死、不被
突襲。`ux-reviewer` sub agent 對審查對象（**drafted design spec 的每個 flow + 每個畫面
的四狀態**，core task 來自核准 product plan）**逐軸 → 逐 check** 對照 `index.md` 旁觀審查
（player ≠ referee，禁 designer 自審）。

**判定模式（與 security / privacy 相同的三級 + 迴圈）.** 每個 sub-check 三級判定：
- **passed** — 該畫面 / 狀態在此軸對首次使用者可用。
- **warning** — 摩擦 / 困惑的取捨（多餘步驟、層級略亂、術語不一致、i18n 破版風險）；浮到
  designer 階段 open questions 給 founder 權衡，可寫明理由接受，不硬擋。
- **critical** — 客觀可用性缺陷（任務無法完成、狀態無出口 / 死路、主要控制項隱形或不可及、
  破壞性動作無確認、動作無回饋、first-run 無指引）；阻擋。
逐項標級後，所有 critical（＋未接受的 warning）回報 designer 修正，迴圈重審，**直到全 passed
或 warning 經寫明理由接受** 才放行。

**與鄰居 reviewer 的界線（不重疊）.**
- `blueprint-reviewer`(checklist mode) 逐條查 spec 有沒有守 designer 規則；`ux-reviewer`
  問「就算全合規，使用者會不會困惑、有多嚴重」。designer 規則也折進本檔六軸，所以同一個
  缺陷會被問兩次不同的問題——「守了沒」與「多痛」——那不是重複，是兩種 finding。
- `conformance-reviewer` 查出貨 **code** 有沒有實作 approved spec（實作期）；`ux-reviewer`
  查 **spec 本身** 可不可用（設計期）。
- 視覺 / mockup 保真度是 founder 手動檢查，不在此。

**檔案格式.** 單一檔 `index.md`；一個 axis 是檔內一個 `## P<N>` 節，不再獨立成檔。節內：
- `## P<N> — <title>（heuristic 對應）`
- `**Principle:**` 母規則通則 1–2 句 + 一行三級判定提示。
- 每個 sub-check 一項 ——
  `**P<N>.k <name>** — Check: <一行判準（含合規條件 + 違規分級）>. Example: <≤1 句>`。

**收斂原則.** rule 是 usability 通則的整理，不是把 Nielsen 十條照搬。新增前先問「這是不是
某個既有 axis 的特例？」是 → 掛成該軸的一個 sub-check，不要新增 sibling 母規則。母規則 =
六軸（Task completability / Orientation & feedback / Error prevention & recovery /
Consistency & recognition / Reading-first minimalism）＋ 一條跨切面 meta，不硬湊。

**單一檔.** `index.md` 現在就是完整規則庫 —— index 與 detail 已合併成同一檔，不再是兩個
互相同步的檔案。新增 / 修改 / 合併 / 刪除時直接編輯對應的 `## P<N>` 節即可；不要為了分工
再拆出第二個檔案。

**learning 更新法.**
1. 先查 `index.md` 是否已有相似 axis / check。
2. 有 → 合併（擴充既有 check 的條件 / 分級，不新增項）。
3. 無但屬某 axis 的新面向 → 加一條 sub-check。
4. 無且是全新 usability 軸 → 在 `index.md` 新增一個 `## P<N+1>` 節（N = 目前最大；刪除的
   洞不回填）。
5. 過時 check（平台慣例 / M3 版本變更）可直接刪除該節內對應項目。

> Nielsen heuristics + cognitive walkthrough 在此當 *rubric*、非認證目標。rule 以「當前
> 一致的 usability checklist」為目標，歷史軌跡在 git。
