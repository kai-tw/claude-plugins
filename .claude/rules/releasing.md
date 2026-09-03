# 出貨規則

- **改了 `plan-cycle/` 的內容就 bump `plugin.json` 的 version.** 消費端的安裝目錄是
  `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`——**以版本號命名的實體
  目錄**。同一個版本號裝著兩份不同的內容時，更新有沒有落地無法從外部分辨，而使用者拿到
  的回饋是「已是最新」。修 bug 用 patch（0.4.0 → 0.4.1），加或改行為用 minor。
- **push 完不等於生效，而且「更新完」也不等於生效.** marketplace 是 directory source，
  讀的是本機工作目錄，所以要消費端跑 `/plugin`（或下一條的 `claude plugin update`）把
  內容複製進 cache。但 **PATH 指向哪個版本無法從外部預測**：它在 session 存續期間會變，
  而且不追蹤安裝——同一個 session 的 transcript 裡依序出現 `0.15.1` → `0.17.0` →
  `0.19.0`（沒重開、沒跑 `update`，而且跳過了 `0.18.0`），且 `0.19.1` 已進 cache 後它
  仍解析到 `0.19.0`。刷新的觸發條件不明，從 session 內部看不到。
  這件事會發生是因為 `bin/` 的 wrapper 是 `exec "$here/../skills/…"`，`$here` 是**它
  自己的安裝目錄**，不是任何工作目錄——所以解析到哪個版本目錄，就跑哪一版的實作，
  **腳本、schema、skill 內文、frontmatter 都跟著那一版**，沒有哪一半是即時的。
  推論的兩條路都不通：安裝紀錄不代表某個 session 吃得到，而 `ListAgents` 的「N 分鐘前
  啟動」是**重新連線**時間、不是 session 起始（實測：`ListAgents` 說 25 分鐘，transcript
  的 `birth` 是 17 小時前）。cache 目錄的 mtime 也不是安裝紀錄——裝新版時會連帶動到既有
  版本目錄的 mtime。
  最陰的是 wrapper 幾乎不會改：兩版 `bin/plan-lint` 的 md5 相同、底下的
  `plan_lint.sh` 不同，所以 `cmp` wrapper 看起來永遠沒事。**所以一律實查、且要驗實作**
  （`type -a <name>` 看解析到哪個版本目錄，或看輸出裡的自報版本）。要確定性就重開
  session。
- **`release.mjs` 只更新一個消費端，而它的 `✔ … installed and verified` 只講那一個.**
  第 6、7 步都以 cwd 解析到的專案為對象；其他啟用了這個 plugin 的專案原地不動，收尾那行
  也不會提到它們——一次 plan-cycle 發版印了全綠，NovelGlide 卻還停在兩版前的 0.15.1。
  **每個消費端各補一次**：
  ```
  cd <project> && claude plugin update <plugin>@<marketplace> --scope project
  ```
  `install` 對已安裝的 plugin 只印 `already installed` 然後什麼都不做（第二個「失敗長得
  像成功」），`--scope project` 也不能省，省了會去找 user scope 然後失敗。收尾看
  `~/.claude/plugins/installed_plugins.json` 裡每個 `projectPath` 的 `version`。
- **裸名呼叫自己的腳本.** plugin 的 `bin/` 在啟用時就在 PATH 上；安裝路徑不可從專案
  相對位置推得、且每次 bump 都會變。寫 `plan-lint`，不要寫 `bash .claude/hooks/…`——
  後者失敗時只印一行 `No such file or directory`，和「這次沒事做」長得一樣。
- **Tag 不是人打的，也不要試.** 版本一進 `main`，`plugin-tag` workflow 就照 `plugin.json`
  建 `<plugin>--v<version>`、push，然後呼叫 `vendor-sync` 開消費端的 bump PR。雲端 session
  的 GitHub 授權本來就拒絕 push tag（403），而**本機先打 tag 更糟**：workflow 看到 tag
  已存在就無事可做，消費端永遠收不到這一版。
- **一個 PR 全程只 bump 一次版號，收尾前才跑.** Tag 只在進 `main` 那一刻打（上一條）
  ——PR 存續期間中途 bump 幾次都不會被 tag、不會被任何消費端看到，只會在 `git log`
  裡留下一串從未真正存在過的版本。改動確定收斂、真的要送出這個 PR 時才跑一次
  `release.mjs`。
