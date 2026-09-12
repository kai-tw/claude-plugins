# Style rules — 維護慣例（review 子系統）

`Read` 本檔只在新增 / 修改 / 合併 / 刪除 style rule 時。

**這是什麼.** `code-reviewer` 的撰寫法規則庫（唯一讀者），組織成**母規則（`index.md`，
語言與專案中立）+ 語言層 sub-check（`dart.md` / `js.md`）**兩層。收的是 founder 手抓
得到、linter 抓不到的撰寫判斷——它們一旦不在規則裡，`code-reviewer` 依 Kind 3
「taste or style with no rule behind it」被要求放過，所以**立法是唯一入口**。

**位階與牴觸.** 唯一版本寫在 `index.md §位階`。本檔只重申一件事：**沒有豁免條款**。
牴觸只有三個結局（母規則收窄 / 母規則廢除 / 專案改 code），全部是修法。

**入憲判準（母規則放哪的唯一出口）.** 一條規則入 `index.md` 的條件是**在所有語言下都
成立**。「這條在 JS 下不成立」不是例外，是它不該入憲的證明——下移到語言檔。

**入庫條件（先過這關再談格式）.**
- **formatter / linter 抓得到的不收.** 它屬 `analysis_options.yaml` / eslint 設定；
  `code-reviewer.md §Rule surface` 明令不重推 lint 已決定的事，收進來只是把判斷預算
  花在機械題上。
- **寫不出 `Check:` 的不收.** 旁觀者查不動的那條是偏好不是規則
  （`.claude/rules/writing-rules.md`）。
- **可機械判定但尚無規則的，去寫 lint 規則，不要寫成散文.** 去處是專案的 lint 規則庫
  （Dart：`dart_lints` 的對應 bundle），那裡是確定性的、而且在編輯時就到得了作者。
  推論：`dart.md` / `js.md` 長期會接近空的——語言層的可判定項幾乎都該是 lint 規則，
  這不是漏收，是分工。

**檔案格式.**
- 母規則：`index.md` 一節一條 —— `## S<N> — <title>` + `**Principle:**` 通則 1–2 句，
  後接該母規則**跨語言成立**的 sub-check，一條一 bullet：
  `- **S<N>.k <名>** — Check: <一行判準>. Example: <≤1 句>`。
  母規則與其 sub-check 都**不帶語言**：出現語言關鍵字、framework 名或副檔名即屬語言層。
- 語言層：`dart.md` / `js.md` 同格式，編號帶後綴 `S<N>.k-dart`，只放**該語言才有**的
  具體化。
- **每條語言 sub-check 必須掛在一個既有 `S<N>` 底下.** 掛不上就是要修憲：先在
  `index.md` 立母規則，再掛。語言檔不得自立母規則。
- **為何不是單一檔**（與 security / ux 那幾包不同）：語言層是兩份**按 diff 副檔名擇一
  載入**的檔，不是同一份規則的第二份拷貝——沒有需要同步的重複內容。

**learning 更新法.**
1. 先查 `index.md` 是否已有可掛的母規則。
2. 有 → 加一條語言 sub-check 到對應語言檔（或擴充既有條的 `Check:`，不新增項）。
3. 無 → 先在 `index.md` 立母規則（過入憲判準），再掛。
4. 牴觸 → 按 `index.md §位階` 的三個結局修法，不加例外。
5. 過時的條目直接刪除，不留「已退役」殘影（歷史在 git）。
