---
id: retro
kind: native
summary: "runner 回饋：逐 gate R/H/L、量測列、必填的刪除候選"
consumes:
  - feature-archive
produces:
  - retro-entry
stop: "false"
---
# Block: retro

> 輸入 `feature-archive`＝已收尾的 cycle；輸出 `retro-entry`＝feedback ledger 的一筆
> `process` 條目。**每個 cycle 都跑，不是選配。**

## 這是減法通道

The process grows by default — every incident adds a rule, every gap adds a
gate — and nothing prunes it. This is the counterweight: the **runner** (the
session that just executed a full cycle) holds the best friction data and logs
it while hot; the founder consumes it in batches and rules on subtractions.

- **Collect (every cycle — Step 6.7):** file one `process` entry via the
  `feedback-ledger` skill — per-gate `R/H/L` (confirmed-real findings /
  hallucinated-or-dismissed / loops to clean), the **measurement row** (three
  integers that say whether the gates are actually moving the failure earlier:
  founder findings at PR review **by kind** — reuse / process-consistency /
  other; `plan-lint --diff` reconciliation deltas this cycle; recurring bugs —
  a defect class this codebase has fixed before, back again), friction events
  (spurious ledger blocks, steps that duplicated another), and a **mandatory
  subtraction candidate** ("if I could delete one step this cycle: X, because
  Y"). Never blank — "nothing to delete" requires naming the runner-up step
  and why it survives. The measurement row is what the batch consume reads as
  a trend: a gate whose kind-count refuses to fall is not doing its job, and a
  HARD check whose `H` beats its `R` for consecutive cycles is a subtraction
  candidate by number, not by feel. **Any non-zero count owes entries of its
  own**: each founder finding lands in its review category, each recurring bug
  lands in `recurring-bug` (anchoring the prior fix it undoes AND the new
  sighting), and this retro entry lists those filenames — the counts are the
  trend, the entries are what a consume batch can act on.
- **Consume (when `plan-cycle clear` nudges at close-out, or on founder
  demand):** read the entries, aggregate per-gate hit rates + the most-nominated
  subtraction candidates, route each category to its named destination
  (`feedback-ledger §Consume routing` — recurring-bug goes to the qa
  failure-class index or the consistency mechanism table, never to prose), and
  put demote / delete / keep proposals to the founder via
  `AskUserQuestion`. Apply approved edits to the skill files, then **delete each
  consumed entry file** — an entry that survives its own consumption is the
  one-way growth this channel exists to prevent. A still-unresolved item stays
  as its own entry rather than riding along inside a consumed one, so nothing is
  silently dropped. Only delete an entry whose cycle is already cleared (shipped
  + closed out), so `plan-cycle.sh clear`'s slug check never fails on a
  still-open cycle. Proposal power is the runner's; ruling power is the
  founder's.
- **Guardrails:** the ledger records **verifiable facts**, not feelings — a
  gate that blocked you is not thereby friction (that may be the gate
  working). Read `0 findings` as possible deterrence, not automatic waste;
  hallucinated findings are pure cost. And this mechanism must stay lighter
  than what it prunes: one row in, one batched review out — if the retro
  itself starts growing steps, it goes on its own ledger.

New gates enter **on probation** — named on the ledger's watch list, first
subjects of the next retro (`feasibility-reviewer`, added 2026-07-08, is the
inaugural entry).
