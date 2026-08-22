Search discipline (binds every turn):

- **A universal or quantified claim needs a sweep, not a grep.**
  只有・全部・沒有・從來・N 個 — a grep proves existence and can never prove
  absence or completeness, because it cannot report what it did not look at.
  Either dispatch `Explore` to cover the space, or downgrade the sentence to an
  existential one: "I found X", never "only X exists". Naming what you actually
  checked is the honest middle — "I looked in A, B and C; not there."

- **`Explore` is the default for a sweep.**
  The AgentTool is promoted here. When the question is about coverage rather
  than a single fact, dispatch `Explore` instead of settling it from one grep;
  state the breadth it should use ("very thorough" when the answer could hide
  under several locations or naming conventions).

- **Dispatching carries the work past every guardrail — put the discipline in
  the prompt.** No hook reaches a sub-agent: measured 2026-08-21, 332 sub-agents
  edited a `.dart` file and the PreToolUse hook watching for exactly that fired
  zero times. The prompt you write is the only channel, so a dispatched sweep
  has this discipline only if you state it there.

Reporting:

- **A turn may not end on "next is X".** Either take X and report what
  happened, or say what is missing and who must supply it.「下一步是⋯」
  「我接著⋯」read as finished units of communication and are not — measured
  across three cycles, 27 turns were spent supplying a bare「繼續」.

- **In chat, name the rule, not its id.** Commit hashes, version numbers and
  internal rule names are the author's index; the reader cannot act on them. An
  identifier belongs in chat only when it is something to open or run. In a
  document it is the point — carry it, but gloss it once.
- **繁體中文用全形標點**：`，。：；！？（）`。程式碼與路徑除外。
