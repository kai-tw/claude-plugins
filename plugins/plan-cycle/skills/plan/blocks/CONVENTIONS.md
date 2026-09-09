# Blocks & flows — 維護慣例

`Read` 本檔只在新增 / 修改 / 合併 / 刪除 block 或 flow 時。

**這是什麼.** `/plan` 的流程模組化：`blocks/` 是自包含子流程，frontmatter 宣告拼裝
契約；`flows/` 把 block 拼成 DAG pipeline。**拼法可以變、契約不變，鏈條就斷不了**——
而「不變」不是靠紀律，是靠 `plan-flow lint` 查。

**為什麼要這樣切.** `plan/SKILL.md` 是**路由**，不是程序書。一個被 invoke 的 skill
其內容會**留在 context 裡整個 session**（官方 skills 文件），所以把 1,383 行程序放在
launcher 裡等於每一則後續訊息都重付一次。block 是 **Read 進來的檔案**——沒有
always-on 描述稅、compaction 丟得掉、而且只有這次路由用到的那幾塊會進來。

> **執行某 block 前必先 Read 該 block 檔。憑記憶執行＝違規。**
> 這條硬規是防止 launcher 又慢慢把內容吸回去的唯一機制。

## 檔案格式

**`blocks/<id>.md`** — frontmatter 六個必填欄，`id` 必須等於檔名：

| 欄 | 值 |
|---|---|
| `id` | == 檔名（不含 `.md`），slug（`[a-z0-9-]+`） |
| `kind` | `native`（body 寫完整執行程序）或 `skill`（委派給一個 skill） |
| `summary` | 一句話：這塊做什麼 |
| `consumes` | 進料 artifact slug 清單，`[]` 表示不需要 |
| `produces` | 產出 artifact slug 清單 |
| `stop` | `true` = 內含 ⛔ STOP，未獲使用者拍板不得推進下游 |
| `skill` | **`kind: skill` 時必填**——委派對象 |
| `scripts` | 選填，相對 plugin 根的路徑；lint 驗它們存在 |

`kind: skill` 的 body 只寫**拼裝契約與注意事項**（任務書在那個 skill 裡）；
`kind: native` 的 body 寫**完整執行程序**。

**`flows/<id>.md`** — 五個必填欄：

| 欄 | 值 |
|---|---|
| `id` | == 檔名，slug |
| `summary` | 一句話 |
| `inputs` | 外部進料 artifact（pipeline 起點手上就有的東西） |
| `nodes` | `"nodeId: blockId"` 一列一個 |
| `edges` | `"a -> b"` 一列一條 |

body 放 ASCII 圖 ＋ 節點備註（條件分支用 prose 寫在備註裡，不要編成 edge）。

## lint 查什麼（`plan-flow lint`）

```
F1  block 契約  必填欄 · id==檔名 · kind enum · kind=skill 有 skill 欄 ·
                stop enum · consumes/produces 是 slug · scripts 檔案存在
F2  flow 結構   必填欄 · id==檔名 · node 格式與唯一 · node 指向真的 block ·
                edge 格式 · 不自環 · 端點存在 · 圖是 DAG
F3  IO 銜接     每個 node 的 consumes ⊆ flow inputs ∪ 上游 ancestors 的 produces
warn            孤兒 node（多節點 flow 裡沒有任何邊）
```

**F3 是最重要的一條**，因為它抓的是「改完看起來沒事、但某個節點沒料吃」——那是
重新拼裝唯一會靜默壞掉的方式。**改了任何 block 或 flow 就跑 lint，綠燈才算改完。**

## artifact 詞彙（改名＝改契約，要一起改所有引用）

artifact 是 block 之間唯一的介面。沿用既有詞彙才接得上既有 block：

| slug | 是什麼 |
|---|---|
| `task-brief` | 進來的需求（QA 單 / 企劃 / 使用者描述） |
| `triage` | 判級結果（豁免 / 要走 cycle，以及要開哪些 phase） |
| `task-anchor` | TaskList task ＋ GitHub issue，所有計畫掛在它上面 |
| `product-plan` | 核准過的 Product Plan row |
| `design-spec` | 核准過的 Design Plan row ＋ renders ＋ widgets ＋ ARB |
| `engineering-plan` | 核准過的 Engineering Plan row |
| `code-changes` | working tree / worktree 裡的源碼改動 |
| `spec-tests` | `/qa` 的 `test/spec/**` |
| `review-report` | 逐 finding 有 verdict 的審查結果 |
| `residual-report` | post-QA 的殘留審查（測試結構上碰不到的那些） |
| `landed-commit` | 過了 commit gate 的 commit |
| `shipped-pr` | 開好的 PR ＋ 測試強度報告 |
| `feature-archive` | Feature Archive row ＋ 已 trash 的 task |
| `retro-entry` | feedback ledger 的 process 條目 |

## 收斂原則

- **一個 block 一件事，而且它的 STOP 語意不可被拼裝改寫。** pipeline 組裝只能改
  「拼法」（節點與邊），不能改個別 block 的 STOP、進出口或不可省步驟。要改 block
  本身＝改 block 檔＋過 lint。
- **條件分支不編進 edge。** 「有 UI 才走 designer」是**兩條 flow**，不是一條帶條件的
  edge——F3 才驗得動，而且哪條在跑看得出來。
- **block 數 = 收斂後的子流程數，不硬湊。** 一塊只在「它有自己的進出口契約、而且
  會被一條以上的 flow 用到，或大到不該常駐 launcher」時才成立。
- **artifact 不要為了讓 F3 過而新增。** 新 slug 代表真的多了一種交接物；為了繞過
  lint 而發明的 artifact 會讓 F3 從檢查退化成裝飾。
