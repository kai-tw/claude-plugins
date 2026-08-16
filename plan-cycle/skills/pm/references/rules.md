# PM rules — drafting constraints

**Read this BEFORE drafting the PM plan.** Every entry constrains the writing,
and the writing is where honouring it costs a sentence.

**逐條走這張清單的是 `blueprint-reviewer` 的 checklist mode**，在 PM plan 撰寫後、給 user
看 OQ 前旁觀審查（**player ≠ referee，禁 PM 自審**）；任何違規當場修正、禁 deferred &
dismiss，迴圈至全 passed，上限 3 輪（見 SKILL.md Phase 6）。SKILL.md Phase 5 的自查是你自己先擋一輪，
**不是**它的替代品——規則你要懂，但審的人不能是你。

後果另有三處接住：**`feasibility-reviewer`**（對既有事物的斷言有沒有 grep 過〔P1.2〕、
universal rule 有沒有 inventory〔P2.2〕、機制交不交得出來〔P2.3／P4.2〕、最危險假設是不是
把工程難度冒充成不確定性〔P7.3〕）；**`ux-reviewer`**（P2.1／P2.4／P3.x／P4.1／P6 的後果會在
design spec 上顯形，含它橫切的 PM-scope adherence 檢查）；P1.1 的 baseline 還有
`plan/SKILL.md §Step 3` 在開 PM phase 前先擋一次。

本檔即完整規則集（母規則 + sub-check + Example 同檔），沒有另外的細節檔；維護慣例見 `../rules/CONVENTIONS.md`。

另有一組**跨 role 的計畫完整性規則**——`I1`（rev 改內文、不疊層）、`I3`（重點式、每行都承載
裁定或事實，答不出來就刪）、`I4`（決策註記寫在被裁定處，不另闢 section）與 `I2`（下游引用上游、不重推、
不把上游的例子當裁定）——定義在 `plan/SKILL.md §Plan integrity`，起草時一併適用。

## P1 — 依據可驗證、不捏造

**Principle:** plan 的依據（成功指標、決策 rationale）必須可驗證，不可憑「我以為」
捏造；沒有依據就標明「待測 / 需 owner 確認」，不要寫死一個假的數字或假的事實。

- **P1.1 數值目標需 baseline（GA4 追得到就用真數據接地）** — Check: 數值門檻有 baseline 或
  「measured at rev N」標註嗎？**當 outcome 是 GA4 追得到的指標（使用 / 採用 / 留存 / 事件）
  時，baseline 與問題規模用 `ga4.mjs`（`overview` / `events` / `report`）拉真數據接地**，而非
  留「待測」或只寫「founder 首次資料審定」；低量下標「方向性、非顯著」，數據接地、產品判斷仍主導。
  GA4 追不到的指標才回落 founder 資料審定。無 baseline 的精確 % / 時長 → 違規。
  Example: 「reading_session 30 天採用 ≥ 30% 使用者」→ 先 `ga4.mjs events` 拉現況（如 13 / 162
  使用者）當 baseline，否則是猜測 → 違規。
- **P1.2 引用既有 codebase shape 前須 grep 驗證** — Check: rationale 引用的既有命名 /
  shape / token / ARB key / lint rule 有在 save 前 grep / read 驗證（附 file:line /
  key）嗎？只有「我以為」→ 先驗證或標「PM 未驗證、需 owner 確認」。比較級論點
  （「更通用 / 更符合慣例」）沒列舉比較對象常是 marker。
  Example: 「『名稱』比『書名』更通用」沒 grep `lib/i18n/` → 其實已 ship「書名」→ 被迫 rev。

## P2 — 枚舉完整、不留白 / 不攤平

**Principle:** 當 plan 宣告一個涵蓋多情況的規則 / 動作 / 區域，必須**窮舉所有相關情況**
並各給明確 ruling 或呈現契約。不可攤平成單一、不可只列此刻記得的、不可留白給工程或
觀察期填補 —— 留白 = 未授權 = 下一個 amendment trigger。

- **P2.1 失敗模式須可區分** — Check: §Acceptance criteria 列舉的每個失敗模式，使用者需要
  不同的下一步嗎？系統需要不同的 log policy 嗎？任一是 → 欠顯式 distinguishability，
  括號清單不夠。
  Example: 「取消 / 權限 / 網路 / 其他」只要求「UI 不卡死」→ 折成單一 error bucket、把
  使用者取消當 error 記 Crashlytics → 違規。
- **P2.2 universal rule 須 codebase inventory** — Check: 「所有 X 都必須 Y」有對 codebase
  做 X 的系統性 inventory（可丟 sub-agent）並明列涵蓋 / 排除嗎？只列 owner 記得的個體
  → 先 inventory 再 save。
  Example: 「網路相關 UI 都須訂閱 connectivity」只列 7 個 dogfood 症狀，實際 30 個 surface。
- **P2.3 cloud-action 列全 online / offline 分支** — Check: online 成功 / online 失敗 /
  offline 成功(若適用) / offline 失敗 四 cell 都有明確 ruling 嗎？某 cell 答「照舊 /
  顯而易見」= 未授權；save 前用 matrix 列出每 cell 一句 ruling 或 cross-ref。
  Example: offline 釘很細、online success 留白 → 工程填「下載完自動 push 路由」。
- **P2.4 多來源頁面訂來源 + gap 呈現** — Check: 頁面靠多個 update timing 獨立的真實來源
  渲染時，每個區塊的基準來源 + 來源不一致 gap 期間呈現什麼，有寫死嗎？否則 gap 期自相
  矛盾（常 false-negative）。
  Example: loader 釋放與 auth-state 推送間 <1s gap 顯示「請登入」與真相相反。

## P3 — affordance 如承諾兌現

**Principle:** plan 承諾的 affordance 必須在使用者**實際抵達 / 操作的當下**真正可用且
如承諾 —— 不被 terminal 結果搶先、不在底層能力未就緒時假裝可點、不被單一預設偏離原本
對稱 / 側中立的承諾。

- **P3.1 terminal 不得搶在 override 之前** — Check: 產生 terminal（no-op / auto-dismiss
  / silent-success）的輸入可被另一 scope item override 嗎？可 → 使用者先抵達 override
  嗎？否 → 此狀態不算 terminal，介面須保持開啟、override 可見。
  Example: 偵測「已是目標語言」就 auto-dismiss，但 scope 保證可手動改語言 → 使用者改不到。
- **P3.2 action 須反映能力就緒** — Check: 此 action 要產出承諾結果需要什麼就緒
  （cold-load / async-init / 平台支援）？介面有反映，還是要點了才知不可用？後者 → 欠
  readiness gate（永久不可用 → disabled + a11y label，非 sheet-to-learn）。
  Example: Translate 按鈕在 ML Kit cold-load / iOS 不支援時仍可點開 sheet 才說不可用。
- **P3.3 對稱承諾不被單邊預設** — Check: plan 文字有辯護把對稱 / 側中立的 affordance
  預設導向某側嗎？沒有 → 三選一：plan 補上有依據的預設 / 介面兩側都可見 / 延後待證據。
  Example: 「可改來源或目標」只給一個 CTA 直開某 picker → 預先選了「哪側更常被誤設」而無證據。

## P4 — 等待邊界綁 user-perceived 事件

**Principle:** 任何鎖定 / loading / ceiling 的生命週期必須綁到一個明確的 **user-perceived
事件**；而且「使用者停止等待」與「work 結果終止」是**兩個**事件，不可合併 —— 合併會丟棄
ceiling 之後才完成的 late result。

- **P4.1 UI 鎖定生命週期綁 user-perceived 事件** — Check: 此 critical section / loading /
  阻擋 UI 的解除點對應哪個 user-perceived 事件（OAuth 完成 / 寫檔完成 / 首次全量同步完成 /
  某 pipeline 全跑完）？未寫進 §scope / §outcome → 工程會綁最長 internal step。
  Example: sign-in 鎖綁「首次全量同步」→ 18 本書帳號實測鎖 91.8 秒，應綁「OAuth + 偏好寫入」。
- **P4.2 ceiling ≠ result termination** — Check: loading ceiling 是「reader 停止等待」還是
  「work 結束」？work 可能在 ceiling 之後才完成（慢網路 / 慢 device）→ late result 怎麼
  抵達使用者（swap-in / 其他 channel），或**顯式 own「丟棄」**並確認可接受？
  Example: `.timeout(5s → sentinel)` 包整段 cover resolution → 7s 拿到 bytes 卻不顯示。

## P5 — 範圍 / 承諾顯式封閉

**Principle:** plan 的範圍與核心承諾必須**顯式封閉** —— 下游（設計 / 工程）不得偷加未
授權的 user-visible 行為，也不得用旁路（定時 / 背景 / GC）規避承諾。沒寫死封閉 = 留白 =
下游照「他覺得理所當然的延伸」填補。

- **P5.1 設計不得擴張產品範圍** — Check: 設計新增的 user-visible surface / state /
  affordance 在 plan §範圍 / §非目標 內嗎？發明新範圍 → 停、回 PM 核可後才繼續。
  Example: design spec 新增 plan 未提的錯誤狀態 / 選單 / affordance。
- **P5.2 永不靜默承諾須封死定時 / 背景自動** — Check: 核心承諾是「永不靜默 X」（永不悄悄
  覆寫 / 挑邊 / 丟棄）時，§非目標有**顯式**封死 time-based / background / 定時自動 X
  （aging / TTL / GC / N 天套預設）嗎？沒有 → 工程會以「清理 stale」名義加回計時器版 silent-X。
  list 成長只能 measure-only + designer 更好呈現，不可定時自動套預設。
  Example: 承諾「永不靜默挑邊」卻 ship `SyncConflictsAgingService`（>14 天自動套預設、無 undo）。
- **P5.3 使用者只調一個細節時，範圍預設就是那個細節** — Check: 使用者對既有項目調整**單一
  細節**時，plan §範圍是否預設收斂到那個細節（narrow reading = 預設）？把更大的重建擺成預設 /
  推薦選項、而非顯式標「非推薦」的旁註 → 違規（restate 期無中生有的範圍；與 P5.1 互補——那條抓
  下游設計擴張、本條抓 restate 期把單一調整吹大）。更大的範圍只能當非推薦的 aside 提。
  Example: 使用者「只想換 metadata syncing 的 icon 樣式」，卻被框成「全組 badge polish（建議）」
  為推薦首選 → 應收斂回單一 icon。

## P6 — 摩擦匹配後果與可逆性

**Principle:** 阻斷式摩擦（確認步驟 / 阻擋 gate / 每次重現的說明）是否合比例，由被 gate
的動作兩個性質決定：**還能不能進行、事後可不可逆**。
- 可進行且可逆 → 阻斷不合比例，改用 **recovery**（讓它發生、給 undo）；對低後果可逆動作
  上阻斷確認 = confirmation fatigue（稀釋真正危險確認的價值）。
- 無法安全進行 / 高後果 → 阻斷合比例，**門是真的鎖著**；每次重現顯式說明不是 nag，是誠實
  的系統狀態可見性，靜默（安靜改道 / 一次性後靜音）才是失敗。

**Check:** 被 gate 的動作能進行且可 undo 嗎？能 → 拿掉阻斷、給 recovery；不能 / 高後果
→ 每次顯式 + live state，禁靜默 / 一次性。

**Example:** 對「staged 刪除」（還沒真刪、可 redo）上阻斷確認 = 過度 → 改 undo；對「寫入
有未解衝突的書」（會 clobber 另一裝置）→ 每次顯式重現未解數量的 write-gate（鎖著的門）。

## P7 — 最危險假設命名 + 便宜驗證

**Principle:** 每個計畫命名其最危險的假設——impact × 不確定性最高的那個信念——並附一個
低成本的驗證方式；不可用「最難做的」代替「最沒把握的」。它與殘餘風險同住 §Product-level
risk，但**必為第一條且形態不同**：最危險假設帶驗證法，殘餘風險帶緩解方式。

- **P7.1 單一、具體、非可行性慣性，且據首位** — Check: §Product-level risk 的**第一條**是否
  指名單一「最危險假設」（`**最危險假設：**<信念> — 驗證法：<便宜驗證>`），而非一份泛用的
  風險/可行性清單？標準 app 的可行性通常是最低風險的一類（除非依賴未驗證的平台能力）——
  先問想要性（使用者會不會要）、存續性（撐不撐得住成本 / 商業模式）、可用性有沒有更沒把握
  的信念。攤平成清單（最危險假設與殘餘風險混為同一種條目、看不出哪條是它）、把它降到第二條
  之後、或直接跳去列可行性疑慮 → 違規。Example:「使用者會為離線閱讀多付一次性費用」比「這個
  同步機制做不做得出來」更該是最危險假設。
- **P7.2 驗證法便宜且先於重投資** — Check: 假設是否附一個低成本驗證法（訪談 5 位使用者 /
  假門頁面 / 小型 spike / 現有數據回查），而非直接跳去建完整功能？若計畫的 §Tasks 已經在驗
  證這個假設之前排了完整實作階段 → 違規，退回重排序或先做驗證。Example:「開一個 waitlist
  頁面觀察點擊率」而不是「先做完整功能再看數據」。
- **P7.3 沒有把「已知怎麼做」誤標成「最沒把握」** — Check: 若假設寫的其實是工程難度（可行
  性），而非使用者會不會要 / 商業能不能撐，標記為誤判，退回重寫。挑一個自己已經知道怎麼
  低風險驗證的可行性項目來填這格，是常見的迴避行為——用來檢查它。Example:「這個演算法效能
  夠不夠」通常不是最危險假設，除非整個產品的存續繫於它。
