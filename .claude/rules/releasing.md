# 出貨規則

- **改了 `plan-cycle/` 的內容就 bump `plugin.json` 的 version.** 消費端的安裝目錄是
  `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`——**以版本號命名的實體
  目錄**。同一個版本號裝著兩份不同的內容時，更新有沒有落地無法從外部分辨，而使用者拿到
  的回饋是「已是最新」。修 bug 用 patch（0.4.0 → 0.4.1），加或改行為用 minor。
- **push 完不等於生效.** marketplace 是 directory source，讀的是本機工作目錄；真正生效
  要消費端專案跑 `/plugin` 更新。script 與 schema 更新後立即生效，skill / agent 的
  frontmatter description 要開新 session 才換。
- **裸名呼叫自己的腳本.** plugin 的 `bin/` 在啟用時就在 PATH 上；安裝路徑不可從專案
  相對位置推得、且每次 bump 都會變。寫 `plan-lint`，不要寫 `bash .claude/hooks/…`——
  後者失敗時只印一行 `No such file or directory`，和「這次沒事做」長得一樣。
