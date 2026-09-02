---
name: guardrails
description: >-
  The rules that fire on their own — a PreToolUse check on every Bash command
  and a discipline block carried at session start. Use when a correction lands
  that should change what happens next time, when a rule fired and you want to
  know why, or when a rule fires on healthy commands.
  TRIGGER: 記一條 guardrail · 這個要記起來 · 加一條規則 · 為什麼會擋我 ·
  add a guardrail rule · why did that fire · guardrails 是什麼 ·
  this rule is too noisy
---

# Guardrails

Two rule sets, each read by its own hook. Nothing else.

| Rule set | Hook | When it speaks |
|---|---|---|
| `rules/tool.tsv` | `PreToolUse` on Bash | before a matching command runs |
| `rules/discipline.md` | `SessionStart` | injected once, binds every turn |

## The bar

**A rule belongs here only if the idiom fails SILENTLY** — it hands back a
confident wrong answer rather than an error. Anything that errors out already
announces itself, and a rule that fires on healthy commands teaches the reader
to dismiss the warning; after which the one that mattered is dismissed too. **A
bloated rule set is worse than no rule set.**

Two more gates, both required: it **actually happened** (not a hazard someone
imagined), and it is **still true in another repo** — otherwise it belongs to
that project's own memory.

## Adding one

Edit the file, then release: this is a plugin, so a rule reaches anyone only
through a version bump (`.claude/rules/releasing.md`).

**`tool.tsv`** — one tab-separated line: `id⇥ERE⇥message⇥incident`. The pattern
is inadmissible until you have shown it catches the bad command **and leaves a
healthy one alone**; an untested pattern is how this turns into wallpaper.

**`discipline.md`** — prose, injected verbatim. Keep it short for the same
reason: every line costs context in every session, so a line that does not
change behaviour is a line that dilutes the ones that do.

**Fuse, never append.** A lesson that is a special case of an existing rule
rewrites that rule. Ask first whether one of the existing rules already covers
it — growing a sibling is how a set stops being read.

## What does not belong here

- How Kai wants to be worked with → the `house-rules` skill.
- Facts about one repo's configuration → that project's own memory.
- Anything that already errors out. The bar is **silent** failure: a confident
  wrong answer, not a stack trace.
