# Privacy rules — minimization checklist

`security-privacy-reviewer` 對 **diff + 商店宣告**逐軸 → 逐 check 對照本清單旁觀審查
（player ≠ referee）：每個 check 逐項判 **passed / warning / critical**。

**計畫不審。** 下面每一條 check 都錨在 collection-site `file:line` 或 log 樣板上，計畫沒有
這些東西。「這個欄位該不該收」是計畫期的產品決策，由 `pm-plan-reviewer` 走 PM 規則 `P8`；
「收了之後有沒有收得安全」才是這裡。

`critical` 擋到解決為止；`warning` 不觸發下一輪，套用 fix 或記一行 accepted debt
（`plan/SKILL.md §Gate loop policy` —— 這道 gate 在 ② 層，一次 + 一次驗證，禁 loop-to-green）。
本檔即完整基線（母規則 + sub-check + Example 同檔），沒有另外的細節檔；維護慣例 + 三級判定見 `CONVENTIONS.md`。

每個 finding 錨定 collection-site `file:line` + 明列欄位（無「user context」籠統詞）。

## 這份是基線，專案要疊加自己的

五軸（Purpose / Necessity / Retention / Sensitivity / Attestation）源自 GDPR 原則，
**任何 app 都適用**，所以整份基線可直接用。專案要疊加的不是新的軸，而是**兩份自己的
事實表**，缺了它們 P4 與 P5 無法判定：

- **Sensitivity Tier 對照表** —— 這個 app 的哪些欄位屬 PII / 準識別碼 / 內容衍生。
  基線給的是類別定義，不是你的欄位。
- **Retention 對照表** —— 各 sink 的實際保存期（後端政策、SDK 預設、雲端由使用者控制）。

兩者放 `.claude/rules/privacy.md`。判斷歸屬同 security：**換一個 app 還成立嗎？**
成立留基線，不成立進疊加層。專案沒有疊加層時，P4／P5 標為**無法判定**並在報告開頭
明說 —— 不要拿別的 app 的 tier 表硬套。

## P1 — Purpose（GDPR 5(1)(b)）

**Principle:** 每個離開裝置的 user-derived 欄位都要有單一、outcome-bound、可追溯到核准
plan / spec 的 purpose；「之後可能有用」不是 purpose。

- **P1.1 site 錨定 + 欄位明列** — Check: collection-site 有 `file:line`、蒐集欄位逐一列出
  （無「user context」「request body」籠統詞）？無法定位 / 籠統 → warning（先補齊才能審）。
  Example: 「上傳 request body」沒列實際欄位。
- **P1.2 purpose 追溯核准 plan / spec** — Check: 此蒐集對得上某條核准的 product plan /
  design spec 段落？無對應 → critical（未授權蒐集）。
  Example: 新增一個 analytics event，但 plan 沒有對應的 outcome / 量測需求。
- **P1.3 outcome-bound** — Check: purpose 綁具體 outcome，而非「之後可能有用 / 先收著」？
  might-be-useful-later → critical。
  Example: 「先記錄完整 reading-session 物件，未來分析用」。
- **P1.4 purpose current** — Check: 對應 feature 仍在線上（非 legacy / dead code 殘留的
  蒐集）？下架仍蒐集 → critical（移除 sink）。
- **P1.5 單一 purpose** — Check: 欄位未被靜默重用於原 purpose 以外的目的？一欄多用且未各自
  授權 → warning（拆分 / 各自授權）。

## P2 — Necessity / 最小化（GDPR 5(1)(c)）

**Principle:** 只蒐集達成 outcome「拿不掉」的最小資料，且以最低識別度形式蒐集。

- **P2.1 拿掉會破壞 outcome** — Check: 移除此欄位會明確打破已記錄 outcome？拿得掉卻收 →
  critical（移除）。Example: outcome 只需「是否用過某功能」卻收逐次輸入內容。
- **P2.2 無更低識別度替代** — Check: 有沒有更低識別度形式滿足 purpose（boolean 取代
  timestamp、bucket 取代 raw、hash 取代 cleartext、count 取代 list）？可降未降 → warning；
  欄位屬敏感 → critical。Example: 收 raw 時間戳但 outcome 只需「當日是否活躍」。
- **P2.3 egress 前 client-side 聚合** — Check: 能不能在離開裝置前先聚合 / 去識別？可聚合卻
  傳明細 → warning。
- **P2.4 sampling 有據** — Check: sampling rate 有理由（100% 僅在必要）？無據全量 → warning。
- **P2.5 非重複 sink** — Check: 此訊號是否已有另一 sink 在載？重複蒐集 → warning（去重）。
- **P2.6 log template 已 vet** — Check: log 樣板無 `LogSystem.error('failed for $userInput')`
  式字串插值 PII 滲漏？有插值帶 user 資料 → critical。Example: 把使用者輸入的標題 / 檔路徑插進 error log。

## P3 — Retention（GDPR 5(1)(e) / MASVS-PRIVACY-3）

**Principle:** 保留期不得超過 purpose 生命週期；可識別資料要有明確上限與清除路徑。

- **P3.1 sink 預設保留期具名** — Check: 此 sink 的預設保留期有寫明（Crashlytics ~90d、
  典型：analytics 依 config 14m–indefinite、performance ~60d、使用者控制的雲端儲存、local
  device-lifetime）？未具名 → warning（先查明）。
- **P3.2 保留 ≤ purpose lifetime** — Check: 保留期 ≤ purpose 所需？超出 → warning；敏感資料
  超出 → critical。
- **P3.3 user 刪除確實清除** — Check: user 主動刪除會真的從此 sink 清掉（或記錄為何不能，如
  Crashlytics aggregate）？宣稱可刪實際殘留 → critical。
- **P3.4 暫態不過 session** — Check: 暫態診斷資料不持久過 session（session scope 足夠時）？
  無謂持久化 → warning。
- **P3.5 local cache TTL** — Check: 可識別資料的 local cache 有 TTL？無限期快取可識別資料 →
  warning。

## P4 — Sensitivity Tier

**Principle:** 每個欄位明確指派敏感度層級，並以最壞合理假設處理 free-form 與穩定識別碼；
組合風險要評估。

| Tier | 通用範例（專案在疊加層列自己的欄位） |
|---|---|
| **anonymous** | 聚合計數、server 端 bucketed 指標 |
| **technical** | OS 版本、app 版本、device model、locale code |
| **behavioral** | 開了哪個項目、停留時長、主題切換、用了某功能、觸發同步 |
| **quasi-identifier** | locale + timezone + screen size 組合、install ID、Firebase Installation ID |
| **PII** | 後端 user id、email、雲端帳號、OAuth token、廣告／裝置識別碼 |
| **sensitive PII** | 使用者建立的內容與註記、私有紀錄的標題（可揭露宗教 / 政治 / 健康 / 性向 / 財務 / 人際關係）、搜尋詞、選取文字 |

- **P4.1 tier 明確** — Check: 每欄位明確指派 tier（無 TBD）？未指派 → warning（先指派才能審）。
- **P4.2 combination risk** — Check: 評估過 anonymous + anonymous → quasi-identifier（timezone
  + locale + screen + OS → 近乎唯一）？未評估的組合 → warning。
- **P4.3 free-form = sensitive** — Check: free-form user text（標題 / 檔名 / 筆記 / 備註）預設當
  sensitive PII？無證據就降級 → critical。Example: 把使用者輸入的標題當「technical metadata」上傳。
- **P4.4 stable id 標記 + 佐證** — Check: stable identifier（後端 user id / install ID /
  ad ID）單獨標記並佐證必要性？未標 / 無據 → critical。
- **P4.5 使用行為 = behavioral** — Check: 使用行為欄位預設認列 behavioral PII（不
  靜默降為 technical）？降級 → warning。

## P5 — Attestation Match（Play Data Safety + App Store Privacy）

**Principle:** 程式實際蒐集必須與商店隱私聲明逐項相符；謊報、漏報分享、或「不蒐集」宣稱
未經全 sink 驗證，都是合規與信任風險。逐 check 判 passed / warning / critical、迴圈至全
passed。

- **P5.1 Play 表涵蓋** — Check: 此欄位出現在當前 Play Data Safety 表？漏報 → warning（補）。
- **P5.2 App Privacy 涵蓋** — Check: 此欄位出現在當前 App Privacy nutrition label？漏報 →
  warning。
- **P5.3 purpose 相符** — Check: 表上宣告的 purpose 與 code purpose 相符？謊報 → critical。
- **P5.4 第三方分享屬實** — Check: 「分享給第三方」反映 SDK 現實（Firebase → Google、
  Crashlytics → Google…）？漏報分享 → critical。
- **P5.5 linked-to-user 屬實** — Check: 「linked to user」與此 sink 是否附 stable id 相符？
  不符 → warning。
- **P5.6 not-collected 全 sink 驗證** — Check: 「Data not collected」宣稱經**全 sink** grep
  驗證（非只改動處）？某 sink 仍收卻宣稱不收 → critical。
- **P5.7 optional toggle 屬實** — Check: 表上 optional / required 反映 app 內真實的 user
  控制？宣稱 optional 但無對應控制 → warning。

## P6 — 跨切面 meta（每次 review 一次）

**Principle:** 有些最小化風險不屬單一欄位，而屬整體設定 —— 第三方 SDK 預設遙測、權限、
log 層 PII scrub。每次 review 跑一遍（非每 finding）。

- **P6.1 SDK 預設遙測盤點** — Check: 第三方 SDK 預設遙測已盤點（Firebase 不論程式都 phone
  home）？標明哪些自動蒐集、是否 `setAnalyticsCollectionEnabled(false)` gated 到 consent？
  未盤點 / consent 前就開蒐集 → critical。
- **P6.2 權限逐平台佐證** — Check: 每個權限請求逐平台佐證（無 feature 不嚴格需要的權限）？
  多餘權限 → critical（移除）。
- **P6.3 log-template 層 scrub** — Check: PII 在 log-template 層以 allowlist scrub，而非靠
  per-callsite runtime sanitisation？靠逐點手動 sanitise → warning（改 allowlist）。
