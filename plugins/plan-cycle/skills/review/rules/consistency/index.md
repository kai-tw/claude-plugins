# Consistency rules — cross-feature mechanism baseline

目標：**同一個 cross-cutting 機制（驗證、紀錄、資訊傳遞、錯誤處置）在整個 codebase
只有一種做法**。`consistency-reviewer` 對審查對象（**diff + engineering plan 的
§Classes / §Conformance 同儕 row + 同儕 feature 的實作**）**逐母規則 → 逐 sub-check**
對照本清單旁觀審查（player ≠ referee，禁實作者自審）：每項問「這條新路徑與既有做法
一致嗎？」→ 標 **passed / warning / critical** → 所有 warning / critical 回報
engineer / 實作者修正 → 迴圈重審，**直到全 passed** 才放行。禁 deferred & dismiss。

這一包補的是其他 gate 結構上不問的那一題：`engineer-plan-reviewer` criterion 10 在
**plan 階段**問「該不該存在」，commit gate 的 `plan-lint --diff` 抓**計畫沒寫過的**
新 class——但一條「計畫寫了、也真的新的」流程，其檢查點是否與同一機制的既有 feature
一致，至今沒有人問。同一流程檢查不一的 bug 會逐 feature 復發，且每次都要人工在 PR
才抓到——這一包就是那道網。

## 這份是基線，不是全部 —— 專案要疊加自己的機制表

本檔只收**任何專案都成立**的一致性通則。哪些機制算 cross-cutting、它們的 canonical
entry point 在哪、各自的檢查點清單長什麼樣——那是專案的事實，不是通則。

**專案在 `.claude/rules/consistency.md` 疊加一張機制表**，一列一個機制：

| 機制 | Canonical entry point | 檢查點（該機制每次都要做的事） |
|---|---|---|
| <驗證 / 紀錄 / 傳遞 / …> | `<file:line 或 Class.method>` | <逐項列出> |

`consistency-reviewer` **兩份都用**：基線的通則 + 疊加層的事實。判斷一條該放哪，
只問一個問題：

> **換一個專案，這條還成立嗎？**

成立 → 基線，回報上游改這裡。不成立（點名了某個 helper、某條自家路徑）→ 機制表。

**專案沒有機制表時**：C1 / C3 照跑（它們只需要 grep），C2 的逐檢查點對照標
**無法判定**——在報告開頭明說機制表不存在，並把「建表」本身回報為一個 warning。
無法判定不是 passed；沒有表的專案正是檢查不一致最會發生的專案。

### 建表法（第一次寫 `.claude/rules/consistency.md` 時讀這一節）

表是**盤點出來的，不是設計出來的**——列的是專案已經在做的事，不是想像中該有的
架構。六步：

1. **從傷口倒推候選機制。** 先翻三個來源：feedback-ledger 的 `recurring-bug` 與
   `code-review` entries、retro 量測列計過數的 finding、founder 在 PR 反覆點名的
   那幾類問題。每個復發 bug 背後都是一個機制——它復發，就是因為這個機制沒有表。
   沒有歷史資料的新專案，從四個常備嫌疑犯起手：輸入驗證、紀錄（log／event）、
   資訊傳遞（feature 間的資料交接）、錯誤處置。
2. **Grep 出每個機制的現有實作點。** 按動詞面掃（validate／check／log／record／
   emit／dispatch／handle…），列出同一件事現在有幾種做法、各在哪裡。**做法超過
   一種本身就是發現**——記下來，這是表的第一批產出。
3. **每機制挑一個 canonical entry point。** 多個實作並存時，選檢查最完整的那個
   當 canonical（通常是修過最多 bug 的那條路），其餘實作在表下方列成
   「待收斂：<路徑> → canonical」——表不假裝現況已收斂，它記錄收斂的方向。
4. **檢查點欄寫「每次都要做的事」，逐項可驗。** 來源是 canonical 實作現在做的
   檢查＋歷史上修過的 bug 各自對應的那一項。寫成 reviewer 拿著能逐項打勾的粒度
   （「拒空值」「上限 N」「重複偵測」「失敗時記 X」），不寫「妥善處理」這種散文。
5. **列少而真。** 起步 3–7 列，只收真正 cross-cutting（≥2 個 feature 做同一件事）
   的機制。一個 feature 私有的流程不進表——表越長越沒人維護，這裡的失敗模式和
   規則檔一樣是一路長大。
6. **每列自帶證據。** entry point 必須是真實 `file:line` 或 `Class.method`
   （`plan_lint` 對 §Classes 的同一紀律）；寫不出位置的機制還不存在，不進表。

**維護是消化的副作用，不是獨立作業**：`recurring-bug` entry 消化到這張表時，
落點就是某一列的檢查點欄加一項（或「待收斂」清單少一行）。表跟著傷口長，
不開會不腦補。首列的驗收：拿最近一次「同一流程檢查不一」的 bug 回測——如果
當時有這張表、`consistency-reviewer` 拿著它，那個 bug 會不會在 review 被抓到？
不會，表就還沒寫對。

## C1 — 同一 datum 只有一個 canonical home，讀寫只走一條路

**Principle:** 一個事實在 codebase 裡只能有一個擁有者。第二真相源在誕生當下永遠
看起來乾淨（「projected from / derived from / mirrors X」），漂移發生在之後——兩條
讀路徑正規化不同、更新漏掉一邊。plan 階段 `為何要新增` 已問過一次；這裡在 diff 上
再問，因為欄位常在實作中途長出來。

每項判 **passed / warning / critical**，未 passed 回報修正，迴圈至全 passed。

- **C1.1 新欄位／實體是既有 datum 的第二面** — Check: diff 新增的 field / entity /
  marker，其承載的事實是否已有 in-tree 擁有者（grep 該 datum 的既有 accessor /
  state）？描述帶「projected from / derived from / mirrors / 同步自」即是 tell；
  已有擁有者而另開一面、且兩邊可獨立變動 → **critical**（漂移是時間問題）。
  已有擁有者但新面是唯讀 view 且單點派生 → **warning**（要求註明派生點）。
  Example: `Book.language` mirrors `BookMetadata.language`，兩條讀路正規化不同。
- **C1.2 新 enum／常數集重複既有詞彙表** — Check: diff 新增的 enum / 常數清單 /
  descriptor 表，是否命名了某個既有集合已命名的概念（兩集合之間需要一個 mapping
  switch 就是 tell）？是 → **warning**（合併進既有集合或說明為何語意真的不同）。
  Example: 新 `SyncPhase` enum 與既有 `LoadingStateCode` 一一對映。

## C2 — Cross-cutting 機制走既有路徑，檢查點在邊界收斂、不逐 callsite 重寫

**Principle:** 驗證、紀錄、資訊傳遞這類機制的正確性活在「每次都一樣」裡。檢查點
必須收斂在**邊界的單一 audited helper**（security 基線 P1.2 / P4.1 對注入與解壓
早已如此要求——這裡把同一紀律一般化到所有機制）；一條新流程該做哪些檢查，以**同儕
（做同一件事的既有 feature）**為準，缺一項就是下一個復發的 bug。

每項判 **passed / warning / critical**，未 passed 回報修正，迴圈至全 passed。

- **C2.1 新流程與指名同儕的檢查點不一致** — Check: engineering plan §Conformance
  的每條 `同儕：<feature> <file:line>` row，打開該同儕實作，逐項列出它做的檢查
  （輸入校驗、空值處置、上限、順序、錯誤路徑、紀錄），再對照新流程——同儕做而新
  流程缺的每一項，都要有寫進計畫的理由。缺項無理由 → **critical**（這正是「同一
  流程檢查不一」的復發源）；有理由但理由是「情境不同」而未寫明差在哪 → **warning**。
  沒有任何同儕 row 而 diff 明顯觸及機制表列的機制 → **warning**（回報 plan 補 row）。
  Example: 匯入流程 A 檢查了副檔名＋大小＋重複，後來的匯入流程 B 只檢查副檔名。
- **C2.2 檢查點逐 callsite 重寫而非走邊界 helper** — Check: diff 對機制表列的機制
  是否呼叫其 canonical entry point，而不是在 callsite 重新實作其中幾步？重寫且與
  helper 的檢查集不等價 → **critical**；等價但重複 → **warning**（改為呼叫，或把
  差異升級進 helper）。Example: callsite 自己 `startsWith` 檢查路徑而不走集中的
  canonical-path helper。
- **C2.3 新的紀錄／傳遞路徑繞過既有機制** — Check: diff 新增的 log / event /
  訊息傳遞，是否走機制表指名的 logger / bus / channel？自建平行通道 → **critical**
  （兩套紀錄格式從此各自演化）；走了但欄位命名與既有事件不一致 → **warning**。
  Example: 新 feature 直接 `print` / 自建 stream，繞過 `LogSystem`。

## C3 — 能力不重複實作：新單元不得是既有能力的第二面

**Principle:** `plan-lint --diff` 保證 diff 的新 class 都在 §Classes 上；這裡問的
是下一層——那個「計畫寫了」的新單元，是否其實是某個既有 use case / helper / 平台
內建能力的重複實作。plan 階段的 `為何要新增` 是起草者自答；這裡是旁觀者拿 grep
覆核那個答案。

每項判 **passed / warning / critical**，未 passed 回報修正，迴圈至全 passed。

- **C3.1 新單元的能力已有 in-tree 擁有者** — Check: 對 diff 每個新 class / 頂層
  helper，grep 其核心能力的既有實作（同動詞、同 datum、同 layer）；§Classes 該列
  `為何要新增` 的 `canonical home：grep …` 答案是否經得起覆核？grep 找得到可重用的
  擁有者而計畫聲稱沒有 → **critical**（答案是假的，回 Phase 11）；找得到但介面
  確實不合、計畫未說明差異 → **warning**。Example: 新 `FooValidator` 與既有
  `BarValidator` 驗同一類輸入。
- **C3.2 框架／平台已內建** — Check: 新單元自管的 state-tracking / 重繪驅動 /
  生命週期編排，框架或平台是否已提供（該列 `框架/平台：` 答案的證據是否為真實
  source 行或 doc 子節）？已內建仍自造 → **critical**。Example: 自管字體版本 map
  ＋ emit 重繪，實則 `FontLoader.load` 已觸發全域 re-layout。

## 殘餘掃描

多數 diff 只觸發一兩個母規則；**diff 同時觸及兩個以上 feature、或新增任何機制表
所列機制的呼叫端**時，三個母規則逐項重判。與其他 pack 的分工：該不該存在（plan）
→ `engineer-plan-reviewer` c10｜計畫沒寫的新 class → `plan-lint --diff`｜spec 有沒有
做出來 → `conformance-reviewer`｜這裡只管**一致**。
