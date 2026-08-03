# Security rules — threat-model baseline

目標 **OWASP MASVS L1**（消費級 app）。`security-reviewer` 對審查對象（**PM plan
功能機制攻擊面 + engineer plan threat model + code**）**逐母規則 → 逐 threat** 對照本
清單旁觀審查（player ≠ referee，禁實作者自審）：每個 threat 逐項問「目前是否已防禦?」→
標 **passed / warning / critical** → 所有 warning / critical 回報 engineer / 實作者修正
→ 迴圈重審，**直到所有 threat = passed** 才放行。禁 deferred & dismiss。

## 這份是基線，不是全部 —— 專案要疊加自己的

本檔只收**任何 Flutter app 都成立**的 threat。它刻意**不完整**：一個 app 真正被打穿的
地方通常在它獨有的攻擊面（吃使用者檔案、跑 WebView、接特定雲端服務、處理支付），那些
不在這裡。

**專案在 `.claude/rules/security.md` 疊加自己的目錄**，格式與本檔相同（母規則 → threat
sub-check → 三級判定）。`security-reviewer` **兩份都 grade**：先基線、再疊加層。

判斷一條 threat 該放哪，只問一個問題：

> **換一個 Flutter 專案，這條還成立嗎？**

成立 → 屬基線，回報上游改這裡。不成立（點名了某個檔案格式、某個 SDK、某條自家程式
路徑）→ 專案疊加層。**寧可放疊加層** —— 基線混進專案特例，會讓其他專案的審查瞄準不
存在的攻擊面，同時漏掉真正存在的。

專案沒有疊加層時：基線照跑，但在報告開頭**明說疊加層不存在**，不要當成「已完整審查」。

本檔即完整基線（母規則 + sub-check + Example 同檔），沒有另外的細節檔；維護慣例 + 三級
判定模式見 `CONVENTIONS.md`。

## P1 — 內容解析是 app 最大攻擊面，每個解析 sink 都是 trust boundary

**Principle:** 任何**非本 app 產生**的 bytes 都是 untrusted input —— 使用者選的檔案、
runtime 下載的資產、後端回應、雲端鏡像的 DTO。把它們餵進**會執行或解析**的 sink
（WebView、封存檔解壓、字型／XML／圖片 parser、DTO `toDomain`）就跨越 trust boundary，
必須在**邊界**（不是 per-callsite）做隔離 / 正規化 / 上限 / 校驗。
STRIDE：Tampering + DoS + Elevation of Privilege。

下面每條都是條件式 —— 專案沒有那個 sink 就標 N/A，**不要**為不存在的攻擊面編造
finding。專案獨有的格式或服務（某種文件格式、某個內容 SDK）掛在
`.claude/rules/security.md` 疊加層。

每個 threat 逐項判 **passed / warning / critical**，未 passed 回報 engineer / 實作者
修正，迴圈至全 passed。

- **P1.1 不受信任內容 → WebView 逃逸** — Check: 專案若在 WebView 載入非自產內容
  （使用者檔案、遠端 HTML、第三方嵌入），該內容是否載入 null-origin sandboxed iframe
  （或獨立受控 origin）+ 嚴格 CSP（`default-src 'self'; connect-src 'none';
  frame-src 'none'`）、JS bridge 只綁 shell document、每個 JS→Flutter message 在
  dispatch 處校驗？內容與 shell 同 origin / 有 bridge 存取 / 無 CSP → **critical**。
  Example: SVG/XML/JS payload 從 content sandbox 穿進 bridge 或 host。
- **P1.2 Zip-slip / zip-bomb / 解析資源耗盡** — Check: 專案若解壓使用者提供或遠端下載
  的封存檔，是否集中於單一 audited helper，每個 entry 做 canonical-path check
  (`canonical(dest/entry).startsWith(canonical(dest)+separator)`)、拒 `..` / 絕對路徑 /
  symlink / Windows device name / NUL，且 cap 總解壓量 / per-entry size / 壓縮比
  (>100×) / entry 數？逐 callsite 自寫解壓、無路徑檢查、無上限 → **critical**。
  Example: callsite-local extraction helper 直接 `ZipEntry.getName()` 寫檔。
- **P1.3 下載資產經未強制 HTTPS 通道餵進 code-shaped parser** — Check: runtime 下載且
  **後續被 parser / loader 解析或執行**的 bytes，HTTP 邊界（共用的 http client /
  download primitive）是否拒非 `https` scheme、redirect 後重驗 scheme、cap size，平台
  transport policy 同步收緊（Android `cleartextTrafficPermitted="false"`；iOS 去
  `NSAllowsArbitraryLoads`）？硬編 `https://` 當「已強制」其實只是「當前值」、無 scheme
  檢查 → **warning**（同 sink 已有更大 untrusted hole 時降級；pinning 由 reachability +
  proportionality 決定，非一律 pin）。Example: 字型從遠端下載進 `FontLoader.load`，
  下載函式無 scheme 強制、平台允許 cleartext。
- **P1.4 反序列化邊界缺數值範圍校驗** — Check: 從 partially-trusted
  來源 round-trip 的數值欄位（timestamp / logical clock / version / sequence /
  priority），若會進入 downstream「compare and bigger wins」決策
  (`a>b`、`Comparable.compareTo`、`SplayTreeMap`、`max(...)`)，DTO `toDomain` 是否在
  邊界 clamp/reject（time-shaped: `> now()+skewBudget` 拒；counter-shaped: 超真實
  producer 上限拒；**reject 不靜默 clamp**；一個 validator 全 DTO 繼承）？兩側信號
  （DTO 收 + downstream 比較）齊備卻無 bounds check → **critical**。Example: 偽造
  `physicalMs: Int64.max-1` 的 HLC row 永遠贏過未來每次衝突。
- **P1.5 反序列化邊界缺 presence-bit 校驗** — Check: 從
  cloud-mirrored / 可外部編輯 DTO 來的 nullable / boolean presence 欄位（tombstone /
  soft-delete / `archivedAt` / `hiddenAt` / visibility flag），若被 read-side 以裸
  null-check / boolean test 當 UI 可見性 gate，DTO `toDomain` 是否 (a) 校驗 bit 內容
  （range / provenance / 生命週期一致，如 tombstone HLC 不得早於 creation HLC）**且**
  (b) 配一個 diagnostic surface 顯示「何項被誰於何時隱藏」？兩側信號齊備卻只信 bit、
  無校驗或無 diagnostic → **critical**（兩層缺一即未消除：通過校驗的偽造 tombstone 仍
  能靜默隱藏）。Example: cloud 端偽造 `removedHlc` 丟到合法 row，下次 sync 靜默隱藏該
  row，無錯誤訊息、無 telemetry、無復原路徑。

## P2 — 憑證與後端設定最小權限、機密不外洩、enforcement 在 server 端

**Principle:** OAuth token、雲端儲存 scope、後端設定都遵守最小權限：token 只進
平台安全儲存且從不入 log / bridge、scope 收到剛好夠用、安全 enforcement 落在
**server-side rules** 而非 client（client 端 config 是公開識別碼）。
STRIDE：Spoofing + Information Disclosure。

每個 threat 逐項判 **passed / warning / critical**，未 passed 回報 engineer / 實作者
修正，迴圈至全 passed。

- **P2.1 OAuth / 雲端 token 外洩** — Check: 是否用 Authorization
  Code + PKCE（無 implicit、無 device 端 client secret）、token 存 iOS Keychain /
  Android Keystore-backed `EncryptedSharedPreferences`（或 `flutter_secure_storage`
  顯式 Keychain/Keystore option）、scope 收到最小可用範圍（如 Drive 的 `drive.file` 而非 `drive`）、登出銷毀 token + WebView
  storage + cached cloud metadata、refresh token 在 provider 支援處 server-side 撤銷？
  token 落 `SharedPreferences`/`UserDefaults`、scope 過寬、登出不銷毀、或
  token 以可讀字串穿 bridge → **critical**。Example: JS context 經 bridge 讀得到 token。
- **P2.2 Firebase 設定 / 安全規則錯誤** — Check: 每次 Firestore /
  Storage / RTDB schema 變更是否審 Security Rules（非 `allow read, write: if true`）、
  API key 在 provisioning 時加限制（web 用 HTTP referrer、Android 用 package +
  SHA-1、iOS 用 bundle ID）、Cloud Functions 預設要求 authenticated caller，且把
  Security Rules 變更當 security-review gated artifact（非 dev 便利）？新 Firebase
  resource 無 rules 審查 / API key 無限制 / endpoint 無 auth 可達 → **critical**
  （`google-services.json` / `GoogleService-Info.plist` 是公開識別碼，真正 enforcement
  在 server-side rules）。Example: default-open Firestore collection 任何人可讀寫。

## P3 — 使用者內容只走 app 知情的通道，旁路 egress 與多餘權限一律封死

**Principle:** 使用者內容（使用者輸入的任何文字、選取、搜尋詞、私有紀錄）只能走 app
threat model 明確 opt-in 的通道；任何**旁路 egress**（Crashlytics/Analytics surface、
OS 自動備份）與**超範圍權限**都擴大事故 blast radius，必須在**邊界 / schema /
path-provider**層 by-construction 排除，而非 per-callsite scrubbing。
STRIDE：Information Disclosure。此原則與 privacy review 交集。

每個 threat 逐項判 **passed / warning / critical**，未 passed 回報 engineer / 實作者
修正，迴圈至全 passed。

- **P3.1 Crashlytics / Analytics PII 外洩** — Check: `LogSystem` 是否
  以 **allowlist**（非 deny-list）限定可記欄位、user text（lookup query / 選取 /
  搜尋詞）analytics 預設 **off** + 顯式 opt-in、PII 以 **schema** 排除而非 per-callsite
  scrub？直接把 user-derived 字串傳 logger、deny-list scrubbing、event payload 帶
  filename / title → **critical**。Example: 使用者輸入的標題 / 選取文字 / 私有筆記直接
  進 analytics event。
- **P3.2 本地使用者內容經 OS 自動備份通道外洩** — Check: 新增的
  persistent 檔（含 user-typed 內容：筆記 / 搜尋史 / conflict snapshot）落在
  backup-included 目錄時，是否在 path-provider 邊界排除備份（Android `<application>`
  `allowBackup="false"`，或 `dataExtractionRules`/`fullBackupContent` 顯式 `<exclude>`；
  iOS 在目錄建立處套 `NSURLIsExcludedFromBackupKey`，經單一 `BackupExclusionHelper`）？
  sandbox 內 user-content 檔落在預設備份目錄、無 opt-out → **critical**（即使 user
  關閉 app 自帶 sync，檔仍經 OS 備份外洩；per-feature opt-out 是已知 anti-pattern，須
  在 path provider 單點根治）。Example: 一個 conflict snapshot 檔聚合使用者筆記，
  Android 無 `allowBackup`、iOS `Library/Data/` 無排除 → 上傳到使用者的雲端備份 /
  iCloud 備份層。
- **P3.3 本地檔案 / 權限超範圍** — Check: manifest / `Info.plist` 每個
  權限是否都有 product plan 中具名的功能佐證、權限 at point-of-use 請求（非 app
  start）、Android 預設 scoped storage（SAF / `MediaStore` / app-private dir，**絕不**
  `MANAGE_EXTERNAL_STORAGE`）、iOS 用 Files.app picker（無 full-disk）、且把
  manifest / `Info.plist` 權限 diff 當 security-review gated？一般 app 宣告
  `MANAGE_EXTERNAL_STORAGE` / camera / microphone / contacts / location 或權限無功能
  佐證 → **critical**（超範圍權限擴大 post-compromise blast radius、踩商店審查）。
  Example: 一般 app 在 manifest 宣告 `MANAGE_EXTERNAL_STORAGE`。

## P4 — 雲端查詢與識別碼當不可信，參數化 + 揭露 + 重置在邊界根治

**Principle:** 雲端查詢 DSL 是有自己語法的小語言，值必須**參數化 / escape** 而非字串
插值；同步用的穩定識別碼即使非憑證，也會 round-trip 進使用者雲端儲存、長期可連結，
需**揭露 + 重置**而非移除或靜默 scrub。STRIDE：Tampering + Information Disclosure。

每個 threat 逐項判 **passed / warning / critical**，未 passed 回報 engineer / 實作者
修正，迴圈至全 passed。

- **P4.1 雲端／後端查詢字串字面插值注入** — Check: 雲端 query DSL（Drive `q:`、Firestore where、任何
  cloud DSL：Firestore where、Realm、Algolia filter）查詢字串是否經單一
  集中的 escape 函式構建、每個插值值都路由過它，並 pin lint
  flag 含 `q:` / DSL-marker 的裸插值？以 `"... '$value' ..."` 直接插值、無 escape、
  reviewer 無法從 diff 證明每個插值值受限於 syntax-safe 子集 → **warning**（今日 input
  多為服務回傳的 ID / hash 不可利用；下一個讓 user-controlled 字串流入的 refactor
  即升 **critical**——前瞻性風險、無 compiler 信號）。Example: `"name = '$filename'
  and '$parentId' in parents"` 字串拼接，單引號可 break out 改寫查詢語意。
- **P4.2 穩定識別碼靜默 round-trip 進雲端使用者資料** — Check:
  client 生成的非憑證識別碼（per-install UUID / device seed / HLC `nodeId` /
  CRDT site-id / shard key），若被嵌入 syncs-to-cloud 的 payload，是否 (1) 在
  sync-enable / sign-in surface 有一行 plain-language 揭露（owned by product/design）、
  (2) 把 reset 接進 sign-out / wipe-account（重新登入即換新識別碼）、(3) 留在
  plaintext preferences（非憑證升 Keychain 是無風險削減的 ceremony）、(4) **絕不**在
  sync 時 scrub 該識別碼當「修法」（它是 sync 演算法正確性的 load-bearing 欄位）？
  新 client-side UUID/device-id 嵌入 cloud-mirrored payload 卻無揭露 copy、無
  sign-out reset → **warning**（揭露缺口非未授權蒐集、屬 MASVS-PRIVACY-1 的「未告知
  蒐集」arm）。Example: `deviceNodeId`（UUID v4 in `SharedPreferences`）嵌入每個
  同步 payload 的每一列與每份 metadata，sync 到使用者的雲端儲存，sign-up/sign-in 全程無揭露、
  sign-out 不重置 → 識別碼跨「使用者以為獨立」的 session 靜默長存。

## P5 — 平台入口（deep-link / intent）的 scheme/host/path 與參數一律當不可信

**Principle:** 控制 deep-link / universal link / app link / Android intent 的攻擊者就
控制了 app 的進入路徑。入口必須驗 scheme + host + path、視參數為不可信輸入、且在
auto-import 檔案或觸發副作用前要求 user 確認。STRIDE：Elevation of Privilege +
Tampering。逐項判 **passed / warning / critical**，未 passed 回報 engineer / 實作者，
迴圈至全 passed。

- **P5.1 Deep-link / intent 入口未驗證來源** — Check: deep-link / intent
  handler 是否在入口驗 scheme / host / path、視 parameter 為不可信（length / type /
  schema-check）、auto-import 檔案或觸發副作用前要求 user 確認，且每個 Android activity /
  intent 預設 `exported="false"`（除非顯式公開）+ entry handler 校驗 extras schema？
  不驗 scheme/host/path、信任 parameter、無 user 確認即 auto-import、或 activity export
  無 extras 校驗 → **critical**。

  **Example:** `file://` 或 custom-scheme URL 自動匯入磁碟上的惡意檔案 / 用 crafted
  parameter 外洩使用者資料 / 無確認觸發副作用。

## P6 — CVE 風險由「可達性」決定，相依鎖定 + 對 untrusted-input sink 做 reachability 分析

**Principle:** 一個高 CVSS CVE 只有當其 vulnerable sink **從本 codebase 的 untrusted
input 可達**時才 load-bearing。專案的 untrusted-input 邊界（使用者檔案、遠端內容、
後端回應）決定哪些 CVE 屬最高風險的供應鏈類。STRIDE：Tampering +
Elevation of Privilege。逐項判 **passed / warning / critical**，未 passed 回報
engineer / 實作者，迴圈至全 passed。

- **P6.1 可達的相依 CVE / 供應鏈污染** — Check: dep diff
  （`pubspec.lock` / `package-lock.json`）是否伴隨 `dart pub outdated` / `npm audit`、
  CI pin lockfile、任何 vendored / fork 程式的 upstream advisory 以同
  in-repo 程式的標準追蹤、每個 flagged CVE 顯式評估 reachability（可達 → block；
  不可達 → flag-and-track），且拒絕無維護紀錄 / 可疑 publisher / typosquat 名的新 dep？
  dep 變更未跑 outdated/audit、vendored advisory 未追、reviewer 跳過 reachability 分析
  → 可達 **critical** / 不可達 **warning**。

  **Example:** 從解析使用者檔案或渲染遠端內容的路徑可達的 CVE（那些入口是
  trust boundary）為最高風險；不可達的同 CVE 僅 flag-and-track。

## STRIDE 殘餘掃描
多數 N/A → passed；**新增金流 / 帳號操作才升級**逐項重判：
Spoofing → §P2｜Tampering → §P1, §P4, §P3.2｜Repudiation → 低優先（L1）｜
Information Disclosure → §P2, §P3, §P4.2｜DoS → §P1（解析界限）｜
Elevation of Privilege → §P1.1（WebView 逃逸）, §P5（入口）, §P3.3（權限）。
