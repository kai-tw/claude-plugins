# Engineer rules — drafting constraints

**Read this BEFORE drafting the engineering plan.** Every entry constrains the
writing, and the writing is where honouring it costs a sentence.

**沒有 `rules-audit` 在審這份計畫。** 原本逐條走這張清單的那道 gate 已按性質拆開：
判斷全歸 `blueprint-reviewer`（P1.2 → 它的 PM-scope 橫切檢查；P3.2 → criterion 8；
P3.3／P3.5 → criterion 10 的「第二面」那條；P9.1 → criterion 9；P8.1 不再是獨立檢查，
計畫抵觸 `.claude/rules/` 一律算成發現它的那個維度的 weakness），機械比對全歸
`../scripts/plan_lint.sh`（點名的檔案在不在、§Conformance 每列有沒有 task、§-ref 通不通）。
所以在這裡略過的一條，不會有清單走查兜住——只可能被某個判斷它後果的人抓到。

另有兩條**跨 role 的計畫完整性規則**——`I1`（rev 改內文、不疊層）與 `I2`（下游引用上游、不重推）
——定義在 `plan/SKILL.md §Plan integrity`，起草時一併適用，由 `blueprint-reviewer` 的橫切檢查旗標。

本檔即完整規則集（母規則 + sub-check + Example 同檔），沒有另外的細節檔；維護慣例見 `../rules/CONVENTIONS.md`。

> **範圍**：本清單只留 **planning 維度**的規則——只有在「撰寫 plan」這件事上才能檢查的條目
> （PM-scope 授權、套件選型證據、框架內建接地）。**實作正確性**的規則（state-write、portal
> 重接、per-key 序列化、最小機制、儲存形狀、sync/async I/O、命名、錯誤處理等）已移到
> **`.claude/rules/`**（path-scoped，編輯對應程式時自動載入、由 code-reviewer 把關），不再於
> plan 期逐條重審。**惟計畫 artifact 本身（含 sketch 程式碼）不得抵觸 canonical rules——見 P8（planning 維度的非抵觸檢查，與「逐條重審實作」不同）。** 對照表：the project's state-management rule（state-write / collaborator seam）· `state.md`（state class / loading code）· `use-cases.md`（fan-in / stream use case）·
> `error-handling.md`（conclusive-only write / exhaustive arm / no-silent-failure）·
> `storage-shape.md`〔原 P4〕· `naming.md` · `architecture.md`（§Deleting a wrapper〔原 P1.1〕·
> §Before inventing a wrapper〔原 P3.1〕· §Minimal, Direct
> Mechanism〔原 P6〕）· `data.md §Per-Key Serialization`〔原 P2.4〕· `code-style.md §Async`〔原 P7〕· `presentation.md §11`〔原 P5〕。
> 母規則編號刪除後留洞、不回填（見 CONVENTIONS）：故 P1 只剩 P1.2、P3 有 P3.2–P3.5（P3.1 留洞不回填）；新增母規則 **P8**（計畫服從 canonical rules）、**P9**（design / product spec 覆蓋——反遺漏）。

## P1 — 重構不得靜默改動 PM 擁有的 user-facing 行為

**Principle:** 重構 / 合併 / 刪除程式結構（wrapper、use case、early-return、guard
arm、terminal value）時，**user-observable 行為跨層歸 PM 擁有**，工程不得藉重構偷改。
（內部結構性質的保全——刪 wrapper 要逐 guard 搬遷——已移至 code-time impl 規則
`.claude/rules/architecture.md §Deleting a wrapper — relocate every guard first`，原
P1.1 不再於此留洞；本條只留 **PM-scope** 這個 planning 維度——plan 期就要擋下「重構順手
改了使用者看得到的行為」。）

- **P1.2 重構不得靜默引入 PM 未授權的 user-facing 語意** — Check: engineering task 的描述
  含 user 可觀察的動詞（「進 reader」「auto-open」「自動 dismiss」「直接 push」「skip
  confirmation」）時，套 observable-phrase test（這句使用者觀察得到、還是只有開發者觀察得
  到？）並核對 cited PM plan §提議方法 / §scope / §matrix 有逐字或語意對應的承諾嗎？缺 →
  停、回 PM role amend，再對著修正後的 plan 寫 task。特別盯 **terminal collapse**：拿掉
  early-return / guard arm / no-op arm 把兩個語意不同的 user action 折成同一個 terminal
  value，而新 terminal 觸發了原本被其中一 arm 擋掉的 side effect（導航 / 寫檔 / 網路）→
  §Blocks 須顯式點出碰撞，要嘛保留兩個 terminal、要嘛引 PM 授權合併。
  Example: F-004 把 `downloadCloudOnly` 折進 `prepareTap` 回 `ready`，widget 的 `ready`
  arm 無條件 push `AppRoutes.toc` → 三本 cloud-only 書近同時點各疊一頁 TOC；PM one-pager
  從未承諾「點 cloud-only → 下載 → auto-open」→ 應停並回 PM 核可 auto-open 語意 + 並行點擊契約。

## P3 — 接觸面要接地：外部證據、框架內建優先

**Principle:** 引入外部相依或自管機制前要先接地。**外部**：套件能否兌現某 design
contract clause 要靠內部級證據（source 行 / doc 子節 / minimal-repro），不是 name
match / README headline。**框架 / 平台**：自造 state-tracking / 重繪 / 生命週期
orchestration 前，先確認框架或平台是否已內建該能力，用內建而非重造。**內部 code**：計畫對
既有內部 code 的每個 load-bearing 斷言（signature /「與 X 逐字一致」/ predicate 行為）須讀
source 後才寫（「和現行 X 一樣」是計畫最高風險的一句）；新增任何 field / entity / method /
wrapper 前先 grep 其 canonical home——blueprint 只在**選定的設計
空間內**評分、會背書過度建構、不會問「該不該存在」。（**內部** toolbox 接地——發明 wrapper 前
先列既有 DI / use-case——已移至 code-time impl 規則
`.claude/rules/architecture.md §Before inventing a wrapper — enumerate the existing
toolbox`，原 P3.1 不再於此留洞；本節的內部 dimension 是**驗證斷言 + canonical home**，與那條的
列 toolbox 不同。）沒接地的套件與自管機制都是「會綠的 coin flip」。

- **P3.2 套件選擇對 design contract 驗內部證據、非 README headline** — Check: §Blocks
  為滿足某非瑣碎 design contract clause 選了外部套件時，理由是 source-code 引用 /
  doc 子節 / minimal-repro 結果，還是套件名 / README headline / pubspec entry？後者 →
  違規。須 (1) 逐字點名套件要兌現的 contract clause（「每個 tile 從舊位置滑到新位置、絕不
  淡出淡入」非「支援 reorder 動畫」）、(2) 引兌現它的證據、(3) 列套件處理 vs 靜默丟棄的
  失敗模式（`onMoved` 有沒有？`5xx` AND `429` 都重試？直書 CFI path？）。這份探查有界、
  機械、可平行 → spawn Sonnet subagent 做（給套件名+版本 + 逐字 contract clause + 具體
  yes/no 問題），plan body 引回它的證據。
  Example: collection-viewer-sort-modes 憑「名稱含 reorderable list + animated」選
  `implicitly_animated_reorderable_list_2`，無 source 驗證；該套件 diff 只 emit
  `onInserted` / `onRemoved`、從不 `onMoved` → 產生 spec 明文禁止的淡出+淡入；一個
  subagent 在 plan 期讀 diff base class 找 `onMoved` path（~5 分鐘）本可在任何 production
  code 出貨前攔下。

- **P3.3 自造 state / 重繪 / orchestration 前，先確認框架或平台是否已內建該能力** — Check:
  計畫要自管一套 state-tracking、`emit`-驅動、或生命週期 orchestration 來達成某行為時，有先
  確認**框架 / 平台 / 引擎是否已內建提供該行為**嗎（證據同 P3.2：source 行 / doc 子節，不憑
  直覺）？已內建仍自造平行機制 → 違規（過度工程）。與
  `.claude/rules/architecture.md §Minimal, Direct Mechanism`（「別為 domain state 已編碼
  的事實加平行 marker」）互補：那條 code-time 規則抓重複的「資料 marker」，本條 plan-time
  抓重複的「機制」——自管機制常連帶一個 marker 去驅動它，兩條一起命中。
  Example: runtime 字體載入原擬 `AppState` registered-version map + `emit` + theme-rebuild
  驅動重繪——實則 `FontLoader.load` 自帶 `_sendFontChangeMessage` 觸發全域 re-layout，theme
  固定 family name 即可，整套自管重繪機制（含那個 map）撤除。

- **P3.4 計畫對既有內部 code 的 load-bearing 斷言，寫入前已讀 source** — Check: 計畫裡每個
  load-bearing 的**內部** code 斷言（method / API signature、「與現有 X 逐字一致 / verbatim
  preserves」、某 predicate 的行為）在寫入前都已讀過真實 source 嗎？「和現行 X 一樣」是計畫裡
  風險最高的一句（讀來像已驗證、實為假設）—— 未 grep / 未讀宣告就斷言 → 違規；改動某識別字時
  對 plan 全 body sweep 舊名。此為 P3.2 外部證據要求的**內部版**；與已移至 code-time 的「發明
  wrapper 前列 toolbox」〔原 P3.1〕不同——那條列既有、本條驗證對既有的斷言。
  Example: C2 plan 斷言 `parseLocale` 回傳 nullable `KnownLocale?` ＋ `.toLocale()`，實際
  signature 是 `Locale parseLocale(String)` 非 null —— 整條 null→fallback 契約落在不存在的 API
  上，耗掉半數 audit round-trip。

- **P3.5 計畫新增 field / entity / method / wrapper 前，先 grep canonical home** — Check:
  §Blocks / §Composition 每新增一個 field / entity / method / wrapper，有先 grep 該 datum /
  能力的既有 canonical home、並說明為何無法 reuse 嗎？「projected from / derived from /
  mirrors X」的措辭是 parallel-marker 的 tell —— 有 canonical source 卻另開第二面 → 違規
  （讀取應走 canonical source）。這道手檢是 **engineer 的責任、不是 gate 的**：
  blueprint 只在選定設計空間內評分、會一致背書「加得很漂亮」的過度建構、不問「該不該存在」。
  與 P3.3 互補（P3.3 抓重複機制，本條抓重複資料面）；code-time 對應
  `.claude/rules/architecture.md §Minimal, Direct Mechanism`。
  Example: plan 加 `Book.language`「projected from `BookMetadata.language`」通過兩道 gate，
  卻是同一 datum 的第二真相源（兩條讀路正規化不同 → 漂移）；BookMetadata 既已記錄 language，
  讀取應走它。

## P8 — 計畫服從 canonical `.claude/rules/`

**Principle:** 計畫（含其 Dart sketch 與所述機制）不得抵觸 `.claude/rules/` 任何規則；衝突一律以 `.claude/rules/` 為準（rule wins）。

- **P8.1 計畫 artifact 不抵觸 canonical rules** — Check: 落筆時比對計畫**可見內容**（§Blocks / §Blocks 的 class 名與程式碼、§Data flow / §Error handling 所述機制）vs 相關 `.claude/rules/`（naming · code-style · architecture · error-handling …），任一抵觸即以 rule 為準（`blueprint-reviewer` 在 consolidation 以 rule wins 收尾）。此非 plan 期「逐條重審實作」（那是 code-reviewer，見上方 §範圍）—— 而是審「計畫 artifact 本身」是否與 canonical rules 自相矛盾；sketch 程式碼只存在於計畫、會被實作者逐字抄走，其規則合規只在 plan 期可查。 Example: cloud_sync `EnsureMirrorCoverUseCase` 缺 feature 前綴（`naming.md`）→ `SyncEnsureMirrorCoverUseCase`；`cover?.bytes != null` 應用既有 `BookCover.hasSize`（`code-style.md` DRY）。

## P9 — design / product spec 覆蓋（反遺漏）

**Principle:** 計畫的 §Conformance 對照表必須**完整覆蓋** approved design spec 的每個可觀察項與 product plan 的每條承諾——每項對到 ≥1 列、每列對到 ≥1 §Tasks entry；漏一項即計畫不完整。

- **P9.1 §Conformance 覆蓋完整** — Check: 存檔前**反向**走一遍 design spec（component 矩陣有行為的格、四狀態、每個動效 / 轉場 / 互動）+ product plan（success metric / scope 承諾），逐項確認 §Conformance 有對應列、且該列對到 ≥1 §Tasks entry。任一可觀察 spec 項缺列、或列無對應 task → plan incomplete。（`plan_lint.sh` 驗「列有沒有 task」，`blueprint-reviewer` criterion 9 驗「spec 項有沒有列」——後者只有讀過上游的人做得到。）此為 planning 維度的反向覆蓋檢查，與 P8.1（不得抵觸 canonical rules）、Iron Law 8（source-from-spec 不得捏造）互補：那兩條防「加錯 / 抵觸」，本條防「漏做」。Example: design spec §動效 寫「遮罩 scale-in 600ms 出入場」但 §Conformance 無此列 → 補列 + 對到 presentation task；四狀態少了 empty → 補列。
