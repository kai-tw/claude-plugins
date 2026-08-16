// Engineering Plan body section definitions.
// SSOT for section structure, authoring guidance, and blueprint-reviewer routing.
//
// Reviewer-first + modular. Sections are ordered in tiers and each is
// single-concern; an artifact is described ONCE (in §Blocks) and referenced by
// name elsewhere — no re-statement across sections.
//   Tier A — At a glance (the review surface; reviewer grabs the whole shape
//            here in ~1 min): Summary · Composition · Risks · Migration impact.
//   Tier B — The blocks (the assembly): Blocks (one table — the sole block
//            inventory).
//   Tier C — Behaviour detail (implementer reference): Data flow · Error handling.
//   Tier D — Execution: Tasks (ordered, phase-grouped — folds Sequencing in).
//   Tier E — Trail (appendix): Revision history.
//
// Each section:
//   key         — the ## heading text emitted in the Notion body (English or 繁中)
//   kind        — para | bullets | table | checklist | raw
//   required    — ADVISORY on this DB (freeformBody): drives `hints`, does not
//                 gate create/update. Any `## heading` is legal.
//   criteria    — blueprint-reviewer dimension keys (c1–c11) this section earns
//   description — one-line description of what this section IS
//   hint        — authoring guidance for the LLM filling this section
//
// Standards live in .claude/rules/ (implementation constraints) + references/sop/
// (design procedure); the plan cites them, never restates them. The plan's job is
// 串連 — which blocks + how they wire + feature-specific instantiation.
//
// Commands:
//   notion-payload hints     engineering-plan   → section questionnaire
//   notion-payload criteria  engineering-plan   → criteria routing table
export const body = [
  // ── Tier A — At a glance (review surface) ──────────────────────────────
  {
    key: 'Summary',
    kind: 'para',
    required: true,
    criteria: [],
    description: '一兩句：在組什麼 + 為什麼（連 upstream product/design row）',
    hint: '1–2 句講清楚這個 plan 在組什麼、為什麼，並連到 task 的 Product / Design Plan row。不要重抄 product plan 的問題敘述（那是 PM 的）——這裡只給工程讀者一個 30 秒定位。形狀看 §Composition、風險看 §Risks。',
  },
  {
    key: 'Composition',
    kind: 'raw',
    required: true,
    criteria: ['c4', 'c5', 'c10'],
    description: 'Mermaid composition graph：積木 + 接線（系統形狀，reviewer 30 秒抓形狀）',
    hint: '用 Mermaid（mermaid code block，Notion 渲染成圖）畫出這次要組的積木與接線——block→block 的注入/呼叫關係（widget → cubit → use case → repository → data source）。這是模組裝配圖，也是 reviewer 抓形狀的地方。\n節點用 class name（feature-prefix + role suffix）。每個積木的介面、檔案、SOP 放 §Blocks，不在這裡展開；runtime 執行序列放 §Data flow。',
  },
  {
    key: 'Risks',
    kind: 'table',
    required: true,
    criteria: ['c3'],
    description: '工程風險（非產品風險）+ 零殘留 mitigation',
    hint: '兩欄：Risk | Mitigation。考慮：library 意外、platform 分歧（iOS/Android/desktop/web）、效能天花板、race / ordering hazard、supply-chain pin move、SSOT violation。每行要具體（「dart:io File.writeAsBytes 在 Android 12+ external storage permission 變更可能 throw PathAccessException」勝過「可能有 IO 錯誤」）；一條實質風險勝過十條「可能比較慢」。\n零殘留 gate：每條都要有具體、可執行的 mitigation。"monitor" / "accept" / "低優先" / "TBD" / "之後再說" 都不算。無法 mitigate 的不可自行接受、不可省略——停下來問 user（Iron Law 11），由 user 裁示（縮 scope / 換做法 / 明確接受）。任一行缺具體 mitigation → 計畫不可進 Iron Law 5 approval。',
  },
  {
    key: 'Migration impact',
    kind: 'raw',
    required: true,
    criteria: ['c11'],
    description: '對持久化狀態 / in-flight users / API callers 的衝擊（基準：最後 release tag）',
    hint: '基準線是最後 release tag（用 tool/version_diff.sh 確認），不是 HEAD——in-flight 使用者跑的是上一個 release。逐項列：\n- SharedPreferences / cache 格式變動 → 遷移路徑（一次性 migration process 或 default-on-read-fallback）\n- cubit state shape 變動 → hot-restart / cold-launch 行為\n- use case 參數 / 回傳值變動 → grep 每個 caller，逐一說明 delta\n- navigation stack 行為（modal sheet 在 context.push() 後繼續存活）\n- release artifacts（fastlane metadata、AAB/IPA 大小、permissions）\n無衝擊也要明寫「無遷移需求」並說明原因，不可省略。\n從未隨 release 出貨過的 state 不需要任何 backward-compat affordance——別寫死碼（先驗基準）。',
  },
  // ── Tier B — The blocks (the assembly) ─────────────────────────────────
  {
    key: 'Blocks',
    kind: 'raw',
    required: true,
    criteria: ['c4', 'c5', 'c8', 'c9', 'c10'],
    description: '唯一的積木清單：每塊一列（layer · 檔案 · 介面 · SOP）',
    hint: '一張表，每個積木一列：\n| Block | Layer | File (NEW/MOD/DEL) | Interface | SOP |\nInterface 只列 **class name + method 簽名清單**（無 method body、無邏輯 pseudo-code）；ctor 列出 collaborators（= test seam）。新 exception 列 parent AppException subclass + carried fields；新 use case 列 UseCase<Return, Param> + Param class（Equatable，禁 record）。\npresentation 的 block 在該列加「· design spec §<section>」引用對應 spec 章節。新外部 dependency 標一列 pubspec.yaml MODIFY + 引入原因。\n命名 feature-prefix + role suffix（naming.md；engineer rule P8）。每塊標治理它的 SOP（references/sop/<block>.md）——內部設計與 method body 交給 SOP + 實作，plan 只負責串連 + 介面。\n無變動的 layer 在表外一行明寫「<layer>: no change」。這是唯一的積木清單；其他 section 用 block name reference，不重述。',
  },
  // ── Tier C — Behaviour detail (implementer reference) ──────────────────
  {
    key: 'Data flow',
    kind: 'raw',
    required: true,
    criteria: ['c1', 'c2', 'c3', 'c6'],
    description: '每個使用者情境的 runtime 呼叫序列（用 §Blocks 的 block name reference）',
    hint: 'product plan 每個使用者情境各一段，逐步列誰呼叫誰（用 §Blocks 的 block name reference，不重述介面）。標出：isolate 邊界、StreamSubscription 放哪 / 誰負責 cancel、LogSystem.error/warning 在哪觸發。Reactive flow 標 Stream<T> 型別、是否 BehaviorSubject-backed。網路操作走 ConnectivityRepository。\n效能標準見 `code-style.md §Performance & Complexity`（hot-path Big-O、heavy work 離開 UI isolate、large data streaming、cache eviction、isolate snapshot cost）——在這裡標出 hot path 與它的 bound、10× scale（1000+ books / slow network / 5 devices）瓶頸在哪，不重抄標準。\nedge cases 列出（empty / single / max / malformed / concurrent）。',
  },
  {
    key: 'Error handling',
    kind: 'table',
    required: true,
    criteria: ['c7'],
    description: '錯誤分支：policy 一行 + 7 欄矩陣 + race 子表',
    hint: '先一行 policy（reviewer 抓的重點）：transient vs conclusive / recoverable vs terminal / retry-eligible vs hard-fail 的處理原則。\n再 7 欄矩陣：\n| Source (file + symbol) | Exception (具體子類別) | Evidence | Catch site | Log call | State/persistence effect | User-facing fallback |\nEvidence 必須真實引用（throw 來源 file:line、框架 doc URL、platform 觀察、prior incident ID）——「可能會 throw」不算。Log call 寫完整：LogSystem.error("message", error: e, stackTrace: st)。走過每個 external boundary（await / parse / API call / domain exception / concurrent producer）。標準見 `error-handling.md`（conclusive-only write / exhaustive arm / no-silent-failure / predicate-over-catch）。\n最後 race 子表：| Race | Handling |——每行要嘛 lock（說明 primitive：Lock/Mutex/Completer）要嘛 accept last-write-wins（說明 convergence path 與原因）。',
  },
  {
    key: 'Startup',
    kind: 'table',
    required: true,
    criteria: ['c12'],
    description: '啟動與初始化順序：policy 一行 + 5 欄矩陣 + 順序相依子表',
    hint: '為什麼是獨立章節：初始化 bug 是**順序**問題，不是狀態問題——四狀態矩陣問「這個畫面在 X 狀態長怎樣」，而初始化壞在「A 在 B 之前發生」，格子裡看不到。它們在單元測試中也**結構性不可見**：測試直接呼叫 `init()`，證明不了「app 從來沒呼叫 init()」。\n先一行 policy：這次改動有沒有新增啟動期工作？沒有就寫「無新增啟動期工作」+ 一句理由，不要留空表。\n再 5 欄矩陣：\n| 元件 (file + symbol) | 建構時機 (eager / lazy / 首次讀取) | 依賴什麼先就緒 | 依賴未就緒時的行為 | 誰證明它真的跑了 |\n最後一欄是本章節的重點，**不接受「單元測試涵蓋」**——單元測試呼叫 init() 證明的是邏輯正確，不是路徑被走到。可接受的證明：device / integration test 走真實流程、啟動期 log 斷言、或一個會在未初始化時 fail-loud 的守衛。fire-and-forget 的副作用元件（無 widget 消費、只驅動導航 / 訂閱 / 排程）必須**明確建構**，lazy 就等於死掉。\n第 3、4 欄要對得起來：依賴未就緒時「靜默用預設值」是最常見的靜默失敗——若行為是這個，說明為何可接受。\n最後順序相依子表：| 先 | 後 | 為何不可交換 | 交換了會怎樣 |——只列真正有順序相依的配對。',
  },
  {
    key: 'Conformance',
    kind: 'table',
    required: false,
    criteria: [],
    description: 'acceptance contract：product-plan 承諾 + design-spec 可觀察項逐項對到 block/task + 驗證（反遺漏）',
    hint: '反遺漏的 acceptance 對照表——product plan 每條承諾（success metric / scope item）+ design spec 每個可觀察項（component 行為、四狀態、每個動效 / 轉場 / 互動）各一列，每列對到 ≥1 §Tasks entry。schema 只是結構容器；「是否必填」由 engineer rule P9 裁定，故此處 required:false。\n| # | Requirement | Source (product §outcome / design §item) | Impl block-or-task | Code evidence (file:line) | Test (qa id) | Status |\nRequirement / Source / Impl 於 plan 階段填；Code evidence 於實作時 self-cite 落地行；Test 指向 QA acceptance test；Status = Pending / Confirmed。這是 §Blocks「source-from-spec 不得捏造」的反面：§Blocks 擋「加錯」，本表擋「漏做」。實作後由 conformance-reviewer + QA 驗證。',
  },
  // ── Tier D — Execution ─────────────────────────────────────────────────
  {
    key: 'Tasks',
    kind: 'bullets',
    required: true,
    criteria: [],
    description: '有序、依 phase 分組的實作清單（含 Sequencing；Task 1 = 審閱，Task N = /review）',
    hint: '一個清單同時表達順序與任務（取代分開的 Sequencing + Task list）。**普通 bullet list，不要 checkbox** —— 進度的真相在 TaskCreate（canonical）與 Notion task 的 `## Implementation` 鏡像，計畫寫的是「要做什麼、什麼順序」，不是「做到哪」；計畫裡再放一份勾選狀態就是同一事實的第三份來源，且必然最先過期。用 Phase A / B / C…（字母，避免與 task 編號衝突）分組，每組下列 tasks。格式（Task 1 與 Task N 固定不可省略）：\n- 1. Engineering review (this artefact)\n- Phase A — <slug>：\n  - 2. <task>\n- N. Post-implementation code review (`/review`) — Phase 12 close-out gate\n建議 phase 順序：A schema / preference / DI 基礎（無 UI delta）→ B service + bug-fix root cause → C domain / use case → D presentation cubit / widget（per surface）→ E i18n wiring（只接 translator 產生的 ARB key）+ manual smoke。\n需先驗證才能開始的 phase 加 pre-<Phase> task（bug root-cause、auth deps-graph audit…）。/qa 測試獨立一個 task。說明單 PR 多 commit 還是多 PR stack。',
  },
  // ── Tier E — Trail (appendix) ──────────────────────────────────────────
  {
    key: 'Revision history',
    kind: 'bullets',
    required: true,
    criteria: [],
    description: '變更記錄（audit trail）',
    hint: '首行固定：YYYY-MM-DD: Created at task list creation.\n每次修訂加一行說明 what changed and why：co-creation 決議落地 / Phase 11 divergence rev（說明偏差原因）/ founder 回饋 / blueprint-reviewer 修正。\n一行一次修訂，不展開理由——裁示本身寫在正文被裁定處的決策註記裡（`plan/SKILL.md §Plan integrity` 的 `I4`）。\n不要省略；這是計畫演進的 audit trail，月後回溯仍需讀懂。',
  },
];
