// Design Plan body section definitions.
// SSOT for section structure and authoring guidance for the designer role.
//
// Each section:
//   key         — the ## heading text emitted in the Notion body (繁中 or English)
//   kind        — para | bullets | table | checklist | raw
//   required    — ADVISORY (freeformBody): drives `hints`, does not gate
//                 create/update. Any `## heading` is legal.
//   criteria    — always [] for design plan (blueprint-reviewer covers engineering plans only)
//   description — one-line description of what this section IS
//   hint        — authoring guidance for the LLM filling this section
//
// Commands:
//   node .claude/skills/archivist/scripts/notion_payload.mjs hints  design-plan   → section questionnaire
// §Problem is deliberately ABSENT: the product plan owns the problem statement,
// and its own hint used to say "從 product plan 抽取" — an admitted duplicate.
// Read the product plan for the problem (designer Iron Law 1); don't restate it.
export const body = [
  {
    key: 'Flow',
    kind: 'raw',
    required: true,
    criteria: [],
    description: '使用者操作流程（入口 → 成功狀態），每步一行',
    hint: '編號流程：1. Entry point → 2. → ... → N. Success state / exit。\n標出入口（從哪裡觸發）與成功狀態（user 認為任務完成的時刻）。\n分支流程（error / edge case）各開子流程，縮排標示。\n禁工程詞彙（cubit / repository / route name）——只寫使用者行為和畫面反應。',
  },
  {
    key: 'Decision history',
    kind: 'raw',
    required: true,
    criteria: [],
    description: '佈局決策的編號流水紀錄（co-created + 自行裁定），每項引設計原則，不記選項',
    hint: '**編號清單**（markdown `1.` `2.` …，非表格），每個決策一項：\n`<決策> — <裁示 + 理由（引設計原則）> —— <裁定者>`\n裁示理由引一個設計原則（M3 canonical layout / Fitts / hierarchy / reuse / a11y / reading-first）；禁審美形容詞（clean / minimal / elegant）。**不記錄被否決的選項**；若「為什麼選 A 不選 B」是理解裁示的關鍵，寫進理由那一句。\n裁定者填 `使用者`（與 user co-create / 拍板，Iron Law 9）或 `自行裁定`（trivial、低風險、單一明確解，你未問逕自決定——/plan rule 1 的 trivial carve-out）。每筆自行裁定都必須留一項，讓 user 在 co-review 一眼掃到並可推翻——decide 可以不問，但不可不記。\n純機械、無分叉的選擇不是決策，不入清單。\n**決策改變時，改內文、不疊層**：spec 正文（§Flow / §States / §Component-by-component spec …）改成新裁示，本清單新增一項 `#12 取代 #7：<新裁示 + 為何改>`，舊項目原地保留不刪不劃線。完整規則與理由見 `plan/SKILL.md §Plan integrity` 的 `I1`。\n寫入時機：本清單隨 living draft 在既有上傳里程碑 batch 上傳，勿每筆決策各打一次 Notion。',
  },
  {
    key: 'States',
    kind: 'table',
    required: true,
    criteria: [],
    description: '每個畫面的 4 個必要狀態（default / empty / loading / error）+ 額外狀態',
    hint: '3 欄表格：| State | Trigger | Component / behavior |\n每個畫面至少 4 行（Iron Law 5）：Default / Empty / Loading / Error。\n  Empty：CommonInfoWidget（icon + title copy intent + optional caption intent + optional actions）。\n  Loading：第一次載入 → CommonLoadingWidget；後續更新 → backgroundLoading（保留現有內容）。\n  Error：CommonErrorWidget，含 localized content。\n  Async 操作中：CommonProgressDialog（loading → success/error）。\n禁：只有 default、空白 trigger、漏列任何畫面的任一狀態。',
  },
  {
    key: 'Component-by-component spec',
    kind: 'table',
    required: true,
    criteria: [],
    description: '每個可見元素的 token 規格（欄位隨表而定，不用固定 12 欄）',
    hint: '**欄位是可變的，只列這張表真的用得到的。** 固定欄位：`# / Region`、`Component`、`Notes`。其餘只在**至少一列真的有值**時才加：`Color (bg)`、`Color (fg)`、`Text style`、`Padding`、`Margin`、`Border radius`、`Icon`、`Size`。\n**整欄都會是「—」的欄位不要出現**——那是模板逼出來的填充，不是規格（實測一份 spec 的這一節有 48 個空 cell、172 行）。「—」只保留給「這一列明確無此值，by design」，不是「待決」，也不是「這類元素都沒有」。\n每個可見元素一行（含 spacer、divider、chip inside card）。出現的每個值都受 Iron Law 8 約束：\n  Color (bg/fg)：colorScheme.<role>（surfaceContainer, onSurfaceVariant…）。禁 raw hex、Colors.*。\n  Padding / Margin：spacing scale（4.0 / 8.0 / 12.0 / 16.0 / 24.0）。禁 "tight" / "comfortable"。\n  Border radius：radius scale（4.0 / 8.0 / 12.0 / 16.0 / 24.0 / 36.0）；驗 concentric corners。\n  Text style：textTheme.<role>（titleMedium, bodySmall…）。\n  Icon：Icons.X_rounded（或 LucideIcons.X）+ dp size。\nShared widget row：只列 instantiation arguments（icon, color tint, copy intent）——其自身 token 已鎖定。**若多列都是共用元件，在表格上方寫一句總則**（「標 `↳shared` 的列版面由共用元件契約鎖定」），列內只留標記，不要每列重抄同一句（實測 DP 重複同一句 6–7 次）。\nDelta mode：只列新增 / 變更的 element；不變的寫「見 parent spec §N」。',
  },
  {
    key: 'Interaction & motion',
    kind: 'bullets',
    required: true,
    criteria: [],
    description: '手勢、點擊目標 (≥ 48dp)、回饋時機、動畫規格',
    hint: '涵蓋：\n  手勢（tap / swipe / drag / long-press）及觸發結果。\n  點擊目標 ≥ 48dp；< 48dp 說明補償方式。\n  回饋時機：< 100ms direct manipulation / loading by 400ms / progress by 1s。\n  動畫：duration（140–300ms）+ curve + what animates。\n  Breakpoint 間的 state transition（restructure vs reflow）。\n  Reduced motion fallback（motion 絕不是 essential）。\n禁：hover-only、任意 breakpoint、bounce / parallax。',
  },
  {
    key: 'Accessibility',
    kind: 'bullets',
    required: true,
    criteria: [],
    description: 'WCAG 2.2 AA、touch target、focus order、Dynamic Type、reduced motion',
    hint: '逐條列：\n  Contrast：body ≥ 4.5:1；large text / UI components ≥ 3:1。\n  Touch target ≥ 48×48dp；< 48dp 時補 spacing ≥ 24dp。\n  Focus order matches visual order；visible focus indicator ≥ 2px。\n  Screen-reader label for every interactive element（Semantics / tooltip 策略）。\n  Dynamic Type：textScaler up to 1.5 時 layout 不爆版。\n  Reduced motion fallback（具體指出哪些 animation 要 fallback）。\n禁：含糊的「a11y 符合規範」——每條要有具體說明。',
  },
  {
    key: 'Localization',
    kind: 'bullets',
    required: true,
    criteria: [],
    description: '新增 l10n key 的 copy intent 清單（供 translator phase 使用）',
    hint: '每條：<key-intent> — <tone> — <copy intent（說明文字表達什麼，不自己寫 copy 值）>。\nTranslator phase 負責 mint ARB key + 撰寫全語言 copy；這裡只列 intent。\n若 0 新增 key（純 token / layout 調整），明確寫「無新 l10n key」。\n禁：自己寫 ARB 字串值、跳過 translator phase、用 "TBD" 代替 intent。',
  },
  {
    key: 'Revision history',
    kind: 'bullets',
    required: true,
    criteria: [],
    description: '變更記錄（audit trail）',
    hint: '首行固定：YYYY-MM-DD: Created.\n每次修訂加一行說明 what changed and why：co-creation 決議落地 / founder 回饋 / ux-reviewer 的修正 / 下游 role 退回。\n這裡記**所有**修訂（含非決策性的措辭修正）；§Decision history 只記裁示，兩者不重複。\n不要省略；這是 spec 演進的 audit trail，月後回溯仍需讀懂。',
  },
  {
    key: 'Mockups',
    kind: 'images',
    required: false,
    criteria: [],
    description: 'Phase 7 渲染的 mockup PNG（real-widget，非手繪）嵌進 plan body',
    hint: 'manifest 此欄給 `build/design-mockups/<slug>/` 目錄（builder 會 glob *.png 依檔名排序、全矩陣嵌入）或一個明確的路徑陣列。\n圖檔名 `<screen>__<size>__<state>__<theme>__<locale>.png` 會被轉成每張圖的 caption。\n圖在 `--commit` 時上傳（single-part file upload）並 append 成 image block，不進 markdown body。\n來源必須是 `render-mockups.sh <slug>` 的輸出（real widget + real tokens）——不要手繪 / Figma 截圖。',
  },
];
