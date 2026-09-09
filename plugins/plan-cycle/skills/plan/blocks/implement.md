---
id: implement
kind: native
summary: "依核准的 engineering plan 實作，嚴守範圍；超出即回 divergence"
consumes:
  - engineering-plan
produces:
  - code-changes
stop: "false"
---
# Block: implement（依核准的計畫實作）

> 輸入 `engineering-plan`＝Phase 10 核准過的 Engineering Plan row（含 §Classes 與
> §Conformance）；輸出 `code-changes`＝worktree 裡的源碼改動。
> **在隔離的 worktree 裡跑**（Iron Law 9）——進來之前它應該已經建好了。

## 每個 phase 四步，順序是載重的

Phased plan 的整個意義是**原子、可獨立出貨的 phase**，所以安全網（測試）和抓 bug 的
閘門（`/review`）屬於**每個 phase**，不是留到最後。

**stubs → tests → freeze → implement → gates**

### 1. Stubs

從核准過的 §Classes 把這個 phase 的公開介面吐成**可編譯的 stub**——
`throw UnimplementedError()`。

這是機械動作，**stub 不是猜測**：介面在 Phase 10 就核准了。反方向已經有
`plan-lint <plan> --diff` 在查（diff 新增的每個檔 / class 都要對到一列 §Classes NEW）。

> **為什麼是 stub，而不是讓測試對著空氣寫。** Dart 是靜態型別，測試指名一個不存在的
> API 是**編譯**錯誤，而編譯錯誤會把整個檔案帶下去（連無關的測試一起），而且跟真的
> 壞掉長得一模一樣。stub 把「還沒做」變成一個乾淨、歸屬明確的紅燈。

### 2. Tests，在任何實作之前

這個 phase 介面的 **contract-derived** 測試在這裡寫（engineer tree），
`/qa` task 寫 **spec-derived** 的那些（`testing.md` Rule 1）。

套件現在是**紅的，by construction**——而那就是重點：測試在還沒有任何東西滿足它的時候
陳述需求，所以它**不可能被一個還不存在的實作塑形**。

```bash
plan-test-first flutter test
```

它只在**每一個** failure 都是 `UnimplementedError` 時通過。真的斷言失敗、別的 throw、
壞掉的既有測試、載不起來的套件——全部照樣擋。

### 3. Freeze，然後才實作

```bash
plan-cycle tests-frozen
```

從這裡起，改一個測試需要在現場寫 `// test-change: <為什麼那個測試是錯的>`（ledger
Gate 5）。然後實作到綠。

**綠燈從兩邊都到得了，而測試那邊比較便宜**——freeze 就是讓這個不對稱關上的東西。

### 4. Gates（scoped 到這個 phase 的 diff）

跑 Phase 12 的 Steps 0–5.5——exception log 檢查、`/review`、逐 finding verdict、
commit gate——**只針對這個 phase 的 diff**，然後才開始下一個 phase。

## Single-slice plan

**只有一個 phase**，所以上面四步在整個 slice 上跑一次，順序完全相同；只有 gates
收斂成 cycle 結尾那一次 Phase 12。

Phase 12 的 Step 6（close-out：翻 Status、寫 Notion revision entry）**只跑一次**，
在最後一個 phase 的 Step 5.5 過了之後——那是行政收尾，不是第二次審查。

## `/qa` 的唯一豁免：這個 phase 沒有新的可觀察行為

`/review` **每個 phase 無條件跑**——schema / DI / preference 的改動可以在零行為變化的
情況下違規。

`/qa` 不一樣。純打底的 phase（Phase 7 自己那個「Phase A — schema / preference / DI
groundwork, no UI delta」的例子）常常還沒有東西可觀察，為它 spawn 一整趟 `/qa` 是付
一個新 sub-agent 的 context 載入成本換近乎零的測試產出。

**這個決定在 Phase 7 撰寫時逐 phase 下，不是實作中途猜。** 沒有新可觀察行為的 phase
跳過它的 `/qa` task，並在 task list 裡**寫明哪個後續 phase 吸收它的測試**（第一個真的
會運用到那個新形狀的 phase）——它的行為在有東西觀察它之前不會被單獨測到。

改變了既有可觀察行為的 phase（就算很細微）保留它的 `/qa` task。**拿不準就保留**——
判錯的跳過是一個靜默的缺口，不是一個便宜的錯誤。

## 超出範圍 = divergence，不是「順手做掉」

實作中途發現計畫裡某個工程決定是錯的（某層接不起來、選的套件過不了約束、畫的資料流
有 race）：**停下來，走 Phase 11 的六步**
（`${CLAUDE_PLUGIN_ROOT}/skills/engineer/references/closeout.md`）——更新 task、把
改動寫進 Notion row 的 §Revision history、**重審 rev 過的計畫**、重新取得核准，才 resume。

**不要在 diff 中途默默換一個架構。** commit gate 的對帳腳（`plan-lint <plan> --diff`）
會擋下任何新增了 §Classes 沒寫過的檔或 class 的 diff，所以中途發明的子系統只有兩條
路：走 divergence 補進計畫，或刪掉。
