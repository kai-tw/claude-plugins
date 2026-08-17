# 出貨規則

- **改了 `plan-cycle/` 的內容就 bump `plugin.json` 的 version.** 消費端的安裝目錄是
  `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`——**以版本號命名的實體
  目錄**。同一個版本號裝著兩份不同的內容時，更新有沒有落地無法從外部分辨，而使用者拿到
  的回饋是「已是最新」。修 bug 用 patch（0.4.0 → 0.4.1），加或改行為用 minor。
- **push 完不等於生效，而且「更新完」也不等於生效.** marketplace 是 directory source，
  讀的是本機工作目錄，所以要消費端跑 `/plugin`（或 `claude plugin install
  <plugin>@<marketplace> --scope project`）把內容複製進 cache。但 **PATH 在 session
  啟動時就固定**，指向當時那個版本的 `bin/`；而 `bin/` 的 wrapper 是
  `exec "$here/../skills/…"`，`$here` 是**它自己的安裝目錄**，不是任何工作目錄。所以
  舊 session 會一直跑舊版實作 —— **腳本、schema、skill 內文、frontmatter 全部都要新
  session 才生效**，沒有哪一半是即時的。
  最陰的是 wrapper 幾乎不會改：兩版 `bin/plan-lint` 的 md5 相同、底下的
  `plan_lint.sh` 不同，所以 `cmp` wrapper 看起來永遠沒事。**要驗就驗實作**
  （`type -a <name>` 看解析到哪個版本目錄，或看輸出裡的自報版本）。
- **裸名呼叫自己的腳本.** plugin 的 `bin/` 在啟用時就在 PATH 上；安裝路徑不可從專案
  相對位置推得、且每次 bump 都會變。寫 `plan-lint`，不要寫 `bash .claude/hooks/…`——
  後者失敗時只印一行 `No such file or directory`，和「這次沒事做」長得一樣。
