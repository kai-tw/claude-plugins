// Engineering Plan body section definitions.
// SSOT for section structure, authoring guidance, and blueprint-reviewer routing.
//
// A GUIDED QUESTIONNAIRE, not a prose template. Each section asks questions whose
// answers are checkable by someone who did not write the plan; a cell an outsider
// cannot verify is a preference, not a plan. Two shapes carry almost everything:
//   §Classes    — what we are building, class by class, method by method.
//   §Data flow  — how it runs, as a typed graph whose node names must match above.
// The rest exist because they catch what those two structurally cannot:
//   §Conformance — what was PROMISED. A missed requirement produces no class and
//                  no graph node, so absence is invisible to a structure indexed
//                  by presence. This is the only reverse walk.
//   §Startup     — what is never CONSTRUCTED, and what must be ready before what.
//                  A missing edge is not drawn; ordering is not a call.
//   §Error policy — the cross-class rulings (retry doctrine, races). A race lives
//                  BETWEEN classes, so it belongs to no class block.
//
// Order matters — it is dependency order for the author: name the classes before
// drawing the graph, draw the graph before deriving the races from it.
//
// Each section:
//   key         — the ## heading text emitted in the Notion body
//   aliases     — translated heading forms (headings are written in 繁體中文 per
//                 the authoring skill's §Language); `sections` ORs them into the
//                 regex that plan_lint.sh matches. Nothing outside this file
//                 keeps its own copy of that list.
//   kind        — para | bullets | table | checklist | raw
//   required    — ADVISORY on this DB (freeformBody): drives `hints`, does not
//                 gate create/update. Any `## heading` is legal.
//   criteria    — blueprint-reviewer dimension keys (c1–c12) this section earns
//   description — one-line description of what this section IS
//   hint        — authoring guidance for the LLM filling this section
//   template    — the literal skeleton `notion-payload template` emits; omit to
//                 fall back to the generic stub for `kind`
//
// Standards live in .claude/rules/ (implementation constraints) + references/sop/
// (design procedure); the plan cites them, never restates them. The plan's job is
// 串連 — which classes + how they wire + feature-specific instantiation.
//
// Commands:
//   notion-payload hints     engineering-plan   → the questions + 禁-lists
//   notion-payload template  engineering-plan   → the skeleton to fill
//   notion-payload criteria  engineering-plan   → criteria routing table
export const body = [
  {
    key: 'Summary',
    aliases: ['摘要', '總結'],
    kind: 'para',
    required: true,
    criteria: [],
    description: '2–4 行：在組什麼、選了哪個形狀',
    hint: '2–4 行，工程讀者的 30 秒定位：這個 plan 在組什麼、選了哪個形狀。\n**上游連結不寫在 body**——`Task` relation 屬性已經指向該 feature 的 tasklist row，Product / Design Plan 都掛在同一個 Task 上。在 body 再貼一次 URL 是第三份副本，rev 或重新連結時會腐爛（`I2`）。\n這是 brainstorming 的**產物**，不是過程——被否決的方案不寫在這裡（`I3`）；「為什麼不是 X」只有在它讓裁示變得可讀時，才進那一則 `〔自行裁定〕` 註記（`I4`）。\n不要重抄 product plan 的問題敘述（那是 PM 的，`I2`）。',
    template: '<在組什麼 + 為什麼，1–2 句>\n<選了哪個形狀，1 句>',
  },
  {
    key: 'Classes',
    aliases: ['類別', '類別清單'],
    kind: 'raw',
    required: true,
    criteria: ['c1', 'c2', 'c4', 'c5', 'c6', 'c8', 'c9', 'c10'],
    description: '總表（一列一個 class）+ 每個 class 一個 ### 區塊，內含公開 method 契約表',
    hint: '**先一張總表**，依 data → domain → presentation 排序（依賴方向；填到 presentation 時前面的名字已經存在可直接引用）：\n| Class | Layer | Kind | File (NEW/MOD/DEL) | 職責（一句） | 持有狀態（含上限 / eviction） | 為何要新增 |\nKind 用固定字彙：entity · DTO · repository · service · use case · cubit · widget · exception。固定字彙才查得動。\n`File` 欄寫**真實路徑**加標記——`plan_lint` 會去 repo 查：標 (MOD)/(DEL) 卻不存在的檔案，就是「跟現有的 X 一樣」這句話已經是假的；標 (NEW) 卻已存在的，是初稿寫錯（實作中途則屬正常）。\n\n**`為何要新增` 每個 NEW 列必填**（MOD 列寫 `—`）。這一欄是「該不該存在」的唯一落點：`blueprint-reviewer` 只在你劃定的設計空間內評分，會一致地背書「加得很漂亮」的過度建構，**不問這東西該不該存在**——所以這是起草者的責任，不是 gate 的。三種答案擇一或並列：\n- `框架/平台：<查過什麼 → 結論>`。要自管一套 state-tracking / `emit` 驅動 / 生命週期 orchestration 之前，先確認框架、平台或引擎有沒有內建（證據是 source 行或 doc 子節，不憑直覺）。已內建仍自造平行機制 = 過度工程。（實例：runtime 字體載入原擬 `AppState` 版本 map + `emit` + theme-rebuild 驅動重繪，實則 `FontLoader.load` 自帶 `_sendFontChangeMessage` 觸發全域 re-layout，整套自管機制連同那個 map 都撤除。）\n- `canonical home：grep <什麼> → 無既有擁有者`。新增 field / entity / method / wrapper 前先 grep 該 datum 或能力的既有 canonical home，並說明為何 reuse 不了。**「projected from / derived from / mirrors X」這種措辭就是第二真相源的 tell**——有 canonical source 卻另開第二面，讀取應走 canonical source。（實例：`Book.language`「projected from `BookMetadata.language`」通過兩道 gate，卻是同一 datum 的兩條讀路、正規化不同 → 漂移。）\n- `套件 <名>@<版>：<逐字的 contract clause> → <source 引用>`。選外部套件滿足某非瑣碎 design contract clause 時，理由要是 source-code 引用 / doc 子節 / minimal-repro，**不是套件名或 README headline**。clause 要逐字（「每個 tile 從舊位置滑到新位置、絕不淡出淡入」而非「支援 reorder 動畫」），並列出套件處理 vs 靜默丟棄的失敗模式。這份查證交給 `package-explorer`，plan body 引回它的證據。\n`持有狀態` 是空間複雜度的 class 那一半——沒有上限的 Map / 沒有 eviction 的 cache 在這一欄現形；不持有狀態就寫 `—`。\n\n**範圍（不收斂會爆）**：只列這份計畫**新增或修改**的 class（NEW / MOD）。既有不動的 class 只以「被呼叫方」出現在 `呼叫` 欄，不佔自己的列。既有方法不夠、需要調整 → 那個既有 class 就變成 MOD，回總表補一列。無變動的 layer 在表外一行寫 `<layer>: no change`。\n\n**再每個 class 一個 `### <Class>` 區塊**，內含一張公開 method 契約表。只列**跨出 class 邊界**的公開 method；private helper 是實作，歸 SOP。\n**ctor 也佔一列**，`簽名` 欄列出它的 collaborators——那就是 test seam，criterion 9 靠它評分（`.claude/rules/testing.md` 禁 `Mock implements` listenable，seam 要是 two-callback 或窄介面，不是帶 `Stream` / `ChangeNotifier` 的具體類）。\n| method | 簽名 | 職責（一句） | 呼叫（`Class.method`） | 既有方法夠嗎 | 複雜度 | Error → 處置 |\n- `呼叫`：寫**字面的** `Class.method`，不寫「呼叫同步模組」——編造的名字可 grep、可證偽，模糊的描述不可。沒有就 `—`。\n- `既有方法夠嗎`：只接受**真實引用**（`file:line` 或貼出簽名）或字面的 `未讀`。`未讀` 是**合法**的，它轉成一條 recon 待辦，不擋 gate——憑印象作答才是違規。不夠用 → 寫 `不足 → <要怎麼調整>`，並把該既有 class 補進總表為 MOD。\n- `複雜度`：`T:… · S:…` **兩半都要填**，trivial 的就是 `T:O(1) · S:O(1)`（兩個 token，不要因為便宜就跳過）。Big-O **必須指名變數**（`n=書籍數`）——沒指名的 O(n) 是裝飾品，不可證偽。帶 I/O 的要標單位：`T:O(n) reads, n=書籍數`，否則 N+1 會躲在 O(n) 底下。\n- `Error → 處置`：`<具體 exception 子類別> → <處置>`。含**自己會丟的**與**被呼叫方會丟的**兩種。憑空的「可能會 throw」不算——依據見 §Error policy 的證據規定。沒有就 `—`。\n\n命名 feature-prefix + role suffix（`naming.md`）。每個 class 標治理它的 SOP（`references/sop/<block>.md`）——內部設計與 method body 交給 SOP + 實作，plan 只負責串連與介面。presentation 的 class 加 `· design spec §<section>` 引用對應章節。新 exception 標 parent AppException 子類別 + carried fields；新 use case 標 `UseCase<Return, Param>` + Param class（Equatable，禁 record）。新外部套件在總表加一列 `pubspec.yaml MODIFY` + 引入原因與**內部證據**（source-code 引用，非 README headline）。\n**永遠不留空格**：`—` = 沒有，`未讀` = 沒查證。',
    template: '| Class | Layer | Kind | File (NEW/MOD/DEL) | 職責 | 持有狀態 | 為何要新增 |\n|---|---|---|---|---|---|---|\n| `SyncRepository` | data | repository | `lib/sync/sync_repository.dart` (NEW) | <一句> | `mirrorCache` 上限 200 · LRU | canonical home：grep `mirror` → 無既有擁有者 |\n| `SyncCubit` | presentation | cubit | `lib/sync/sync_cubit.dart` (NEW) | <一句> | `—` | 框架/平台：Bloc 無內建同步編排 → 需自管 |\n\n<總表一列一個 NEW/MOD class，依 data → domain → presentation 排序>\n<未變動的 layer 各一行：domain: no change>\n\n<以下 ### 區塊：總表的每一列都要有一個，一個都不能少。名字要和上表、和 §Data flow 的節點逐字一致>\n\n### `SyncRepository`\nSOP: `references/sop/<block>.md`\n\n| method | 簽名 | 職責 | 呼叫 | 既有方法夠嗎 | 複雜度 | Error → 處置 |\n|---|---|---|---|---|---|---|\n| `ctor` | `SyncRepository(LocalStore)` | collaborators = test seam | `—` | `—` | `T:O(1) · S:O(1)` | `—` |\n| `write` | `Future<void> write(Id, T)` | <一句> | `LocalStore.put` | `lib/store.dart:88` 簽名相符 | `T:O(1) write · S:O(1)` | `PathAccessException → 轉 StorageFailure，上拋` |\n| `readAll` | `Future<List<T>> readAll()` | <一句> | `—` | 未讀 | `T:O(n) reads, n=書籍數 · S:O(n)` | `—` |\n\n### `SyncCubit`\nSOP: `references/sop/<block>.md`\n\n| method | 簽名 | 職責 | 呼叫 | 既有方法夠嗎 | 複雜度 | Error → 處置 |\n|---|---|---|---|---|---|---|\n| `ctor` | `SyncCubit(SyncRepository)` | collaborators = test seam | `—` | `—` | `T:O(1) · S:O(1)` | `—` |\n| `start` | `Future<void> start()` | <一句> | `SyncRepository.write` | `—` | `T:O(n), n=待同步筆數 · S:O(1)` | `StorageFailure → 顯示重試` |',
  },
  {
    key: 'Data flow',
    aliases: ['資料流', '流程圖'],
    kind: 'raw',
    required: true,
    criteria: ['c1', 'c3', 'c6'],
    description: 'mermaid 型別化呼叫圖：節點名逐字對上 §Classes；race 由它推導',
    hint: '一張 mermaid `flowchart`，**節點名逐字對得上 §Classes**（對不上就是名字漂移，機械查得出來）。三種節點形狀就是三種型別：\n- `([...])` **併發來源 / entry point**：使用者動作 · stream · 背景 sync · isolate · 平台 callback · app 啟動。\n- `[Class.method]` **呼叫節點**：必須是 §Classes 某個 class 區塊裡的一列。\n- `[(state)]` **持有狀態**：必須是總表 `持有狀態` 欄出現過的東西。\n\n**這張圖存在的理由是找 race**：被 **≥2 個不同 `([origin])` 寫入**的 `[(state)]` 節點就是 race 候選，每一個都必須在 §Error policy 有對應列。這是封閉性檢查——把「你有沒有想到 race」換成「你有沒有把自己畫出來的東西交代完」，後者可查、前者不可查。\n\n**至少要有一個 `([origin])` 節點**，否則這張圖沒有回答它該回答的問題。真的只有單一入口就明寫一行「單一入口，無併發來源」，不要畫空圖。\n**只畫跨 class 邊界的邊**，且只畫 product plan 點名的使用者情境——每個 method 都畫會變成沒人看得懂的毛球。class 內部呼叫不畫。\n圖上順帶標出 hot path：per-method 的 Big-O 看不到**組合**（`O(1)` 的方法被放進別人的 `O(n)` 迴圈，整條路徑是 `O(n)`，兩張表分開看每列都乾淨）——那條邊在圖上才顯得出來。\nmermaid 標籤含中文或括號時用引號包住，否則語法會壞。',
    template: '```mermaid\nflowchart LR\n  U(["使用者點下 同步"]) --> A\n  S(["背景 sync stream"]) --> B\n  A["SyncCubit.start"] --> B["SyncRepository.write"]\n  B --> M[("mirrorCache")]\n  A --> M\n```\n\nHot path: <哪條路徑 + 它的 bound>',
  },
  {
    key: 'Error policy',
    aliases: ['錯誤處理', '錯誤政策'],
    kind: 'raw',
    required: true,
    criteria: ['c7'],
    description: '一行分類原則 + 共享狀態爭用表（由 §Data flow 推導）',
    hint: '**先一行 policy**：transient vs conclusive · recoverable vs terminal · retry-eligible vs hard-fail 的處理原則。逐一 exception 的處置寫在 §Classes 各 method 的 `Error → 處置` 欄，這裡只放跨 class 的裁示。\n\n**證據規定（適用於本節與 §Classes 的 error 欄）**：exception 要**具體子類別**、不要抽象基底；依據必須真實——`throw` 來源 `file:line` · 框架 doc URL · 平台觀察 · 過去事故編號。「可能會 throw」不算依據。log 呼叫寫完整：`LogSystem.error("message", error: e, stackTrace: st)`。標準見 `error-handling.md`（conclusive-only write · exhaustive arm · no-silent-failure · predicate-over-catch）。\n\n**再一張共享狀態爭用表**，**從 §Data flow 推導**：每個被 ≥2 個 origin 寫入的 `[(state)]` 節點一列。寫入者只有一個的不列。\n| 共享狀態 | 寫入者（`Class.method`） | 併發來源 | 順序重要嗎 | 序列化機制 / 可接受 last-write-wins 的理由 |\n`併發來源` 用固定字彙：stream · 使用者連點 · 背景 sync · isolate · 平台 callback。\n每列要嘛指名序列化 primitive（Lock / Mutex / Completer / per-key 佇列），要嘛接受 last-write-wins 並說明**收斂路徑**與理由。\n圖上沒有這種節點時，寫一行「無 ≥2 來源的共享狀態」——那是一個可以證明的答案，不是省略。\n\n本節只涵蓋「兩個來源撞同一份狀態」這一類。**await gap**（await 前讀、await 後用）是程式碼形狀、**框架排程**（rebuild 順序 / microtask / plugin 執行緒）是執行期行為，兩者計畫階段看不到，歸 code-reviewer 與 `/qa` 的 async-race failure class——不要在這裡假裝涵蓋。',
    template: 'Policy: <transient vs conclusive / retry vs hard-fail 的處理原則，一行>\n\n| 共享狀態 | 寫入者 | 併發來源 | 順序重要嗎 | 序列化機制 / 可接受的理由 |\n|---|---|---|---|---|\n| `mirrorCache` | `SyncCubit.start` · `SyncRepository.write` | 使用者連點 · 背景 sync | 是 | per-key 佇列序列化（`data.md §Per-Key Serialization`） |\n\n<沒有的話改寫這一行：無 ≥2 來源的共享狀態。>',
  },
  {
    key: 'Startup',
    aliases: ['啟動', '初始化'],
    kind: 'table',
    required: true,
    criteria: ['c12'],
    description: '本次新增 / 改動的啟動期元件：建構時機、前置依賴、誰證明它跑了',
    hint: '**為什麼是獨立章節**：初始化 bug 抓的是**缺席**，而計畫其他每一節都只看得到存在。從沒被建構的元件在 §Classes 有列、在 §Contracts 有方法、在圖上有節點，看起來一切正常，就是永遠不會跑——**漏掉的邊不會被畫出來**。而且 `A --> B` 的意思是「A 呼叫 B」，不是「A 必須在 B 之前就緒」，順序相依在圖上是兩個不相干的節點。單元測試對這類也結構性失明：測試直接呼叫 `init()`，證明不了「app 從來沒呼叫 `init()`」。\n\n多數 feature 不動啟動期，**這時整節就是一行**：`無新增啟動期工作 —— <一句理由>`。那一行有價值：它是「想過了，沒有」和「沒人想過」的差別。不要留空表。\n\n有的話，**只列這份計畫新增或改動的**啟動期元件：\n| 元件 (file + symbol) | 建構時機 (eager / lazy / 首次讀取) | 依賴什麼先就緒 | 誰證明它真的跑了 |\n最後一欄是本節的重點，**不接受「單元測試涵蓋」**——單元測試呼叫 `init()` 證明的是邏輯正確，不是那條路徑被走到。可接受的證明：device / integration test 走真實流程 · 啟動期 log 斷言 · 未初始化就 fail-loud 的守衛。\nfire-and-forget 的副作用元件（沒有 widget 消費它，只驅動導航 / 訂閱 / 排程）必須**明確建構**——lazy 就等於死掉。\n本表列的元件應該都能從 §Data flow 的 `([app 啟動])` origin 連得到；連不到的那一個，就是「沒人建構它」現形的地方。\n只在**真的有不可交換的配對**時才補一張順序子表：| 先 | 後 | 為何不可交換 |。沒有就不畫。',
    template: '無新增啟動期工作 —— <一句理由>\n\n<有的話改用下表：>\n| 元件 | 建構時機 | 依賴什麼先就緒 | 誰證明它真的跑了 |\n|---|---|---|---|\n| `lib/sync/bootstrap.dart` `SyncBootstrap` | eager (main) | `LocalStore.open` | integration test `TC-11` 走真實啟動流程 |',
  },
  {
    key: 'Migration impact',
    aliases: ['Migration', '遷移', '相容性', '向後相容'],
    kind: 'raw',
    required: true,
    criteria: ['c11'],
    description: '持久化格式 / schema / API 的變更與回退路徑',
    hint: '持久化格式、schema、既有 API 的變更各一條：**舊資料怎麼被讀**、**舊版本 app 遇到新資料會怎樣**、**回退路徑是什麼**。\n沒有任何遷移影響時寫一行「無持久化 / schema / API 變更」+ 一句理由。\n禁：「加個欄位而已，向後相容」而沒說明舊版讀到它會怎樣。',
    template: '無持久化 / schema / API 變更 —— <一句理由>\n\n<有的話一條一行：<變更> — 舊資料如何讀 / 舊版 app 行為 / 回退路徑>',
  },
  {
    key: 'Risks',
    aliases: ['風險'],
    kind: 'table',
    required: true,
    criteria: ['c3'],
    description: '工程風險（非產品風險）+ 零殘留 mitigation；含 10× 規模',
    hint: '兩欄：Risk | Mitigation。考慮：library 意外 · 平台分歧（iOS / Android / desktop / web）· 效能天花板 · supply-chain pin move · SSOT violation。\n**必含規模那一條**：這個設計在 10× 現有規模下怎麼樣（1000+ 本書 · 100 MB EPUB · 50+ collections · 慢速 / 離線網路 · 5+ 同步裝置）？瓶頸在哪、既有規模下有沒有已經該擔心的？§Data flow 的 fan-out 是它的證據來源。\n每行要具體（「`dart:io File.writeAsBytes` 在 Android 12+ external storage 權限變更下可能 throw `PathAccessException`」勝過「可能有 IO 錯誤」）；一條實質風險勝過十條「可能比較慢」。\n**零殘留 gate**：每條都要有具體、可執行的 mitigation。`monitor` / `accept` / `低優先` / `TBD` / `之後再說` 都不算。無法 mitigate 的**不可自行接受、不可省略**——停下來問 user（Iron Law 11），由 user 裁示（縮 scope / 換做法 / 明確接受）。任一行缺具體 mitigation → 計畫不可進 Iron Law 5 approval。',
    template: '| Risk | Mitigation |\n|---|---|\n| <具體風險，含觸發條件> | <具體、可執行的動作> |\n| 10× 規模：<瓶頸在哪> | <具體動作> |',
  },
  {
    key: 'Conformance',
    aliases: ['符合性', '對照'],
    kind: 'table',
    required: true,
    criteria: ['c9'],
    description: '反遺漏對照表：上游每條承諾 → 實作它的 Class.method → 驗證',
    hint: '**唯一的反向走查**。其他每一節都按「我們要蓋什麼」索引；漏掉的需求不會產生任何 class、任何 method、任何圖上的節點——**缺席在一個以存在組織起來的結構裡不留痕跡**。所以存檔前**反過來**走一遍 design spec（component 矩陣有行為的格 · 四狀態 · 每個動效 / 轉場 / 互動）+ product plan（success metric · scope 承諾），逐項確認有列。\n| # | Requirement（一句） | Source | 實作於（`Class.method`） | 驗證 |\n`Requirement` 一句話寫清楚要什麼，**不整段抄上游**（`I2`）；`Source` 指回上游章節。\n`實作於` 必須是 §Classes 裡實際存在的 `Class.method`——這一欄可機械查（找不到 = 名字漂移或根本沒做）。\n`驗證` 指向 QA 的 acceptance test id；plan 階段還沒有就寫 `pending`。\n任一可觀察的 spec 項缺列、或列指向不存在的 method → plan incomplete。',
    template: '| # | Requirement | Source | 實作於 | 驗證 |\n|---|---|---|---|---|\n| 1 | <一句話的需求> | design spec 的動效章節 | `SyncCubit.start` | TC-07 |',
  },
  {
    key: 'Revision history',
    aliases: ['修訂歷史', '修訂紀錄', '變更紀錄'],
    kind: 'bullets',
    required: true,
    criteria: [],
    description: '變更記錄（audit trail）',
    hint: '首行固定：YYYY-MM-DD: Created.\n每次修訂加一行說明 what changed and why：co-creation 決議落地 / divergence rev（說明偏差原因）/ founder 回饋 / blueprint-reviewer 修正。\n一行一次修訂，不展開理由——裁示本身寫在正文被裁定處的決策註記裡（`plan/SKILL.md §Plan integrity` 的 `I4`）。\n不要省略；這是計畫演進的 audit trail，月後回溯仍需讀懂。',
    template: '- YYYY-MM-DD: Created.',
  },
];
