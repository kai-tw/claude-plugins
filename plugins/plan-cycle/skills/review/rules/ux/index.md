# UX rules — usability heuristic checklist

`design-plan-reviewer` 對審查對象（**drafted design spec 的每個 flow + 每個畫面的四狀態**，配合
core task 來自核准的 product plan）**逐軸 → 逐 check** 對照本清單旁觀審查（player ≠
referee，禁 designer 自審）：每個 check 逐項判 **passed / warning / critical** → 所有
critical（＋未接受的 warning）回報 designer 修正 → 迴圈重審，**直到全 passed 或 warning
經寫明理由接受** 才放行。

方法 = **cognitive walkthrough 為主**（扮首次使用者走每個 flow，逐步問「知道要做什麼／
看得到怎麼做／知道做成了」）＋ **heuristic sweep**（P1–P6 掃每畫面）＋ 最後一次
**橫切檢查**（PM-scope adherence，見文末）。每個 finding 錨定
spec（component row／state／section）＋ 明列 failure scenario（具體的困惑一刻）。
本檔即完整規則集（母規則 + sub-check + Example 同檔），沒有另外的細節檔；維護慣例 + 三級判定見 `CONVENTIONS.md`。

**designer 規則就在這裡，沒有第二份。** designer 交付的是 widget，所以它的便宜 gate 是
`design-lint`（層邊界 + token，逐檔讀原始碼），判斷這一半全在本檔——而且你評的是
**渲染出來的畫面與 widget 原始碼**，不是一份描述畫面的文件。問法也不同：不是「守了沒」，
而是**使用者會不會因此困惑、有多嚴重**。

嚴重度：**critical** = 客觀可用性缺陷（任務無法完成、狀態無出口、主要控制項隱形／不可及、
破壞性動作無確認、動作無回饋）→ 迴圈修到好。**warning** = 摩擦／困惑的取捨 → 浮到 designer
階段 open questions 給 founder 權衡，可寫明理由接受。

## P1 — Task completability（cognitive walkthrough）

**Principle:** 首次使用者能不能真的完成這個 flow 存在的核心任務；每一步都要「知道要做什麼、
看得到怎麼做、知道做成了」。逐 check 判 passed / warning / critical、迴圈至全 passed（或
warning 經寫明理由接受）。

- **P1.1 flow 有明確目標** — Check: 每個 flow 對得上 product plan 的一個 outcome（使用者
  來這裡是為了完成什麼）？無明確目標的畫面 → warning（先釐清才能走查）。
  Example: 一個 settings 分頁堆了雜項但說不出使用者的任務。
- **P1.2 下一步看得見** — Check: 完成任務的主要控制項在畫面上可見，非藏在長按 / 隱藏選單 /
  未提示的手勢？看不見 → critical（使用者卡在此步）。
  Example: 唯一的「新增書籍」入口是空白處長按，畫面無任何提示。
- **P1.3 知道怎麼做** — Check: 控制項的標籤 / 圖示表達得出它的動作，非純 icon 靠猜？**而且
  表達的要是它真的會做的事** —— glyph family 暗示原地展開（`arrow_drop_down` / `expand_more`）
  卻其實跳頁、disabled 不說明為什麼（點了才知道「沒反應」，或開到一張只寫「此裝置不支援」的
  destination），都是視覺寫了不兌現的承諾。語意不明或承諾不符 → warning。
  Example: 一個裸 icon 按鈕，使用者猜不出點下去會發生什麼；chip 掛 `arrow_drop_down` 卻
  `context.push` 到全螢幕頁。
- **P1.4 動作有回饋** — Check: 每個動作後有明確回饋（成功 / 失敗 / 進行中），非靜默？靜默動作
  → critical（使用者不知道成功與否，重複操作）。
  Example: 點「同步」後畫面毫無變化，不知是否已觸發。
- **P1.5 無死路** — Check: flow 中每個畫面都能往前完成任務或明確退出，非走到某狀態就卡住？
  死路 → critical。
  Example: 匯入失敗後只剩一個無法離開的錯誤畫面。

## P2 — Orientation & feedback（visibility of system status）

**Principle:** 使用者隨時知道「我在哪、正在發生什麼、剛剛發生了什麼」；四狀態
（default / empty / loading / error）各自告知狀態並指出下一步。逐 check 判
passed / warning / critical、迴圈至全 passed。

- **P2.1 等待的視覺對得上真實狀態** — Check: loading 告知「正在載入」且不像卡死（progress /
  skeleton / spinner）？無表徵（畫面凍住看不出在動）→ warning。**而且那一格要是真的**：
  in-flight 視覺只在真的開始等待後才出現（便宜的同步 pre-flight 失敗時停在 idle，不閃一下
  loading 再報錯）、**結束綁一個具名的 user-perceived 事件**（不是「最長的 internal step 做完」）、
  只在 online 才 resolve 的區域要 spec 出**離線終態**（無 progress / 無 shimmer 的中性終點 +
  連線恢復的 reconcile 契約），不是永遠轉下去的 spinner。一頁多區域時**逐區域**寫死觀察哪個來源、
  以及來源不一致的 gap 窗口渲染什麼 —— 沒寫死，各區會挑最方便的源、真機上差 100ms–1s 就互相
  矛盾。說謊的等待視覺 → critical（使用者據此走錯下一步）。
  Example: 開啟內容時白畫面數秒無指示；離線點 Sign-in 先閃 loading 再彈錯；critical section 綁
  「首次全量 sync」實測鎖住超過一分鐘；只存在雲端的縮圖在離線下無限 shimmer。
- **P2.2 empty 有指引** — Check: empty 狀態解釋「為什麼空」＋ 指引「怎麼開始」，非只有空白 /
  一句「沒有資料」？空白無指引 → critical（first-run 迷路）。
  Example: 全新使用者開書櫃只見空白，不知道要去哪匯入第一本書。
- **P2.3 error 有出路，而且真的是 error** — Check: error 狀態白話說明問題 ＋ 提供出路（重試 /
  返回 / 換方式），非只有「發生錯誤」？死錯誤（只報錯不給路）→ critical。**反向也查**：使用者
  可在原地解決的狀態（語言對撞、篩選結果為空、預設不符當下意圖）不得穿 error 的形狀
  （error icon／errorContainer 色／指責文案／把承載面關掉）—— 那是把「你改一下就好」講成
  「壞了」。且**上游已區分的失敗類要各自可辨**：不同成因若導向不同的下一步，就不能折成同一句
  共用文案（文案命名成因、glyph 有無、該面本身的有無，三者至少動一個）。
  Example: 雲端同步失敗顯示「Error 500」且無重試鈕；把 recoverable 狀態 force-fit 進
  `*ErrorView`；cancel / offline / permission / unknown 共用同一個 `error_outline_rounded`。
- **P2.4 知道當前位置** — Check: 使用者隨時知道當前位置（標題 / 返回路徑清楚，深層 flow 不
  迷路）？迷路（多層 push 後不知在哪、怎麼回）→ warning。
  Example: 設定裡三層深的子頁都叫「設定」，回不到想去的層級。

## P3 — Error prevention & recovery（user control & freedom）

**Principle:** 破壞性 / 不可逆動作要有防呆；任何狀態都能返回 / 撤銷 / 逃離；錯誤要能被理解
並復原。逐 check 判 passed / warning / critical、迴圈至全 passed。

- **P3.1 破壞性動作防呆，且摩擦與後果相稱** — Check: 破壞性 / 不可逆動作（刪除、覆寫、登出清
  本機資料）前有確認對話或可撤銷（undo）？無防呆 → critical（一觸即失資料）。**相稱性兩邊都查**：
  還能進行且事後可逆的動作上阻斷確認 = confirmation fatigue，改用 recovery；無法安全進行或高後果
  的，門就是真的鎖著，每次顯式重現不是 nag。**一個控制只承載一個意圖**——`Switch` / toggle 讀作
  「記住我要什麼」（即時、可逆、純本地），不得同時觸發 OAuth / 付款 / 特權權限 / 外部呼叫；副作用
  自己有 affordance。**還有一種無聲的破壞**：某個資料類被**正常存取動作**寫入（開書就寫閱讀進度）
  時，靠 badge / banner 這種 passive discovery 來得太晚——存取當下已經靜默挑了一邊，要在入口
  active intercept。
  Example: 書籍列表項左滑直接刪除，無確認也無 undo；對「還沒真刪的 staged 刪除」上阻斷確認；
  sign-in toggle 把偏好寫綁 OAuth 成功；五個衝突資料類共用 passive trio，第五類開書就自動挑邊。
- **P3.2 每個狀態有出口** — Check: 每個畫面 / 狀態都有明確的返回 / 離開路徑，非把使用者困在
  某個 modal / 狀態？無出口 → critical（trap）。
  Example: 一個全螢幕提示只有主要按鈕，沒有關閉 / 返回。
- **P3.3 error 可理解** — Check: error 訊息說明「哪裡錯 ＋ 怎麼辦」的白話，非技術碼 / 籠統
  詞？籠統（「something went wrong」）→ warning。
  Example: 授權失敗顯示 raw exception 字串。
- **P3.4 防誤觸** — Check: 容易誤觸的操作有足夠間距 / 確認保護（主要動作與破壞性動作不相鄰
  誤點）？易誤觸 → warning。
  Example: 「儲存」與「刪除」並排且同尺寸、無視覺區隔。

## P4 — Consistency & recognition（don't make me think）

**Principle:** 沿用 app 既有 pattern / 共用元件 / 平台慣例，讓使用者辨識而非回想；互動
affordance 要能被發現。逐 check 判 passed / warning / critical、迴圈至全 passed。

- **P4.1 沿用既有 pattern，且不污染它** — Check: 做同一件事沿用既有共用元件 / M3 pattern，而非
  新造一套 UI？重造（同功能兩種樣子）→ warning（認知負擔）。**沿用時兩個方向都要查**：M3 元件
  進到非 canonical 的角色時，default token（elevation / fill / padding / color role）要**重評**，
  不能把元件當成單一形狀；而 feature-local 的差異要修在 outer container，**不得改共用 widget 的
  default** —— 那是把局部不一致擴散成全 codebase drift。
  Example: 這個畫面自訂一個 bottom sheet，但 app 別處同類選擇都用既有的 `ReaderBottomSheet`；
  把 entry-point `SearchBar` 的 3.0dp elevation 原封用作 in-page filter；為了補兩頁的 padding
  差異去改共用 row widget 的 `contentPadding`。
- **P4.2 要據以行動的東西，感知得到** — Check: 可點 / 可滑 / 可拖看得出來（有視覺暗示），非把
  隱形手勢當唯一入口？隱形唯一入口 → critical（發現不了就用不到）。**區別本身也要感知得到**：
  使用者要據以挑選 / 分辨的差異不得只靠**單一**通道（顏色 / hue / 形狀 / 位置 / 大小）——閱讀
  app 把 greyscale / e-ink 當一等顯示模式，純色編碼對**所有**人失效，不只色盲（WCAG 1.4.1）；
  補一個既有 ARB 已 localize 的文字 label 或 icon。清單可能含一種以上 KIND 時，每列要有 leading
  identity cue（封面縮圖 / kind icon / type chip），只靠 title 字串是 recognition-by-recall。
  Example: 唯一的分頁切換方式是左右滑，畫面上無 tab；「保留本機 vs 雲端」picker 只用色點，決策被
  縮成「分辨黃和綠」；同步衝突清單以 title 排 flat `ListTile`，看不出哪個是書、哪個是收藏。
- **P4.3 標籤 / 術語 / 載入詞彙一致** — Check: 標籤 / icon / 術語一致且不歧義（無同義不同詞、
  同詞不同義）？不一致 → warning。**loading 也是一種詞彙**：同 surface 的 sibling CTA 不得各用
  一種 loading 形狀（一個 token swap、一個 content replacement）而無理由——使用者只該學一種。
  Example: 同一功能一處叫「書庫」另一處叫「書櫃」；sign-in 用 spinner 換文案、sign-out 用內容替換。
- **P4.4 平台慣例與 OS-owned 表面** — Check: 遵守平台慣例（iOS 邊緣返回手勢、Android 系統返回、
  平台化 widget）？違反 → warning。**OS 擁有的東西 Flutter 蓋不住**：在帶 live DOM selection 的
  WebView 上開 modal 前要先清除 selection，否則 native selection handle（Android `PopupWindow`、
  iOS `UITextInteraction`）會蓋在 modal 上整段生命週期，z-order 無解 → critical。
  Example: iOS 頁面攔掉邊緣返回手勢卻沒給替代返回；reader 選字後開 bottom sheet，選取控點浮在上面。

## P5 — Reading-first minimalism（aesthetic & minimalist restraint）

**Principle:** 這是閱讀器，UI 要讓路；不對核心閱讀流程加多餘步驟 / chrome，畫面上每個元素
都要 earning its place。逐 check 判 passed / warning / critical、迴圈至全 passed。

- **P5.1 無多餘步驟** — Check: flow 沒有對核心任務加多餘步驟（能一步不要兩步、能就地不要
  跳頁）？多餘步驟 → warning。
  Example: 調字級要先開設定頁再進子頁，而非閱讀畫面就地調。
- **P5.2 視覺層級服務主任務** — Check: 主要動作突出、次要噪音抑制（層級服務使用者當下的
  任務）？層級混亂（次要按鈕搶過主要）→ warning。
  Example: 閱讀工具列把「分享」做得比「翻頁 / 目錄」還顯眼。
- **P5.3 無冗餘元素** — Check: 畫面無不 earning-its-place 的元素（純裝飾 chrome、重複顯示
  的資訊）？冗餘 → warning。
  Example: 同一書名在 header 與 body 各顯示一次、無資訊增益。
- **P5.4 不打斷閱讀，chrome 退讓** — Check: 閱讀中的沉浸不被非必要打斷（彈窗 / 提示 / badge /
  全螢幕 interstitial 不搶注意力）？打斷閱讀 → critical（違反 reading-first 核心）。**常駐的
  也算打斷**：壓在 body text 上的 bar / 飽和 accent / 高對比 overlay 若 `fixed` / `pinned` 而
  沒有 auto-hide 或 reader-mode gate，就是永久佔用讀者的視野。
  Example: 閱讀中途彈出「評分 app」對話框蓋住內文；持久 top bar 蓋在文字上，只能靠捲動躲。

## P6 — 跨切面 meta（每次 review 一次，非每 finding）

**Principle:** 一次性檢查影響整個 spec 的可用性面向（可達性、i18n、first-run、響應式），
不逐畫面重複。逐 check 判 passed / warning / critical、迴圈至全 passed。

- **P6.1 互動目標可達** — Check: 觸控目標夠大、最大斷點下主要動作單手可及（非只塞畫面角落 /
  頂端）？不可達 → warning（小螢幕主要動作構不到 → critical）。
  Example: 大手機直握時主要動作固定在最頂端，單手構不到。
- **P6.2 撐得住 i18n 文字膨脹，且截斷不吃掉承載資訊** — Check: 版面撐得住較長字串（de / ja 常比
  en 長 30–40%），不截斷 / 不破版（對得上四語現實：en / ja / zh_Hans / zh_Hant）？會破版 →
  warning。**套 `maxLines: 1 + ellipsis` 前先問切點**：templated label 的 load-bearing 值常在
  結尾（`"Auto ({lang})"`、`"Source: {name}"`），ellipsis 切掉的正好是使用者要看的那個字 →
  改版面讓它佔滿軸（跨 locale 最安全），不是重排 template（CJK 修飾語在前、英文在後，常不相容）。
  Example: 一個固定寬按鈕在 ja 下文字被截成「…」；`"自動（繁體中文）"` 截成 `"自動（繁…"`。
- **P6.3 first-run 有指引** — Check: 全新使用者（無內容、第一次開）有 onboarding /
  empty-state 指引知道怎麼開始，非丟到空畫面？無指引 → critical（meta 層一次確認，交叉
  P2.2 的逐畫面 empty 檢查）。
  Example: 首次啟動直接進空書櫃，無「從這裡匯入第一本書」的引導。
- **P6.4 響應式全斷點可用** — Check: 每個 WindowSize 斷點（compact / medium / expanded）
  的 flow 都可用，非只設計了單一寬度？漏斷點 → warning。
  Example: 只標了 compact 佈局，expanded（平板 / 桌面）下 flow 未定義。

## 橫切檢查 — PM-scope adherence（每次一定跑，不評等級）

拿著 cited 的 product plan 讀 spec，旗標三件事，**經 designer 階段的 open questions 路由回
PM role**，不自行改寫（player ≠ referee）：

- **spec 發明了 plan 沒授權的 user-visible 範圍** —— 新的 surface / state / affordance 不在
  §範圍 也不在 §非目標 裡。
- **spec 把上游的「例子」當成上游的「裁定」** —— §Proposed approach / §Acceptance criteria /
  §Success metric / §Non-goals / 決策註記是已授權、可當 ruling 引；§Product-level risk
  裡由「**例如**」「candidate」「could」引入的數字 / 閾值 / 排序**只是 input**。把後者寫成 binding
  的，常會跟 spec 自己的原則打架——那個矛盾就是 smoke。
- **plan 的「永不靜默 X」承諾被旁路** —— §非目標 沒封死 time-based / background / aging 的自動
  X，工程就會以「清理 stale」的名義把計時器版的 silent-X 加回來。

（工程機制不是這裡的事：spec body 若用 route push/pop、navigator-stack、state-field
reconciliation 這類抽象**自答**跨斷點機制問題，那是把未驗證的機制銀行成既定設計 —— 旗標它，
要求改記可觀察的設計行為並把機制 defer 給工程階段。）
