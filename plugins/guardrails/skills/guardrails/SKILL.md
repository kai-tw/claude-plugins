---
name: guardrails
description: >-
  Rules that fire on their own — hooks that warn about or block known mistakes
  as a command runs, and a short discipline loaded at session start. Use when a
  correction should change what happens next time, when a rule fired and you
  want to know why, or when a rule fires on healthy commands.
  TRIGGER: add a guardrail rule · remember this · why did that fire · why was
  I blocked · what are guardrails · this rule is too noisy · 記一條 guardrail ·
  這個要記起來 · 加一條規則 · 為什麼會擋我 · guardrails 是什麼
---

# Guardrails

Two sets of rules, each loaded by its own hook. That's all.

| Rules | Hook | When they speak up |
|---|---|---|
| `rules/tool.tsv` | `PreToolUse` on Bash | just before a matching command runs |
| `rules/discipline.md` | `SessionStart` | loaded once, applies to every turn |

Five more rules live outside both sets because they **block** the command
instead of warning. Each is a hook of its own, so `intercept.sh` can keep its
promise never to block — that promise is what lets it speak up on every command
without turning into noise.

| Hook | Named after | Blocks |
|---|---|---|
| `hooks/charon.sh` | the ferryman of the Styx — a one-way trip | deleting with whichever of `rm` / `trash` this machine does NOT have |
| `hooks/palimpsest.sh` | a manuscript scraped clean and written over | a force-push or a delete aimed at `main` / `master` — force-pushing any other branch is fine |
| `hooks/godot.sh` | Beckett's two tramps, waiting by the tree | polling — `gh pr checks --watch`, `gh run watch`, `watch`, a loop that sleeps — in Bash or Monitor; schedule a one-off check instead |
| `hooks/shadow.sh` | Andersen's shadow that walks off on its own | a process detached from the call — `nohup`, `disown`, `setsid`, or a `&` never `wait`ed for; the harness can't see it, so use Bash's `run_in_background` |
| `hooks/babel.sh` | Borges' library of every book, with no catalogue | a recursive search — `find`, `fd`, `rg`, `ag`, `grep -r`, `ls -R`, `tree`, the Grep tool, the Glob tool with `**` — starting at `/`, the home folder, `/Users`, `/home` or `/Volumes`, more than 2 levels deep; search the one folder the file belongs in |

A blocking hook is only worth having where a `permissions` rule can't do the
job: the decision needs something the command string doesn't contain (which
binary exists here, which branch you're on), or the block has to name the
alternative (a bare deny just sends the agent to the next way of doing the same
thing). Anything a warning can handle stays a warning.

## The bar

**A rule belongs here only if the mistake fails SILENTLY** — it hands back a
confident wrong answer instead of an error. Anything that errors out already
announces itself, and a rule that fires on healthy commands teaches the reader
to ignore warnings; then the one that mattered gets ignored too. **A bloated
rule set is worse than none.**

It also has to pass two more tests: it **actually happened** (not a risk someone
imagined), and it **still holds in another repo** — otherwise it belongs in that
project's own memory.

## Adding one

Edit the file, then release: this is a plugin, so a rule only reaches anyone
through a version bump (`.claude/rules/releasing.md`).

**`tool.tsv`** — one tab-separated line: `id⇥ERE⇥message⇥incident`. Don't add a
pattern until you've shown it catches the bad command **and leaves a healthy
one alone**; untested patterns are how this turns into wallpaper.

**`discipline.md`** — prose, loaded word for word. Keep it short for the same
reason: every line costs context in every session, and a line that doesn't
change behaviour dilutes the ones that do.

**Merge, don't append.** A lesson that's a special case of an existing rule
rewrites that rule. Check first whether one already covers it — adding siblings
is how a rule set stops being read.

## What doesn't belong here

- Facts about one repo's setup → that project's own memory.
- Anything that already errors out. The bar is a **silent** failure: a confident
  wrong answer, not a stack trace.
