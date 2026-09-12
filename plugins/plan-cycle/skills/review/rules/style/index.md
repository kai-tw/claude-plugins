# Style rules — 撰寫法母規則（語言與專案中立）

`code-reviewer` 的 Kind 1 規則面之一：**母規則在本檔，語言層在 `dart.md` / `js.md`**
（按 diff 的副檔名擇一載入）。收的是 linter 抓不到、founder 會手抓的撰寫判斷。

**判定模式.** 本包**不自訂級別**——違規由 `code-reviewer` 依其 §Severity 提級、
`code-review-verifier` 裁定。某條需要級別下限時，寫在該條的 `Check:` 裡
（例：`違規一律 proposed CRITICAL`）。

## 位階

三層，上位優先。**這是位階規則的唯一版本**，其他檔一律引用本節。

| 位階 | 檔案 | 收什麼 | 權限 |
|---|---|---|---|
| 憲法 | 本檔 `S<N>` | 所有語言、所有專案都成立的通則 | 唯一能立母規則的地方 |
| 法律 | `dart.md` · `js.md` | 該語言的具體判準，每條掛一個 `S<N>` | 只能把母規則**具體化** |
| 命令 | 專案 `.claude/rules/` | 該專案的事實（自家 helper 名、canonical entry point、路徑） | 只能**加嚴**或**填事實** |

**牴觸判準.** 兩條**能不能同時滿足**？能 → 合法疊加；不能 → 牴觸。

**沒有豁免條款.** 牴觸只有三個結局，全部是修法：母規則收窄（加條件，或下移到語言層）·
母規則廢除 · 專案改 code。自授例外是 valid finding 在被提出前就死掉的標準路徑
（`code-reviewer.md` 開頭的 as-written 條款）。

**審查中撞到牴觸怎麼辦.** 該條判 **`無法判定`**（`references/evidence.md`）+ 指名由誰
修法（哪個檔、誰改），並開 ledger（`plan-feedback add code-review`）。不是 `passed`，
也不是拿作者開刀的 `critical`。

**舉證要求.** 主張牴觸要**引兩條規則原文 + 說明為何不能同時滿足**。「這條在這裡不好
用」是不方便、不是牴觸——當次照上位規則判，另開修法。

## 母規則

**語言檔為空不代表該語言沒規則**——母規則照樣適用。反之，本檔沒立法的撰寫偏好，
`code-reviewer` **不得自行發明成 style finding**：沒有條文不等於交由自由心證。

## S1 — 層級歸屬

**Principle:** 一段邏輯屬於哪一層，由它依賴什麼知識決定，不由它放在哪個目錄決定——
linter 查得到 import 方向，查不到歸屬。

- **S1.1 目錄不等於歸屬** — Check: diff 新增 / 移動的檔案，其內容依賴的知識與所在層
  一致（`domain/` 內不出現傳輸格式、HTTP 狀態碼、DB 欄位名、UI 語彙）；不一致 →
  搬層或改寫，不是加註解。Example: 放在 `domain/` 的 use case 在做 HTTP 狀態碼轉譯。
- **S1.2 穿越邊界的是 domain 型別** — Check: repository / use case 的簽章回傳 domain
  型別，而非「以 domain 命名的傳輸結構」（欄位與外部 payload 一對一，或帶 raw / json /
  code 之類欄位即是）。型別合法，所以 linter 全綠。Example: `XRepository.fetch()` 的
  回傳物件欄位對得上 API response。
- **S1.3 orchestration 只在組裝點** — Check: 跨 repository 的順序 / 重試 / fallback
  只出現在專案宣告的組裝點（**組裝點放哪是專案事實**，屬命令層）；use case 內只有一個
  domain 決策。Example: use case 依序呼叫兩個 repository，失敗時改走另一條。
