// Design Plan body section definitions.
// SSOT for section structure and authoring guidance for the designer role.
//
// THE DESIGNER SHIPS THE WIDGETS. The presentation components are the
// deliverable, not a description of them — so this body holds only what the
// code cannot say. Tokens, layout, padding, radii and text styles are read off
// the widget source; restating them here would be a second truth that drifts
// (the retired token table measured 172 lines and 48 empty cells on one spec).
// What survives is intent and semantics:
//   §States   — WHEN each state is shown. The code shows what it looks like.
//   §Seam     — what the engineer must supply, as observable behaviour. The
//               constructor signature is the contract; this says what it means.
//   §A11y · §Interaction — the intent behind the values, and the bars a
//               reviewer scores against.
//
// Each section:
//   key         — the ## heading text emitted in the Notion body (繁中 or English)
//   aliases     — translated heading forms; `notion-payload sections` ORs them
//                 into the regex, so nothing outside this file keeps its own copy
//   kind        — para | bullets | table | checklist | images | raw
//   required    — ADVISORY (freeformBody): drives `hints`, does not gate
//                 create/update. Any `## heading` is legal.
//   criteria    — always [] for design plan (engineer-plan-reviewer covers engineering plans only)
//   description — one-line description of what this section IS
//   hint        — authoring guidance for the LLM filling this section
//   template    — the literal skeleton `notion-payload template` emits
//
// Commands:
//   notion-payload hints    design-plan   → the questions + 禁-lists
//   notion-payload template design-plan   → the skeleton to fill
//
// §Problem is deliberately ABSENT: the product plan owns the problem statement.
// Read it for the problem (designer Iron Law 1); don't restate it.
export const body = [
  {
    key: 'Summary',
    aliases: ['摘要', '總結'],
    kind: 'para',
    required: true,
    criteria: [],
    description: '2–4 行：改的是哪個 surface、做了什麼取捨',
    hint: '2–4 行：這次動到哪個 surface、選了什麼形狀、最大的取捨是什麼。\n不要重抄 product plan 的問題敘述（`I2`）。被否決的方案不寫在這裡（`I3`）——「為什麼不是 X」只有在它讓裁示變得可讀時，才進那一則 `〔自行裁定〕` 註記（`I4`）。\n上游連結不寫在 body：`Task` relation 已經指向該 feature 的 tasklist row。',
    template: '<改的是哪個 surface + 為什麼，1–2 句>\n<最大的取捨，1 句>',
  },
  {
    key: 'Widgets',
    aliases: ['元件', '元件檔'],
    kind: 'bullets',
    required: true,
    criteria: [],
    description: '本次交付的 widget 檔清單（一行一檔，路徑 + 一句用途）',
    hint: '**一行一個檔**：`` `<path>` — <一句用途> ``。這裡只給定位，不描述長相——長相在程式碼裡，`render-lint` 與 §Renders 各自驗證它。\n交付的每個 widget 都必須通過 `design-lint <path>`：\n- **只碰 presentation**：不得 import repository / service / cubit / bloc / provider / getIt；不得出現 `context.read` / `context.watch` / `BlocBuilder` / `Consumer` / `StreamBuilder`。資料一律從 constructor 參數進、動作一律用 callback 出。\n- **原則上 `StatelessWidget`**。`StatefulWidget` 唯一的正當理由是 **vsync**（`TickerProvider` / `AnimationController`）——動畫本質上是渲染的一部分，抽不出去。State 裡沒有 vsync = 這個 StatefulWidget 不該存在，把變化改用參數傳。\n- **不得建構有生命週期的 controller**（`FocusNode` / `ScrollController` / `TextEditingController` / `PageController` / `TabController`）——它們由 cubit 持有、當參數傳進來。用參數收是對的，`new` 出來是違規：需要釋放的資源不屬於這一層。\n這三條是 `design-lint` 逐檔查的，不是自我宣告。',
    template: '- `lib/<feature>/presentation/<name>.dart` — <一句用途>\n\n<每個交付的 widget 一行；全部要通過 design-lint>',
  },
  {
    key: 'States',
    aliases: ['狀態'],
    kind: 'table',
    required: true,
    criteria: [],
    description: '每個狀態的「什麼時候出現」——長相在程式碼裡',
    hint: '3 欄：| State | 什麼時候進入這個狀態 | 使用者看到 / 能做什麼 |\n每個畫面至少四列（Iron Law 5）：Default / Empty / Loading / Error。\n**這一節問的是「什麼時候」，不是「長什麼樣」**——長相是 widget 的參數決定的，寫在程式碼裡，抄過來就是第二真相源。\n第二欄要能區分容易混淆的相鄰狀態：什麼情況該看到 empty 而不是 loading（首次載入 vs 已載入但無資料）、什麼情況該看到 error 而不是 empty（拿不到 vs 拿到了但是空的）。分不清楚的話，實作一定會挑錯一個。\n第三欄寫**可觀察行為**：看得到什麼、能不能操作、有沒有出口。\n\n**視覺狀態必須忠實對映底層真實狀態**——這一節最常出錯的五種，逐一自問：\n- **notice ≠ error**：使用者能在原地解決的狀況（語言對撞、預設不符）用 notice 的形狀，不要套 error 的形狀；error 的視覺是「出事了、你可能無能為力」。\n- **disabled 要帶得知原因的訊號**：因為 async readiness（cold-start probe、權限、平台能力）而 disabled 的控制，使用者要看得出「為什麼現在不能按」，否則它和「壞掉了」無法區分。\n- **pre-flight 失敗不要進 in-flight 視覺**：動作若有便宜的同步 / 次感知的 pre-flight 檢查，失敗時直接給結果，不要先閃一下 loading 再失敗。\n- **in-flight 的結束綁 user-perceived 事件**：loading 的結束條件要是使用者認得出的那一刻，不是某個內部 future 完成的那一刻。\n- **網路相依區域要有 offline 終態**：只有連線才會 resolve 的來源，離線時必須有一個**終止**狀態，不能永遠轉圈。\n狀態的形狀怎麼進 widget（sealed view-state / 個別參數）是**設計決策**——你列舉了哪些視覺上不同的狀態，就用那個形狀；但「什麼條件下進入哪個狀態」是工程的，寫在第二欄當**期待**，不要在這裡指定機制（`I2`）。',
    template: '| State | 什麼時候進入 | 使用者看到 / 能做什麼 |\n|---|---|---|\n| Default | <條件> | <可觀察行為> |\n| Empty | <條件——與 loading / error 的分界要講清楚> | <可觀察行為> |\n| Loading | <首次載入？背景更新？> | <可觀察行為> |\n| Error | <條件> | <可觀察行為 + 出口> |',
  },
  {
    key: 'Seam',
    aliases: ['接縫', '交接'],
    kind: 'table',
    required: true,
    criteria: [],
    description: '需要真資料的參數 / callback：概念上是什麼 + 期待的可觀察行為',
    hint: '交付的 widget 有一組參數，那組參數就是給 engineer 的合約。**只列需要真資料的參數與所有 callback**——已經有預設值、純視覺的參數不用列。\n| Widget | 參數 / callback | 概念上是什麼 | 期待的可觀察行為 |\n`概念上是什麼` 用產品語言（「這本書目前的同步狀態」），不是工程語言（「SyncCubit.state.status」）。\n`期待的可觀察行為` 寫使用者看得到的結果（「按下後這一列變成 loading，完成後回到 default」），**不寫機制**——路由怎麼走、狀態怎麼調和、資料從哪個 repository 來，全是 engineer 的裁定（`I2`）。在這裡指定機制 = 把未驗證的工程決策當成既定設計。\n簽名本身不用抄——constructor 就是它，抄過來會漂（`I2`）。',
    template: '| Widget | 參數 / callback | 概念上是什麼 | 期待的可觀察行為 |\n|---|---|---|---|\n| `SyncBanner` | `onRetry` | 使用者要求重試同步 | 按下後這一列進 loading；成功回 default，失敗回 error 並保留錯誤說明 |',
  },
  {
    key: 'Interaction & motion',
    aliases: ['互動', '動效'],
    kind: 'bullets',
    required: true,
    criteria: [],
    description: '手勢、點擊目標、回饋時機、動效的意圖（數值在程式碼裡）',
    hint: '涵蓋：手勢（tap / swipe / drag / long-press）及觸發結果 · 點擊目標 ≥ 48dp，< 48dp 說明補償方式 · 回饋時機（< 100ms direct manipulation / loading by 400ms / progress by 1s）· breakpoint 之間是 restructure 還是 reflow · reduced-motion fallback（motion 絕不是 essential）。\n**動效寫意圖，不抄數值**：duration 與 curve 在 widget 程式碼裡，這裡寫這個動效在傳達什麼（「讓使用者看見那一列從舊位置移到新位置，所以絕不能淡出淡入」）——那句話才是 reviewer 和實作者判斷做對沒有的依據。\n禁：hover-only、任意 breakpoint、bounce / parallax。',
    template: '- 手勢：<gesture> → <結果>\n- 點擊目標：<≥48dp，或 <48dp 時的補償>\n- 回饋時機：<哪個動作、多久內要有回應>\n- 動效意圖：<這個動效在傳達什麼；絕不能變成什麼>\n- Reduced motion：<哪些動效要 fallback、fallback 成什麼>',
  },
  {
    key: 'Accessibility',
    aliases: ['無障礙', 'a11y'],
    kind: 'bullets',
    required: true,
    criteria: [],
    description: 'WCAG 2.2 AA、touch target、focus order、Dynamic Type、reduced motion',
    hint: '逐條列，每條要具體（「a11y 符合規範」不算）：\n  Contrast：body ≥ 4.5:1；large text / UI components ≥ 3:1。\n  Touch target ≥ 48×48dp；< 48dp 時補 spacing ≥ 24dp。\n  Focus order 與視覺順序一致；focus indicator ≥ 2px 且看得見。\n  每個互動元素有 screen-reader label（`Semantics` 已寫在 widget 裡——這裡寫**唸出來該是什麼意思**，含動態內容怎麼組）。\n  Dynamic Type：`textScaler` 到 1.5 時版面不爆——這條在 §Renders 有對應的渲染可以驗。\n  Reduced motion：具體指出哪些動效要 fallback。',
    template: '- Contrast：<哪些組合、比值>\n- Touch target：<尺寸；不足時的補償>\n- Focus order：<順序>\n- Screen reader：<每個互動元素唸出來的意思>\n- Dynamic Type：<textScaler 1.5 的行為>\n- Reduced motion：<哪些要 fallback>',
  },
  {
    key: 'Localization',
    aliases: ['在地化', 'i18n'],
    kind: 'bullets',
    required: true,
    criteria: [],
    description: '新增 l10n key 的 copy intent 清單（供 translator phase 使用）',
    hint: '每條：<key-intent> — <tone> — <copy intent（說明這段文字要表達什麼，不要自己寫 copy 值）>。\nTranslator phase 負責 mint ARB key + 撰寫全語言 copy；這裡只列 intent。\n若 0 新增 key（純 token / layout 調整），明確寫「無新 l10n key」。\n禁：自己寫 ARB 字串值、跳過 translator phase、用 "TBD" 代替 intent。',
    template: '- <key-intent> — <tone> — <這段文字要表達什麼>\n\n<沒有的話改寫這一行：無新 l10n key。>',
  },
  {
    key: 'Revision history',
    aliases: ['修訂歷史', '修訂紀錄', '變更紀錄'],
    kind: 'bullets',
    required: true,
    criteria: [],
    description: '變更記錄（audit trail）',
    hint: '首行固定：YYYY-MM-DD: Created.\n每次修訂加一行說明 what changed and why：co-creation 決議落地 / founder 回饋 / ux-reviewer 的修正 / 下游 role 退回。\n一行一次修訂，不展開理由——裁示本身寫在 spec 被裁定處的決策註記裡（`plan/SKILL.md §Plan integrity` 的 `I4`）。\n不要省略；這是 spec 演進的 audit trail，月後回溯仍需讀懂。',
    template: '- YYYY-MM-DD: Created.',
  },
  {
    key: 'Renders',
    aliases: ['Mockups', '渲染', '截圖'],
    kind: 'images',
    required: false,
    criteria: [],
    description: '交付 widget 的實際渲染（breakpoint × state × theme × locale）',
    hint: '**這些不是示意圖，是出貨的那個 widget 真的長出來的樣子**——所以這一節是驗收，不是提案。舊的「防止畫出仿冒品」那套（sketch widget、guard、fidelity 自查）連同它要防的問題一起消失了：渲染的就是交付物本身。\nmanifest 此欄給 `build/design-mockups/<slug>/` 目錄（builder 會 glob *.png 依檔名排序、全矩陣嵌入）或一個明確的路徑陣列。圖檔名 `<screen>__<size>__<state>__<theme>__<locale>.png` 會被轉成每張圖的 caption。\n來源必須是 `render-mockups <slug>` 的輸出。手繪或 Figma 截圖現在不只是不精確，是**在描述一個已經存在的東西**——直接渲染它。\n渲染矩陣要覆蓋 §States 列舉的每個狀態；漏掉的狀態等於沒被看過。',
    template: '<render-mockups <slug> 的輸出目錄，例如 build/design-mockups/<slug>/>',
  },
];
