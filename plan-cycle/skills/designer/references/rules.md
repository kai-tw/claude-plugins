# Designer rules — drafting constraints

**Read this BEFORE drafting the design spec.** Every entry constrains the
writing, and the writing is where honouring it costs a sentence.

**逐條走這張清單的是 `blueprint-reviewer` 的 checklist mode**，在 design spec 撰寫後、給
user 看 OQ 前旁觀審查（**player ≠ referee，禁 designer 自審**）；任何違規當場修正、禁
deferred & dismiss，迴圈至全 passed，上限 3 輪（見 SKILL.md Phase 8）。SKILL.md Phase 6 的自查是你自己
先擋一輪，**不是**它的替代品——規則你要懂，但審的人不能是你。

**這裡的每一條同時也活在 `ux-reviewer` 的六軸裡**（狀態忠實 → ux P2.1／P2.3；感知通道與
identity cue → ux P4.2；glyph 與 disabled 的承諾 → ux P1.3；共用元件污染與 M3 跨角色 →
ux P4.1；載入詞彙 → ux P4.3；ellipsis 吃掉承載字 → ux P6.2；一個控制一個意圖與
access-as-mutation → ux P3.1；chrome 退讓 → ux P5.4；native overlay → ux P4.4；
P8 的兩條 provenance → `plan/SKILL.md §Plan integrity` 的 `I2` ＋ ux 的橫切 PM-scope 檢查）。
兩道不是重複而是兩種問法：這裡問「守了沒」，那裡問「使用者會不會因此困惑、有多嚴重」。

本檔即完整規則集（母規則 + sub-check + Example 同檔），沒有另外的細節檔；維護慣例見 `../rules/CONVENTIONS.md`。

另有兩條**跨 role 的計畫完整性規則**——`I1`（rev 改內文、不疊層）與 `I2`（下游引用上游、不重推、
不把上游的例子當裁定）——定義在 `plan/SKILL.md §Plan integrity`，起草時一併適用。

## P1 — 視覺狀態忠實對映底層真實狀態

**Principle:** in-flight / loading / disabled / error 視覺是對「底層狀態機現在處於哪一格」
的承諾，必須與真實狀態一一對應。把可在原地解決的 notice 畫成 error、把同步 / 即將 fail 的
pre-flight 畫成 loading、把無止境的 offline 等待畫成 spinner、把「沒給原因的 disabled」當成
disabled —— 都是視覺對狀態說謊，使用者據此走錯下一步。

- **P1.1 notice ≠ error 形狀** — Check: 使用者可在原地解決的狀態（語言對撞、預設不符當下意圖、
  空篩選結果）有沒有被塞進 error-view family（同 `error_outline_rounded`、同 errorContainer 色、
  blocking 文案、snackbar-then-dismiss）？是 → 違規；notice 給中性 icon 色（`onSurfaceVariant`）、
  無 error 底、不指責文案、CTA 指向原地 override，且承載面 **維持開啟**。
  Example: 把 recoverable 狀態 force-fit 進 `*ErrorView`，或用 auto-dismiss snackbar 關掉使用者
  本要解決的那張 sheet。
- **P1.2 disabled 帶得知原因的訊號** — Check: 因 async readiness（cold-start probe、權限、平台能力）
  而 gate 的 tappable 控制，在 disabled 視窗有沒有視覺 / a11y 訊號？是不是讓使用者點了才知道「沒
  反應」或開到一張只寫「此裝置不支援」的 destination？transient（~1-2s）只需去飽和、**不上 spinner**；
  permanent disabled 需獨立 screen-reader label 說明限制。
  Example: 開一張全部內容只有「你想用的功能在此裝置不可用」的 sheet —— 那是 disabled 按鈕點前就該
  說的話。
- **P1.3 pre-flight 失敗不進 in-flight 視覺** — Check: 動作有便宜的同步 / 次感知 async pre-flight
  （連線檢查、權限 probe、格式驗證、flag gate）時，失敗路徑會不會閃一下 loading 再報錯？會 → 違規；
  in-flight 視覺**只在 pre-flight 通過後**啟動，pre-flight 失敗停在 idle、走 post-flight 同一個失敗
  channel。
  Example: 離線點 Sign-in 先進 button content-replacement loading 再彈 offline —— 使用者讀成
  flicker / 不穩；應 tap → 訊息出現、按鈕原位。
- **P1.4 in-flight 視覺的結束綁 user-perceived 事件** — Check: critical section / loading 的 start
  **與 end** 都綁到具名的 user-perceived 事件了嗎？還是用被動語（「loading 是為了等」「成功 → 解除」）
  讓工程把生命週期綁到「最長 internal step 完成」？被動 = 違規；post-event housekeeping（背景 sync、
  cache 暖機、修復掃描）非同步續跑、由專屬 status surface 觀察，**永不**靠延長 in-flight 視覺。
  Example: sign-in critical section 綁「OAuth result + 偏好寫完」（~3s），而非「首次全量 sync 完成」
  （實測 18-book 帳號鎖 91.8s）。
- **P1.5 網路相依區域有 offline-terminal 終態** — Check: 觀察「只在 online 才會 resolve 的來源」
  的區域，有沒有 spec **三**態（in-flight / loaded / offline-terminal），而非只有 loading+loaded？
  只有兩態 → loading 在離線下永不結束、讀成「卡住 / 壞掉」。offline-terminal 是有限狀態機的**終態**：
  無 progress / 無 shimmer / 無 skeleton，中性 token（`onSurfaceVariant` + `cloud_off_rounded`）+
  非指責短句，並訂 connectivity 恢復時自動 offline-terminal → in-flight 的 reconcile 契約。
  Example: cloud-only 書無本地封面在離線下無限 shimmer skeleton → 改 asset fallback；Cloud Space tile
  無限 spinner → 改 stale-cache + offline badge 或純 offline placeholder。

## P2 — 使用者須據以行動的區別，多通道且各自可辨

**Principle:** 當 spec 要使用者依某個區別行動（挑一個、分辨兩邊、讀懂狀態、認出 item 是哪種），
那個區別必須**各自可辨**且**至少兩個感知通道**承載。把多個 plan 已區分的失敗 / 種類折成單一視覺，
或只靠顏色 / 形狀 / 位置單一通道，使用者就少了挑對下一步所需的訊號 —— 而這類缺口在彩色螢幕上
肉眼 review 看不出來，只能靠原則攔。

- **P2.1 plan 區分的失敗類各給可辨視覺** — Check: 一個 feature 有多個 plan 已區分（不同 user intent、
  不同 recovery、不同 mental model）的失敗條件時，spec 有沒有給各自可辨的處置（文案命名成因 + glyph
  有無 + 該面本身的有無）？折成單一 SnackBar / dialog / banner 一句共用文案 = 違規；ARB key 數須等於
  失敗類數，一類一 key。
  Example: cancel / offline / permission / unknown 全部同一個 `error_outline_rounded` + 同文案 →
  拆成 cancel（靜默無 UI）、offline（`cloud_off_rounded`）、permission（`lock_outline_rounded` + 原因）、
  other（無 icon）。
- **P2.2 須行動的區別 ≥ 兩個感知通道** — Check: 使用者要據以行動的差異（挑一個、分辨兩邊、讀狀態）
  是不是只靠顏色 / hue / 形狀 / 位置 / 大小**單一**通道？是 → 違規（WCAG 1.4.1 正面式：顏色可強化、
  不可獨任）；補一個既有 ARB 已 localize 的文字 label 或 icon，**勿** mint 平行名集。閱讀 app 把
  greyscale / e-ink 當一等顯示模式 —— 純色編碼對**所有**使用者失效，不只色盲。
  Example: 「保留本機顏色 vs 雲端顏色」picker 只用色點 → 決策被縮成「分辨黃和綠」；改
  `swatch + highlightColor* 名`（🟡 黃色 / 🟢 綠色）。
- **P2.3 list-item 種類有自明 identity cue** — Check: list 可能含一種以上 KIND（書 vs 收藏、檔 vs
  資料夾）或使用者根本不確定內容時，每列有沒有 leading identity cue（封面縮圖 / kind icon / type chip）
  讓種類一眼可辨？只靠 title 字串 = recognition-by-recall = 違規；把「這裡只會有書」寫進 decision log
  **不**算修好 —— 表面仍無 cue，問題每次看到都復發（同質清單 cue 仍以消滅「這是什麼?」歧義站得住）。
  Example: 同步衝突清單以 title 排 flat `ListTile`，founder 三問「哪個是書、哪個是收藏?」→ 改
  rounded `Card`（r24，沿用 collection-list-item）+ 封面縮圖。

## P3 — 視覺語彙寫的承諾須與實際角色 / 行為相符

**Principle:** glyph / M3 元件 / chrome 都帶有 canonical 的角色與互動承諾；放進新角色時必須
重新評估，讓「視覺寫的承諾」與「實際行為 / 角色」一致。glyph 暗示在原地展開卻 route 到別頁、
M3 元件帶著 canonical 角色的 token 進到不同角色、chrome 在閱讀時搶版面 —— 都是視覺寫了一個
行為不兌現的承諾。

- **P3.1 glyph family 配合導航語意** — Check: 控制的 glyph 是否暗示「在此原地開 popup / 展開」
  （`arrow_drop_down` / `expand_more` / `unfold_more`），但 onPressed 其實是 `context.push` /
  開第二張 modal / 去全螢幕頁？是 → 違規；改用導航 family（`chevron_right_rounded` 去他面、
  `open_in_new_rounded` 離開此 context、ListTile trailing 用 `>` 去 detail），`arrow_drop_down`
  **只**在 tap 真的在控制位置開 popup 時用。
  Example: engine-reported option list（20 / 60 locales）大到必開 routed page 時，chip glyph **必須**
  是導航 family，否則第一個 feedback 就是「為什麼開頁、我以為是 dropdown」。
- **P3.2 M3 元件跨角色重評 default token** — Check: spec 在非 canonical M3 context 用 M3 元件時，
  有沒有重評 default token（elevation / fill / padding / color role）仍合用？把元件當單一形狀、不分角色
  = 違規。
  Example: 把 entry-point `SearchBar`（3.0dp elevation + `surfaceContainerHigh`）原封用作 in-page
  filter，多出一層 surface tier 與下方 list 競爭 → instance 上 override `elevation: 0.0`（保 pill
  shape + fill），**絕不**改 global theme。
- **P3.3 chrome 在閱讀時退讓** — Check: 在 body text 上常駐的 bar / 飽和 accent / 高對比 overlay，
  有沒有 auto-hide 或 reader-mode gate？`fixed` / `pinned` 蓋在 content region 上無 gate = 違規
  （Iron Law 6：typography 是產品，chrome 退讓）。
  Example: 持久 top bar 蓋在文字上 → 改 scroll / selection / reading-mode auto-hide，僅在明確意圖時
  再現。

## P4 — 共用元件 / 既有修法不污染、不毀資訊

**Principle:** 修 feature-local 的視覺問題時，改動範圍要落在正確的層、且不得引入新的資訊
遺失。把 feature-local 的 row-rhythm 差異改進共用 row widget 的 default = 把局部不一致擴散成
全 codebase drift；把標準 overflow 修法套到 load-bearing 結尾的 label = 修了版面 bug、換來
state opacity bug。

- **P4.1 feature-local 差異修在 outer container、不動共用 widget default** — Check: 兩個同 feature
  的 sibling surface 共用 row widget 卻 padding 不一致時，spec 有沒有先確認分歧在 outer container 層
  （`ListView.padding` / body `Padding`），而非提議改共用 row widget 的 `contentPadding`？提議 mutate
  `lib/app/widgets/` 下共用 widget 的 default 來補 feature-local rhythm = 違規。
  Example: 兩頁 `LocaleListTile` 內 token 都對、但 outer padding 不同 → 對齊那個 outer container
  到 canonical 面（通常是最近收過 symmetric-padding 修正的那面），共用 widget default 保持不動。
- **P4.2 layout idiom 不吃掉 load-bearing 資訊** — Check: 對某 label 套 `maxLines: 1 +
  TextOverflow.ellipsis` 前，有沒有問「在 worst-case 內容下 ellipsis 會切在哪、那個切點是不是
  load-bearing?」templated label 的 load-bearing 值在結尾（`"Auto ({lang})"`、`"Source: {name}"`）
  時 ellipsis 切掉的正是使用者要看的資訊 = 違規（且可能違反 plan scope 契約）。
  Example: 三選一 —— (a) 重組 layout 讓各 label 佔滿軸（跨 locale 安全，優先）；(b) 重排 template
  （**只**在所有目標 locale 文法相容時，CJK modifier-before-head vs 英文相反常使其不安全）；
  (c) 文字 marker 換相鄰 glyph（有 canonical glyph 才可行）。

## P5 — 一個控制 = 一個連貫意圖；載入詞彙一致

**Principle:** 單一控制的視覺 affordance 寫了一個意圖契約，實作不得偷渡第二個語意不同的動作；
同一 surface 的 sibling 控制必須共用同一套載入詞彙，讓使用者只學一種 loading 語言。

- **P5.1 偏好 toggle 不偷渡 consent / 副作用** — Check: 單一 `Switch` / toggle / checkbox 會不會
  同時做 (a) 寫本地偏好 AND (b) 觸發 OAuth / 付款 / 特權權限 / 外部系統呼叫？是 → 違規；toggle
  讀作「記住我要什麼」（即時、idempotent、可逆），不含 consent / network step。拆成兩個：偏好 toggle
  純本地即時可逆（無 async / spinner / dialog）；副作用放獨立 affordance（後續 Card 上的 `FilledButton` /
  status row CTA / setup step）。副作用失敗保留偏好 + 露出 recovery；反轉副作用（sign-out / revoke /
  取消訂閱）也各有自己的 affordance，不 piggy-back 在 toggle-off。
  Example: sign-in toggle 把偏好寫綁 OAuth 成功，cancel / 網路失敗時 toggle 狀態說謊或卡死 →
  「偏好 on、副作用未完成」是合法狀態、有自己的 card 組成。
- **P5.2 sibling CTA 載入詞彙一致** — Check: 同 feature 的 sibling CTA 是否各用不同 loading 形狀
  （一個 token swap、一個 content replacement）而無理由？action-only CTA（Sign in / Send / Confirm）
  是否用 token swap 產生「spinner + 文案」與 M3 calm-loading 競爭、並新增只為 in-flight label 的 ARB
  key？是 → 違規。action-only CTA 用 **content replacement**：保 outer footprint、內容換
  `Center(SizedBox(20×20, CircularProgressIndicator(strokeWidth: 2.0)))`，消滅 in-flight label（不新增
  ARB key）。token swap 只在 label 在 idle/loading 間真的改變含義時用，且須說明理由；**同 surface 不混用**。
  Example: sign-in CTA 與 sign-out 都採 content replacement、保 idle footprint，退掉
  `cloudSyncSettingsSigningIn` 這支只為 loading label 的 ARB key。

## P6 — 多區域 / 多來源渲染顯式協調 gap

**Principle:** 一頁由多個區域組成、各區域相依的觀察來源 update timing 會分歧時，spec 必須**逐區域**
寫死 (a) 該區觀察哪個來源、(b) 來源不一致的 gap 窗口（一源已 fire、相依源尚未 propagate）該區渲染
什麼。沒寫死，工程就各區挑最方便的源讀，real device 上來源差 100ms–1s，gap 窗口出現互相矛盾的渲染，
使用者讀成 glitch / flicker / 失敗重試。

**Check:** spec 是否逐區域填三格 —— (a) 觀察來源（設計抽象命名：「auth-state observer」「auto-sync
偏好 observer」「cloud-space-info observer」，**非** state holder / stream / class 名）；(b) loaded-state 渲染；
(c) gap-window 渲染（三選一：(i) **延續先前 in-flight 視覺**，當該區綁的 user-perceived「done」事件
晚於 lock-release；(ii) **顯示 loading**，當該區觀察的源自己正在 fetch；(iii) **保留先前穩定態**，
**只**在該態於 gap 期間確實正確時 —— 絕不用那個原本觸發 bug 的 false-negative 態）？缺任一格 = 違規；
Hand-off 須逐區列出 source + gap-render，工程不得各區挑方便的源。此 bug 常在某 rev 依 P1.4 收緊
critical-section / loading 生命週期後才浮現 —— 過長的舊生命週期把 convergence gap 藏住了。

**Example:** rev 4 把 page-leave critical section 收到「OAuth + prefs done」（~3s）後，露出 lock 釋放
與 auth-observer propagation 間 <1s gap：Account card 觀察（sign-in 進度 + auth-state observer），其
「登入中」延續 gap（綁的 done 事件「帳號在卡上可見」晚於 lock 退出）；Auto-sync / Cloud Space card 各
觀察自己的 observer、gap 期顯示 loading；該頁 lock 釋放後**永不**再渲染「請登入」CTA。

## P7 — reader 存取與生命週期語意特例顯式處理

**Principle:** 閱讀 app 的某些存取 / 生命週期語意與通用情況不同 —— WebView 上的 modal 會留下
OS-owned native overlay、「開書來讀」同時也是「寫入閱讀進度」。spec 必須對這些特例顯式處理，
不能套用對其他面成立的通用做法。

- **P7.1 reader 觸發的 modal 顯式清 native overlay** — Check: 在帶 live DOM selection 的 WebView 上
  開 modal / dialog / bottom sheet 時，spec 有沒有寫「modal 開啟**之前**清除 selection」這一步（不只
  on-dismiss 清）？沒有 = 違規 —— OS-owned selection handle（Android `PopupWindow`、iOS
  `UITextInteraction`）會蓋在 modal 上整個 lifetime，Flutter z-order 蓋不住。
  Example: reader-triggered modal 的 spec entry 在 open action 旁同列 pre-open cleanup step。
- **P7.2 access-as-mutation 資料類不靠 passive discovery** — Check: 用統一 passive discovery vehicle
  （badge / banner / snackbar / settings entry）服務多個參與「pending 狀態」（衝突 / 分歧 / review queue）
  的資料類時，有沒有逐類 audit **default 存取路徑**？其中一類若被**正常存取動作**寫入（閱讀進度被開書 /
  翻頁寫、draft-read 被檢視寫），passive vehicle 來得太晚、存取動作本身已靜默挑一邊 = 違規（牴觸
  「永不靜默 resolve」原則）。read-only 存取類 passive 足夠；access-as-mutation 類需在**存取入口**做
  active intercept：(a) block-then-ask（無 defensible 中性態時），或 (b) **defer-default-action + 提供
  選擇**（開在中性態、入口處 inline 解決 affordance、fallback 手勢產生短窗 undo）—— 閱讀 / 瀏覽 app
  優先 (b)。**強制性 per-class 而非 per-feature**；修法不是「再加一個 passive 面」也不是「靜默寫後才警告」。
  Example: 同一組 passive trio 套到五個衝突資料類，四類 read-only、第五類閱讀進度被開書 auto-position
  靜默挑邊 → 改成開書時開在 TOC（不 auto-position）、入口衝突卡給明確選擇、「點任一章」為 fallback
  產生 5 秒 undo、下次翻頁 invalidate undo。

## P8 — spec body 不得銀行未授權 / 未驗證的內容當作裁定

**Principle:** spec body 內每條 ruling 須可稽核 —— 要嘛 trace 到 PM 已授權的一行，要嘛帶 designer
自己的 justification。把上游 plan 的 candidate 例子當成已授權裁定、或把 designer 自己未驗證的工程
機制草圖銀行進 spec body，都讓未經授權 / 未驗證的內容與真實裁定在 body 裡同權，後來的 reader /
the engineer role / `/qa` 讀成既定 doctrine。共同失敗：body 裡 reads-as-settled 但從未被授權 / 驗證。

- **P8.1 上游 candidate ≠ 已授權裁定** — Check: 從 source PM plan 引用數字 / 預設 / 閾值 / 排序前，
  有沒有先定位引文所在 section 並分類？§Proposed approach / §Acceptance criteria / §Success metric /
  §Non-goals / §Decision history = **已授權、可當 ruling 引**；§Product-level risk / 由「**例如**」
  「for instance」「candidate」「could」引入的例子 = **未授權、只當 input**。把後者當前者 = 違規（且常與
  spec 自身的 universal principle 矛盾 —— 矛盾就是未授權 import 的 smoke）。引用後者時 spec 須 (a) 自己
  做設計判斷並以自己的聲音擁有裁定（引所服務的原則、命名捨棄的 trade-off），或 (b) escalate 回 the PM
  role 求明確裁定；(a) 為預設。
  Example: 從 plan §Product-level risk 的「**例如**進度差 < 5% 取最新」import 成 binding 閾值，卻與
  spec 自己的「永不靜默挑邊」矛盾 → 移除閾值，把任何 micro-conflict noise filter 路由給 the engineer
  role（algorithm 層 HLC / tombstone），非 designer 的 UX-層 magnitude 閾值。
- **P8.2 工程機制不在 spec body 自答 co-create 問題** — Check: co-create 時 founder 問跨 breakpoint /
  resize / rotate 的**機制**（route-vs-state、push-vs-body-swap、stack 如何 reconcile），spec 有沒有用
  工程抽象（route push/pop、navigator-stack mutation、「declarative rebuild from state」、state-field
  reconciliation、具名 route / state 欄位）在 body 自答？是 → 違規（牴觸 Iron Law 7，且銀行未驗證機制
  當既定設計決策；imperative `push` 對本質 declarative 的 width 重決 pane 數常落在 anti-pattern）。只記
  **可觀察的設計行為**（選取跨 resize 保留、back 回 list、compact 單窗 expanded+ 雙窗），把機制問題在
  §Decision history 記一項顯式 deferral（裁示＝「路由給 engineering plan / pre-impl gate 決定」，
  含 owner + trigger），而非在 body 自答。
  Example: 用 go_router「selectedBookId + 寬度重建堆疊（push detail 變寬、變窄重 push）」回答「compact
  push detail 怎轉 expanded 雙窗格?」→ pre-E gate 證實 mixed-route 是 anti-pattern（imperative push 無法
  declarative un-push、occlude 雙窗）；正解是 single-route selection-as-state，spec 只該記設計行為。
