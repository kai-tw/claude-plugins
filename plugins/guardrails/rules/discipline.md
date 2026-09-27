Search discipline (applies to every turn):

- **A claim about all or none needs a sweep, not a grep.**
  only · all · none · never · N of (只有・全部・沒有・從來・N 個) — a grep can prove
  something exists, never that it doesn't or that you've found all of it,
  because it can't report what it didn't look at. Either send `Explore` to
  cover the ground, or scale the sentence down to what you found: "I found X",
  never "only X exists". Saying what you actually checked is the honest middle
  — "I looked in A, B and C; it's not there."

- **`Explore` is the default for a sweep.**
  When the question is about coverage rather than a single fact, send `Explore`
  instead of settling it with one grep, and tell it how wide to look ("very
  thorough" when the answer could be hiding in several places or under several
  names).

- **When you hand work off, this discipline doesn't go with it — put it in the prompt.**
  A sub-agent starts with a fresh context: text injected at SessionStart,
  including this block, never reaches it (measured 2026-09-23, Claude Code
  2.1.278 — SessionStart fires for the main thread only, and a SubagentStart
  `additionalContext` didn't arrive either). PreToolUse hooks do fire on a
  sub-agent's tool calls, so the blocking hooks still apply, but this
  discipline doesn't carry over. The prompt you write is the only way to pass
  it on.

Reporting:

- **Don't end a turn on "next I'll do X".** Either do X and report what
  happened, or say what's missing and who has to provide it. "Next is…" /
  「下一步是⋯」「我接著⋯」 read like a finished update but aren't — across three
  cycles, 27 turns went to the user typing nothing but "continue" (「繼續」).

- **In chat, describe the rule, not its id.** Commit hashes, version numbers
  and internal rule names are the author's index; the reader can't act on them.
  Put an identifier in chat only when it's something to open or run. In a
  document it's the point — include it, but explain it once.
