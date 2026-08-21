---
name: guardrails
description: |
  File and consume this project's guardrails ledger — the loop that turns a
  correction into a rule that fires on its own. Use when a founder correction
  lands, when something returned a confidently wrong answer, or when the Stop
  hook says the ledger is drifting.
  TRIGGER: 記一條 guardrail · 這個要記起來 · 消費 ledger · 整理 guardrails ·
  file this correction · consume the ledger · why did that fire ·
  add a guardrail rule · guardrails 是什麼
---

# Guardrails

A correction is worth something only if it changes what happens next time.
This is the path from one to the other.

```
correction  →  entries/  →  consume  →  rules/  →  a hook says it out loud
              (blind)      (fusion)    (fused)     (at the moment, unprompted)
```

## The two disciplines are opposite, deliberately

**`entries/` takes anything.** An inbox with a bar is an inbox nobody fills, and
the founder correction that evaporated into chat is the one signal that would
have improved something. File it rough; file it now.

**`rules/` takes almost nothing.** A rule speaks out loud on its own. Past a
dozen per category nobody reads the set, and a rule that fires on healthy
commands teaches the reader to dismiss the warning — after which the one that
mattered is dismissed too. **A bloated rule set is worse than no rule set.**

`consume` is the filter, and it refuses a bare append.

## Filing

**File without asking.** If it clears the three gates below, it goes in — do not
surface it as a suggestion and wait for a yes. An inbox that costs a round-trip
to fill is an inbox that stays empty, and the correction that was never filed is
the whole problem this exists to solve. Founder ruling, 2026-08-21:「有過門檻的
都自動 file 好了，那邊本來就是要廣泛收集的地方」.

The gates, all three:

1. **Silent** — it hands back a confident wrong answer rather than an error.
   Anything that errors out announces itself and needs no entry.
2. **Actually hit** — it happened. Not a hazard someone imagined.
3. **Still true in another repo** — otherwise it belongs to that project's own
   memory rather than here.

A cause you have not diagnosed is still worth filing: say so in the body and it
waits for whoever works it out. Losing it is the only unacceptable outcome.

`entries/` is git-tracked, so filing writes to the working tree; committing
stays a deliberate act.


```bash
gr add tool --source founder --title "<one line>" <<'BODY'
What happened, and what it cost. Name the command or the claim.
BODY
```

`--source founder` is the half that matters — an agent grading itself is cheap
and abundant. Categories: `tool` (fires before a Bash command) · `claim` · `report` ·
`scope` (carried at session start).

## Consuming

`gr consume <entry>` with no declaration prints the existing rules and stops.
That is the point: **read them first, and ask whether this is a special case of
one you already have.**

- `--extends <id> --message "<merged wording>"` — the usual answer. Rewrite the
  existing rule so it covers both cases.
- `--new --id … --pattern … --message …` — only when nothing covers it. In
  `tool`, also `--fires-on` / `--quiet-on`: a pattern is inadmissible until it
  is shown to catch the bad command **and leave a healthy one alone**. Untested
  patterns are how this turns into wallpaper.
- `--drop "<why>"` — a reasoned drop is a real outcome.

Either way the entry file is deleted. An entry that was read and agreed with but
is still on disk was **not** consumed.

## What does not belong here

- How Kai wants to be worked with → the `house-rules` skill.
- Facts about one repo's configuration → that project's own memory.
- Anything that already errors out. The bar is **silent** failure: a confident
  wrong answer, not a stack trace. Errors announce themselves and need no rule.
