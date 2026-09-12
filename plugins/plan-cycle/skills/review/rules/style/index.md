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

目前 **0 條**。

**空包時 `code-reviewer` 的行為**：Kind 1 只走專案 `.claude/rules/`，**不得自行發明
style finding**——本包空著代表這類規則尚未立法，不代表交由 reviewer 自由心證。
