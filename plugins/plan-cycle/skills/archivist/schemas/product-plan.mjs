// Product Plan body section definitions.
// SSOT for section structure and authoring guidance for the PM role.
// Product plans have multiple artifact types — each type has its own section array.
//
// Each section:
//   key         — the ## heading text emitted in the Notion body
//   kind        — para | bullets | table | checklist | raw
//   required    — ADVISORY (freeformBody): drives `hints`, does not gate
//                 create/update. Any `## heading` is legal.
//   criteria    — always [] (engineer-plan-reviewer covers engineering plans only)
//   description — one-line description of what this section IS
//   hint        — authoring guidance for the LLM filling this section
//
// Commands:
//   notion-payload hints product-plan              → list types
//   notion-payload hints product-plan <type>       → questionnaire

// ── shared sections (reused across multiple types) ──────────────────────────────
const PROBLEM = {
  key: 'Problem',
  kind: 'para',
  required: true,
  criteria: [],
  description: '使用者角度的問題（who / when / how often / coping-today）',
  hint: '一段落，使用者語氣。答四個問題：\n  Who has it（具體 persona，不是「所有使用者」）\n  When / how often（場景 + 頻率）\n  What do they do today to cope（現有 workaround）\n  Why that\'s not good enough\n若對方給你 solution 而不是 problem，問「這在解決什麼問題、對誰、什麼情況下？」\n禁：solution-framing、工程詞彙（class names / file paths）、"all users"、inventing numbers without baseline。',
};

const WHY_NOW = {
  key: 'Why now',
  kind: 'para',
  required: true,
  criteria: [],
  description: '為什麼現在做（timing rationale）',
  hint: '說明觸發因素：新平台能力 / 使用者回饋量 / 競爭壓力 / 解鎖的依賴 / 策略轉向。\n一段，具體。「這個問題一直都有」不是 Why now。',
};

const TARGET_USER = {
  key: 'Target user',
  kind: 'para',
  required: true,
  criteria: [],
  description: '具體 reader persona（not "all users"）',
  hint: '描述一個具體的 reader persona：習慣、語言、設備、閱讀情境。\n若有多個 persona，說明主要目標是哪一個，以及為什麼。\n禁：「所有使用者」、「一般讀者」、無差異化的描述。',
};

const ACCEPTANCE_CRITERIA = {
  key: 'Acceptance criteria',
  kind: 'bullets',
  required: true,
  criteria: [],
  description: '逐條、二元可判定的驗收準則（merge 前在單機 / 測試環境即可驗）',
  hint: '每條格式：<情境> → <可觀察的結果>。\n判準是「這東西**做對了嗎**」——每條都要能在 merge 前、由一個人在一台裝置或測試環境上\n得到「做到 / 沒做到」的二元答案。「這東西**值不值得做**」屬 §Success metric，不寫在這裡。\n涵蓋三類：主要流程走通、已知失敗路徑的行為、**不得發生的事**（負面準則，例如「正常情況\n不得誤觸這個錯誤提示」）。\n禁：需要母體或時間序列才能判定的敘述（「大多數使用者能…」「留存提升」）——那些屬\n§Success metric；也禁實作細節（class / 檔案 / API 名稱）——寫使用者可觀察的行為。',
};

const SUCCESS_METRIC = {
  key: 'Success metric',
  kind: 'para',
  required: true,
  criteria: [],
  description: 'ship 後、在母體上、隨時間量測的指標 + threshold + by when',
  hint: '一個主要指標，且必須是**ship 後才量得到**的：在母體上、隨時間變化、統計性的。\n說明 threshold（達到什麼才算成功）+ by when（評估時間點）。\n逐條可在 merge 前於單機驗證的準則**不要寫在這裡**——那是 §Acceptance criteria。\n本專案常常沒有可用的線上訊號；此時就寫明「無 baseline，門檻由 founder 於首次資料審定時\n設定」，並至多列一條既有埋點可看的守門指標。**不要用行為準則把本節填滿**（實測兩份計畫\n都這樣做過，結果是本節混了兩種東西、長到難讀）。\n若無現有 baseline，不要自行發明數字（P1.1）。\n禁：多個主要指標、「改善使用者體驗」等無法量化的目標、threshold 留空。',
};

const PRODUCT_LEVEL_RISK = {
  key: 'Product-level risk',
  kind: 'bullets',
  required: true,
  criteria: [],
  description: '第一條固定是最危險假設 + 便宜驗證法（PM rule P7），其後為殘餘風險',
  hint: '**第一條必須是最危險假設**，格式：`**最危險假設：**<單一信念> — 驗證法：<便宜驗證>`。\n那是這個計畫成不成立最沒把握的那一句話，不是風險清單的第一項。\n排序參考：想要性（使用者會不會要）通常最先致命 > 存續性（撐不撐得住成本 / 商業模式）\n> 可用性 > 可行性（標準 app 通常最低風險，除非依賴未驗證的平台能力）。\n禁：把「這個做起來難不難」當最危險假設——那是可行性，通常不是最沒把握的那個。\n驗證法要便宜：訪談幾位使用者 / 假門頁面 / 現有數據回查 / 小型 spike——不是「先做完整功能\n再看數據」。若計畫已把完整實作排在驗證之前，退回重排序。\n**其餘各條是殘餘風險**，格式：<風險> — <目前最好的猜測或下一步緩解方式>；涵蓋技術執行、\n外部依賴、時程壓力。不要在這裡重複第一條。\n本區塊不收「open questions」：存檔前所有開放問題都已解決或經使用者明確確認為刻意 defer；\n刻意 defer 的決策在被 defer 的那條旁邊附決策註記（含 owner / trigger）。\n若無殘餘風險，只留第一條即可。',
};

const NON_GOALS = {
  key: 'Non-goals',
  kind: 'bullets',
  required: true,
  criteria: [],
  description: '明確不做的事（Iron Law 3）',
  hint: '明確列出：scope 邊界、被刻意排除的使用情境、不在 v1 裡的 follow-up。\n每條以「not X」或「X is out of scope」開頭。\n禁：留空（Iron Law 3 是硬要求，不是選項）、含糊的「not applicable」。',
};

const REVISION_HISTORY = {
  key: 'Revision history',
  kind: 'bullets',
  required: true,
  criteria: [],
  description: '變更記錄（audit trail）',
  hint: '首行固定：YYYY-MM-DD: Created.\n每次修訂加一行說明 what changed and why：co-creation 決議落地 / founder 回饋 / 下游 role 退回 / gate 修正。\n一行一次修訂，不展開理由——裁示本身寫在正文被裁定處的決策註記裡（`plan/SKILL.md §Plan integrity` 的 `I4`）。\n不要省略；這是計畫演進的 audit trail，月後回溯仍需讀懂。',
};

// ── artifact type definitions ──────────────────────────────────────────────────
export const types = {

  'one-pager': [
    PROBLEM,
    WHY_NOW,
    TARGET_USER,
    {
      key: 'Proposed approach',
      kind: 'para',
      required: true,
      criteria: [],
      description: '高層次方案（2–4 句，no mocks）',
      hint: '2–4 句。說明做什麼、不說怎麼做（no class names / routes / APIs）。\n用產品語言：「讓使用者可以 X」而不是「新增一個 cubit 叫 Y」。\n禁：mocks / wireframes、implementation detail、超過 4 句的長篇。',
    },
    ACCEPTANCE_CRITERIA,
    SUCCESS_METRIC,
    NON_GOALS,
    PRODUCT_LEVEL_RISK,
    REVISION_HISTORY,
  ],

  'prd': [
    PROBLEM,
    WHY_NOW,
    TARGET_USER,
    {
      key: 'User stories',
      kind: 'bullets',
      required: true,
      criteria: [],
      description: 'As a <persona>, I want <action> so that <outcome>',
      hint: '格式（verbatim）：As a <persona>, I want to <action> so that <outcome>。\n每條故事對應一個具體使用場景；3–8 條為佳。\n禁：engineering persona（"As a developer…"）、outcome 含工程語彙、超過 10 條（代表 scope 失控）。',
    },
    {
      key: 'Proposed approach',
      kind: 'para',
      required: true,
      criteria: [],
      description: '高層次方案（high-level，no mocks）',
      hint: '比 one-pager 更詳細，但仍限產品層面。說明核心機制（使用者看到什麼 + 怎麼運作的 mental model），不說 implementation。\n禁：class names / file paths / API names、mocks / wireframes。',
    },
    {
      key: 'Solution sketch',
      kind: 'para',
      required: true,
      criteria: [],
      description: '方案在產品層面的具體呈現（no mocks）',
      hint: '說明方案在使用者操作流程中如何呈現：入口、主要互動、成功狀態。\n仍在產品層面——不是 wireframe，不是 API 設計。\n若有多個 option，列出每個的 trade-off。',
    },
    ACCEPTANCE_CRITERIA,
    SUCCESS_METRIC,
    NON_GOALS,
    {
      key: 'Rollout plan',
      kind: 'para',
      required: true,
      criteria: [],
      description: '分階段 release + audience + kill-switch',
      hint: '說明：第一批 audience（內部 / TestFlight / 全量）、分階段條件（metric threshold → 下一階段）、kill-switch / feature flag 策略。\n禁：「全量 release」作為唯一計畫、沒有 kill-switch 策略。',
    },
    {
      key: 'Dependencies',
      kind: 'bullets',
      required: true,
      criteria: [],
      description: '功能 / 合作方 / 平台能力依賴',
      hint: '列出：其他 feature（需先完成 X）、平台版本 / API（需要 iOS X.X+）、第三方依賴。\n每條標明：blocking（必須先到位）或 nice-to-have（不到位的降級方案）。\n若無依賴，明確寫「無外部依賴」。',
    },
    {
      key: 'Instrumentation',
      kind: 'bullets',
      required: true,
      criteria: [],
      description: '指標如何量測（events / metrics 告訴我們 outcome 在移動）',
      hint: '列出：哪些 analytics event 對應 success metric 的移動、怎麼知道 feature 被使用了、怎麼知道它有效。\n不用列所有 event——只列回答 success metric 的那幾個。\n禁：「使用現有埋點就夠了」作為唯一回答（需具體說明）。',
    },
    PRODUCT_LEVEL_RISK,
    REVISION_HISTORY,
  ],

  'prfaq': [
    {
      key: 'Press release',
      kind: 'raw',
      required: true,
      criteria: [],
      description: '假設已上線的發佈稿（title / subtitle / body / reader quote / how to use）',
      hint: '結構（verbatim）：\n  [Title — what we\'d announce]\n  [Subtitle — user benefit in one line]\n  [Body — 3–4 paragraphs as if it shipped today]\n  [Quote from a reader]\n  [How to use it]\n以「它已經 ship 了」的語氣寫。目的是用 launch story 倒逼澄清 scope 和 value。\n禁：工程語彙、功能清單代替 narrative、超過 6 段。',
    },
    {
      key: 'Internal FAQ',
      kind: 'bullets',
      required: true,
      criteria: [],
      description: '團隊內部會問的問題（problem / why / metric / non-goals / risks）',
      hint: '格式：Q: <問題>  A: <具體回答>。\n必涵蓋：\n  - 我們在解決什麼問題、對誰？\n  - 為什麼現在做？\n  - success metric 是什麼，threshold 是多少，什麼情況下 double down vs kill？\n  - v1 不做什麼？\n  - 我們最沒把握的信念是什麼（impact × 不確定性最高，不是最難做的部分）？打算怎麼低成本驗證？\n  - 什麼可能出錯？',
    },
    {
      key: 'External FAQ',
      kind: 'bullets',
      required: true,
      criteria: [],
      description: '使用者會問的問題（how to use / cost / privacy / locale+a11y）',
      hint: '格式：Q: <問題>  A: <具體回答>。\n必涵蓋：\n  - 怎麼用？\n  - 要付費嗎？離線可用嗎？\n  - 我的隱私怎麼處理？\n  - Reader-specific：語言支援（en/ja/zh/zh_Hans/zh_Hant）、直書、無障礙功能。',
    },
  ],

  'strategy': [
    {
      key: 'Diagnosis',
      kind: 'para',
      required: true,
      criteria: [],
      description: '現況診斷：實際發生什麼事、挑戰是什麼',
      hint: '描述現實狀況（不是解法）：問題的本質、影響範圍、為什麼現有方法無法解決。\n名稱問題，不是解法。Rumelt 的診斷是「命名複雜情況中的關鍵點」——不是 symptom list。\n禁：直接跳進解法、使用 "we should" 開頭。',
    },
    {
      key: 'Guiding policy',
      kind: 'para',
      required: true,
      criteria: [],
      description: '面對這個挑戰的整體方針',
      hint: '一段，說明應對這個診斷的 overall approach——不是行動計畫，是「我們選擇用什麼角度切入」。\n一個好的 guiding policy 會排除部分選項（說明什麼不做）同時為 coherent actions 提供方向。\n禁：空洞的「以使用者為中心」、多個互相矛盾的方針。',
    },
    {
      key: 'Coherent actions',
      kind: 'bullets',
      required: true,
      criteria: [],
      description: '實踐 guiding policy 的具體行動（含明確的 non-actions）',
      hint: '列出 3–6 個具體、相互一致的行動。每條動詞開頭，說明做什麼 + 為什麼（如何落實 guiding policy）。\n至少一條明確的「我們不做 X」——coherent actions 的一致性需要明確排除。\n禁：和 guiding policy 不一致的行動、太抽象的「改善 X」。',
    },
  ],

  'roadmap': [
    {
      key: 'Now',
      kind: 'raw',
      required: true,
      criteria: [],
      description: '這個 cycle 的 outcome + features（以 outcome 為主題）',
      hint: '結構：\n  **Hypothesis:** <一行，我們相信 X 會帶來 Y>\n  **Success metric:** <一行>\n  - Feature example: ...\n  - Feature example: ...\nFeatures 是示例，不是承諾。主題是 outcome，不是功能清單。\n禁：日期 / 季度作為主要結構、features 沒有對應 outcome hypothesis。',
    },
    {
      key: 'Next',
      kind: 'raw',
      required: true,
      criteria: [],
      description: '這個季度的 outcome + features',
      hint: '同 Now 結構。比 Now 更模糊是正常的——這是方向，不是承諾。\nFeatures 以「例如：」或「可能包括：」標示，強調探索性。',
    },
    {
      key: 'Later',
      kind: 'raw',
      required: true,
      criteria: [],
      description: 'Someday-maybe outcomes（探索性，不承諾）',
      hint: '同 Now 結構，但更粗糙。這個 bucket 可以放「如果 Now 的假設成立，下一個大賭注是什麼」。\n不要在這裡放「一定要做」的事——那應該是 Now 或 Next。',
    },
  ],

  'opportunity-tree': [
    {
      key: 'Desired outcome',
      kind: 'para',
      required: true,
      criteria: [],
      description: '單一 metric（OST 的 root）',
      hint: '一個可量測的 outcome，作為整棵樹的 root。這是北極星——所有 opportunity 都要對應這個 outcome。\n禁：多個 outcome、無法量測的目標、proxy metric 沒說明為什麼是好的 proxy。',
    },
    {
      key: 'Opportunity Solution Tree',
      kind: 'raw',
      required: true,
      criteria: [],
      description: 'OST 樹狀結構（outcome → opportunities → solutions → experiments）',
      hint: '用縮排 tree 格式：\n  Desired outcome\n  ├── Opportunity A（user pain/desire + evidence）\n  │   ├── Solution A1（experiment to test）\n  │   └── Solution A2\n  └── Opportunity B\n      └── Solution B1\nOpportunity 要有 evidence（觀察、訪談、data）。Solution 要是可以 test 的實驗。\n禁：把 solutions 直接連到 outcome（跳過 opportunity 層）、opportunity 沒有 evidence。',
    },
  ],

  'discovery-brief': [
    {
      key: 'What we wanted to learn',
      kind: 'para',
      required: true,
      criteria: [],
      description: '原始問題（discovery 開始時想釐清的事）',
      hint: '一段，說明 discovery 開始時的問題。應該是可以被 confirmed 或 killed 的假設形式。\n禁：問題太模糊（「了解使用者需求」）、事後倒推的問題。',
    },
    {
      key: 'What we did',
      kind: 'para',
      required: true,
      criteria: [],
      description: '具體的 discovery 活動（conversations / instrumentation / reviews）',
      hint: '說明：做了哪些訪談（幾人、哪個 persona）、看了哪些 analytics（哪段時間、哪個 event）、讀了什麼（App Store reviews、競品評測）。\n具體數字。禁：「做了一些研究」、活動沒有對應的 learnings。',
    },
    {
      key: 'What we learned',
      kind: 'bullets',
      required: true,
      criteria: [],
      description: '具體 findings（含 quotes / data points）',
      hint: '每條：<finding>（支持 evidence：quote / data point）。\n區分事實（data 說的）和 inference（我們的解讀）。\n禁：純解讀沒有 evidence、finding 太模糊（「使用者喜歡這個功能」）。',
    },
    {
      key: 'Hypotheses confirmed / killed',
      kind: 'bullets',
      required: true,
      criteria: [],
      description: '每個原始假設的裁決（confirmed / killed / inconclusive）',
      hint: '每條格式：<hypothesis> → confirmed / killed / inconclusive（原因一句）。\n每個 "What we wanted to learn" 的假設都要對應一條裁決。\n禁：留空、inconclusive 沒有說明為什麼和下一步怎麼辦。',
    },
    {
      key: 'Next step',
      kind: 'para',
      required: true,
      criteria: [],
      description: '一個具體的下一步行動',
      hint: '一條具體的 next move：另一個小實驗 / one-pager / 做出 MVP 測試。\n禁：「繼續研究」、「等待更多數據」（不夠具體）、多個並行的 next step（太多代表沒做決定）。',
    },
  ],

};
