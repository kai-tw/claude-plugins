# Notion — when the tracker or the spec pages live there

- The databases sit under the root page the project's CLAUDE.md gives; it maps names that differ.
- A task is a `tasklist` row; `Blocked by` and `Parent item` are relations.
  A decision is a `decision-log` row: Name = the question, Context · Decision ·
  Consequence, `Task` = the task row, `Status=Active`, `Decided` = today. Close = trash the row.
- A query reads every page of results (Notion paginates).
- A `|` inside a table cell is written `\|`.
- Every comment any agent leaves on a Notion page starts with
  `〔Claude Code｜<role>｜<category>〕`: role is the writer's department in the user's
  language (前端, 企劃…); category is one word summing up the comment (提問, 回報…),
  no fixed list. Of page bodies and properties, only a spec question row's Name carries it:
  `〔Claude Code｜企劃｜提問〕<summary>` (`references/brief.md`).
