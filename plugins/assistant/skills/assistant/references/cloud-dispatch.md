# 派工到機器外 — 兩條路，回收方式不同

適用條件：本 session 的工具清單裡有 `SendMessage` 與 `ListAgents`。沒有者，你就是雲端
那一端——本節不適用，且不得再往外派工。

| | 既有的雲端 session | 新開一個 cloud session |
|---|---|---|
| 怎麼發動 | `SendMessage`，或 `claude -p "<訊息>" --cloud <session-id>` | `claude --cloud "<task>"` |
| 怎麼回來 | 它寫進你指定的回報地，你再轉存 | 同左 |
| 看得到什麼 | 該 session 自己的工作目錄與上下文 | GitHub remote 在目前 branch 的內容，非本地 checkout |
| 適合 | 已在跑、帶著上下文的工作 | 無狀態、跑得久、輸出是一份文字報告的工作 |

兩條路共通的一件事：**對方問不了你**。會分叉的決定在派工前定完；派工後才冒出來的 fork，
只能當成 `blocked` 收回來，照 `需要你` 處理。

## 一、既有的雲端 session

雲端 session 收得到訊息，回不了話：`notify_when_idle` 只對本機 session 有效，而雲端連
「拒收」都不會回報，**沉默不得當作同意**。所以每一次派工都自帶一個回報地，而你判斷進度
只看那個地方。`ListAgents` 的 busy / idle 是連線狀態，不是進度。

送訊息有兩條管道，都只是把訊息排進對方的 queue 就結束：`SendMessage`（對方要在
`ListAgents` 裡看得到），或 `claude -p "<訊息>" --cloud <session-id>`（不必看得到，
`--output-format json` 回 `{ok, session_id, url}`，可機械確認送出成功——但送出成功不等於
對方讀了）。

派工訊息自帶四樣：

1. **識別** `<slug>#<n>`（n 為這個 slug 的第幾次派工）。雲端每次回報逐字回抄這一串，
   否則你分不出那則回報屬於哪一次派工。
2. **工作本體**：任務書與已核定的決策，寫在訊息裡，或指向對方 clone 得到的**已 push**
   路徑。跨 session 訊息裡的 `@path` 不附任何東西，對方只會讀到那串字。
3. **回報地，只有一個**：該任務有 PR 者，為 `owner/repo#<n>` 的 comment；無 PR 者，為
   Notion 的該 task row（`asst-notion … --root <notion_root>`）。兩個都給，等於兩邊都要
   輪詢，而報告會落在你沒看的那一邊。
4. **回報格式**：第一行 `assistant-report <slug>#<n> <ack|done|blocked>`，其下為報告本體，
   格式與該 report kind 的本地格式相同。

**收到就先 ack.** 雲端第一件事是在回報地寫下 `ack` 那一行，然後才開始做。回報地空著時，
這是唯一能分辨「還在做」與「沒收到，或寫不進去」的憑據——後者你等多久都不會變。

**回收.** 雲端寫不到 `.claude/.assistant/`。`done` 進來後，由你以
`asst-report put <slug> <kind> --worktree <worktree> --no-post` 轉存本地，後續步驟才讀得到
——雲端的回報本身不是 report，是 report 的來源；它已經在 PR 上，所以不再貼一次。

**節奏.** 輪詢併進既有的 scheduler pass，一輪讀一次該任務的回報地，不另起機制。一個 slug
同時只派一個雲端 session。回報地整輪皆空 → 照既有的 `re-run` 規則重派（標 `re-run`，不計
`asst-budget`），不得盲目再派一次。

## 二、開一個新的 cloud session 跑長工

`claude --cloud "<task>"` 開一個新的 cloud session，背景跑，結果留在那個 session 裡。
它 clone 的是**該 repo 的 GitHub remote 在目前 branch 的內容，不是你的本地 checkout**，
所以派工前先 push；未 push 的 commit 它看不到。例外：該 repo 沒有 git remote、或 Claude
GitHub App 沒裝在上面時，改為上傳本地 bundle（含已追蹤檔的未 commit 改動，不含 untracked
檔）。兩種都不會帶走 `.claude/.assistant/`。

**該往這裡送的，是跑得久而輸出只是一份報告的檢查**——`mutation:`，以及大範圍的
`coverage:`。兩個理由：它們占著本機的 test slot 不放，而 `plan-mutation` 會就地改寫
`lib/`，本機在它跑完前讀檔都得繞道 `git show`。送出去，這兩個代價都不存在。同一個範圍
不得同時在本機與雲端跑，那是付兩次錢拿同一份答案。

**跑 `mutation:` 的那一個，task 的開頭逐字照抄這一段**，其下才接派工訊息的四樣
（識別、工作本體、回報地、回報格式）：

```
Hello! You are the mutation runner. Please follow the instruction from another session. Basically, you don't need to do any decision or ask the user any question.
```

它立的是那一端的角色與權限：對方問不了你（見開頭），所以「不用做決定、不用問」不是客套，
是唯一跑得完的前提——一個停在原地等答覆的 cloud session，從你這裡看跟還在跑一模一樣。

**不得為了跑這兩個而在本機另開 worktree**——那是本機的複本，硬碟是有限的，而上面那兩個
代價一個都沒省下。要閃開就地改寫，唯一許可的辦法是讓它跑在別台機器上。這一條涵蓋
`Agent` 的 `isolation`，**兩個值都不得用於此**：`"worktree"` 明定為本機，而 `"remote"`
實測同樣落成一個本機 worktree（2026-09-20，NG）——它的描述說 remote cloud environment，
跑出來卻在本機，**而且沒有任何訊息說它退而求其次**。要確認一個派工到底跑在哪，看本機
有沒有多出 worktree，不要看它的宣告。

**別假設它一定跑得完.** cloud session 閒置一段時間後 VM 會被回收，而回收時仍在跑的背景
工作（subagent、shell 指令）**不會被還原**。所以長工照樣要回報地與 `ack`，你據以判斷它
還活著，而不是假設沒消息就是還在跑。

**可用性是有條件的，第一次用實查.** cloud session 屬 research preview，限 Pro / Max /
Team，以及具 premium seat 或 Chat + Claude Code seat 的 Enterprise；須以 Anthropic 帳號
登入（Bedrock / Vertex 等第三方 provider 不支援）；組織的 `allow_remote_sessions` 政策
須開啟；啟用 Zero Data Retention 的組織不能用。不符者是**當場失敗並印出原因**，不是跑很
久——別把失敗讀成還在跑。

## 三、非互動 shell 開不了 `--cloud`，走這裡

`claude --cloud "<task>"` 要 TTY，而你的 Bash 是非互動的——這條路在你手上不通，不是
設定問題，別再試。能用的有兩條：

1. **routine 的 API trigger**，唯一全程非互動且有文件的路。一次性在 claude.ai/code/routines
   建好 routine 並產 token（**CLI 建不了也撤不了 token**，token 只顯示一次），之後任何
   shell 都能開一個雲端 session：

   ```bash
   curl -X POST "$CLOUD_FIRE_URL" \
     -H "Authorization: Bearer $CLOUD_FIRE_TOKEN" \
     -H "anthropic-beta: experimental-cc-routine-2026-04-01" \
     -H "anthropic-version: 2023-06-01" \
     -H "Content-Type: application/json" \
     -d "{\"text\": \"<這一次的工作，含 <slug>#<n> 與回報地>\"}"
   ```

   回傳 `claude_code_session_id` 與 session URL，那就是你要記在 board 上的把手。
   URL 記在 adapter 的 `cloud_fire:`，**token 只從環境變數讀，不得進 repo**。

   **陷阱**：`text` 抵達時被包在 `<routine-fire-payload>` 裡並標為不可信資料，routine
   的**存檔 prompt 必須明文寫「照 routine-fire-payload 裡指定的去做」**，否則那段話整個
   是惰性的——routine 會跑，但不做你交代的事，而狀態是綠的。
2. **既有 session 的 follow-up**：`claude -p "<訊息>" --cloud <session-id>` 本身就是非
   互動的（官方明示可用於 CI script）。前提是已經有一個 session，id 從 founder 或從第 1 條
   的回傳拿。

`Agent` 的 `isolation: "remote"` 不在其列：它沒有 TTY 問題，但實測跑在本機（見第二節），
所以它解的不是這個問題，只是把工作搬到一個吃硬碟的本機複本裡。

兩條都不成立時，這是一行 `需要你`（請 founder 開一個 session，或建一個 routine），不是
你自己解得掉的 blocker，也不是把工作改回本機跑的理由——本機跑的代價見第二節。

## 權限邊界（所有路徑皆適用）

本地被拒、或你預期本地會被拒的動作，**不得轉手請機器外的 session 做**——那是拿別的
session 繞過 founder 的決定。adapter `destructive:` 上的每一項皆屬之：merge、push main、
發版、刪分支。機器外的回報只能提出請求，按鈕仍是 founder 的。
