# Style rules — 立法程序與體例（review 子系統）

`Read` 本檔，限於新增、修改、合併或刪除 style rule 之時。

**本包為何.** `code-reviewer` 之撰寫法規則庫（唯一讀者），分二層：**母規則（`index.md`，
語言與專案中立）**，及**語言層 sub-check（`dart.md` / `js.md`）**。所收者，為 founder
手抓得到、而 linter 稽核不到之撰寫判斷——該等判斷一旦不在規則之內，`code-reviewer` 依
Kind 3「taste or style with no rule behind it」即被要求放行，故**立法為唯一入口**。

**位階與牴觸.** 唯一版本載於 `index.md §位階`。本檔僅重申一事：**無豁免條款**。牴觸僅有
三種結局（母規則收窄／母規則廢除／專案改 code），全屬修法。

**母法不引外部.** `index.md` 為母法，其條文僅得引本系統之內的東西（下位法、其他條次）。
審查器名稱、lint 規則名、ledger 指令、證據檔路徑一律不得出現於該檔——母法若須靠外部
檔案才讀得完整，該檔一改，母法即失效。程序性的落地細節寫在本檔：牴觸判 `無法判定` 時，
其證據格式見 `../../references/evidence.md`，並以 `plan-feedback add code-review` 開
ledger。同理，某條之範圍若因 lint 已涵蓋而收窄，條文只寫**它自己管什麼**，不寫「另一半
由誰擋下」——那是入庫要件（見下）的效果，不是條文的內容。

**入憲要件（母規則置於何處之唯一出口）.** 一條規則入 `index.md` 之要件，為**於所有語言
下均成立**。「本條於 JS 下不成立」非屬例外，乃其不應入憲之證明——應下移至語言檔。

**入庫要件（先過本關，再論體例）.**
- **formatter / linter 稽核得到者，不收.** 其歸屬為 `analysis_options.yaml` / eslint
  設定；`code-reviewer.md §Rule surface` 明令不重推 lint 已決之事，收入本包僅係將判斷
  預算耗於機械題。
- **寫不出 `Check:` 者，不收.** 旁觀者查不動之條，係偏好而非規則
  （`.claude/rules/writing-rules.md`）。
- **可機械判定而尚無規則者，應往寫 lint 規則，不得寫為散文.** 其去處為專案之 lint 規則
  庫（Dart：`dart_lints` 之對應 bundle），該處係確定性的，且於編輯時即達於作者。
  推論：`dart.md` / `js.md` 長期將趨近於空——語言層之可判定項幾乎均應為 lint 規則，
  此非漏收，乃分工。

**體例.**
- 母規則：`index.md` 一節一條 —— `## S<N> — <title>` + `**Principle:**` 通則一至二句，
  後接該母規則**跨語言成立**之 sub-check，一條一 bullet：
  `- **S<N>.k <名>** — Check: <一行判準>. Example: <≤1 句>`。
  母規則與其 sub-check 均**不帶語言**：出現語言關鍵字、framework 名或副檔名者，即屬
  語言層。
- 語言層：`dart.md` / `js.md` 同體例，編號帶後綴 `S<N>.k-dart`，僅置**該語言特有**之
  具體化。
- **每條語言 sub-check 應掛於一既有 `S<N>` 之下.** 掛不上者即應修憲：先於 `index.md`
  立母規則，再掛。語言檔不得自立母規則。
- **用詞一律台灣用語、法律用詞.** 禁止用「不得」，義務用「應」，容許用「得」；條件句
  用「…者，…」，排除用「不在本條之列」；主體稱「本條」。
- **技術術語有限度地保留英文.** 已是工作語彙者直接用原文，不另造中譯——`catch` /
  `throw` / `rethrow` / `propagate` / `predicate` / `callback` / `timeout` / `mutex` /
  `cache` / `eviction policy` / `stack trace` / `hot path` / `log level` / `null` /
  `enum` / `sealed` / `domain` / `repository` 皆屬之。**自創中譯與冷僻行話同為違規**：
  前者（「述詞」「淘汰策略」「最上層處理器」）令讀者須反推原文，後者（`arm`）令讀者無從
  反推。行話應改用日常詞（`arm` → 分支），中譯則應還原為原文。判準只有一個：**讀者能否
  一眼認出所指之物**。
- **何以不採單一檔**（與 security / ux 諸包不同）：語言層係二份**按 diff 副檔名擇一
  載入**之檔，非同一份規則之第二份拷貝——無須同步之重複內容並不存在。

**learning 更新程序.**
1. 先查 `index.md` 有無可掛之母規則。
2. 有者 → 增一條語言 sub-check 於對應語言檔（或擴充既有條之 `Check:`，不新增項）。
3. 無者 → 先於 `index.md` 立母規則（應過入憲要件），再掛。
4. 牴觸者 → 依 `index.md §位階` 之三種結局修法，不得加例外條款。
5. 過時之條目，逕予刪除，不留「已退役」殘影（歷史在 git）。
