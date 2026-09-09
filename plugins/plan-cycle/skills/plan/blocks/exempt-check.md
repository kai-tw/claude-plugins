---
id: exempt-check
kind: native
summary: "守門判級：豁免 / 要走 cycle，以及這次要開哪些 phase"
consumes:
  - task-brief
produces:
  - triage
stop: "false"
---
# Block: exempt-check（守門判級）

> 輸入 `task-brief`＝進來的需求（QA 單 / 企劃 / 使用者描述）；
> 輸出 `triage`＝豁免與否，以及要走哪條 flow、開哪些 phase。
> **豁免不是本 flow 的一個節點，是不進 flow** ——判成豁免就在這裡結束。

## 第 0 步 — 豁免清單

符合以下任一項就明說並直接做——**不開 task、不開 phase、不留 Notion trail、不 spawn
任何東西**：

- **Typo** — string / doc / comment 的錯字
- **Lint 修正** — formatter、analyzer 建議的清理
- **孤立 bug fix** — 恢復原本意圖的行為，不改流程、範圍或互動面 → 走
  `/bug-investigate`
- **行為保持的重構** — 檔案改名、函式抽出、測試重組、型別收緊且無行為差異

回覆格式：`Exempt from /plan: <一句話理由>`。

### 兩個看起來像 bug fix 但不是的形狀

這兩個是豁免判斷唯一真正會出錯的地方，錯的方向都是**判太寬**：

- **加了流程步驟 / 改了權限邊界 / 挪用了既有 state 的「修正」不是 bug fix**，是功能
  變更，要走完整 flow。
- **加了使用者看得到的 state / 畫面 / 操作面 / 文案的修正，是 SCREEN 變更（designer）
  ＋一次翻譯循環**。這個分類要在**動手之前**先攤給 founder 看。照著已出貨的 sibling
  抄機制可以，但它的文案和逐面設計仍要各自走一次——**不要把 sibling-mirror 當既成
  事實出貨**。

## 豁免 ≠ 不進 worktree

**worktree 閘門看的是「顯著性」，不是豁免狀態。**

| 這次改動 | 去哪 |
|---|---|
| 豁免且**顯著**——範圍大，或**功能性**（會改變行為的孤立 bug fix 算） | 仍然進隔離 worktree、仍然開 PR（Iron Law 9），只是沒有 plan / Notion 產物 |
| 豁免且瑣碎——typo / format / 小 lint / 微小的行為保持調整 | 直接在 main tree |
| 所有非 app-code 的編輯 | 直接在 main tree |

## 第 1 步 — 非豁免：先拉使用數據基線

任務是「**該不該做這個**」，而且它的成效是專案 analytics 已經在追的指標（採用 /
留存 / 互動 / 某個事件）時：**在任何 phase 開始之前**，先用專案自己的使用數據 skill
查一次。

競品研究答的是「別人怎麼做」，基線答的是「這裡有沒有人走到那一步」——而**後者可以
用零頭的成本讓前者變得不必要**。兩種情形都要把數字寫進去；低流量時它是**方向性、
不是顯著性**，產品判斷仍然主導（PM `P1.1`）。

## 第 2 步 — 選 flow

| 這次改動 | flow |
|---|---|
| 會產生或改變任何**使用者看得到的介面** | `standard-dev` |
| 沒有 user-visible surface | `code-only` |

非 UI 的工作跳過設計與翻譯，**但不跳過工程計畫**。

跑 `plan-flow show --flow <id>` 取拓撲執行序，不要憑記憶背節點順序。

## 第 3 步 — phase 開啟判準（寫進 `triage`）

flow 決定骨架，這張表決定骨架上哪些節點這次真的有事做：

| Phase | 什麼時候開 |
|---|---|
| **PM** | 改動碰到線上機制 / 資料流 / 權限 / telemetry，或還沒有核准過的 product plan |
| **designer** | 改動產生或改變任何使用者看得到的介面 |
| **translator** | 改動新增或改變需要 i18n 的使用者文案（在 `design-spec` 塊**內部**，不是獨立節點） |
| **engineer** | 任何非瑣碎的實作（有 code 就一定開） |
| **QA** | 有 code 落地 |
| **code review** | code 寫完之後 |
| **post-QA** | code ＋ QA 的 spec tests 都到位、且有核准過的計畫 |

**security / privacy 不是可開可關的 phase。** 它是橫切 gate，跑在 PM、engineer 和
code 三個階段**內部**，而且在 code 階段是 boundary-gated 在 diff 自己的 sink 訊號上。
「某個欄位到底該不該收」是 PM 規則 `P8`，在 ① 層走。**不確定就 spawn——fail-closed。**

## 有 app code 就一定進 worktree

flow 裡只要有 translator / implement / qa 任一節點會寫檔（也就是任何帶 code 的
ticket），整條就在**隔離的 git worktree** 裡跑，讓並行的 `/plan` session 不會踩到
彼此的 working tree（Iron Law 9）。**這是強制的，不是選配。** 只有純 plan cycle
（只寫 Notion、不寫 app code）可以不開。

worktree 的建立時機、base 捕捉與拆除在 `plan/SKILL.md` §Worktree isolation。
