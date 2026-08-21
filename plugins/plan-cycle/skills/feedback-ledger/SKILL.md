---
name: feedback-ledger
description: |
  The bounded ledger of unconsumed feedback about how this project's own process
  and review gates are performing, in four categories: process · code-review ·
  security-review · privacy-review. One item = one markdown file; all writes go
  through `scripts/feedback.sh`. Review feedback is recorded whether it came from
  the reviewer AGENT or from the FOUNDER — the founder's correction of a review
  is the higher-signal half and the one most often lost. Consuming an entry means
  folding it into a rule, a skill or a deletion and then DELETING the file; a
  Stop hook nudges once per session when a category passes 5.
  TRIGGER: log feedback · record this feedback · file a retro entry · runner
  feedback · process retro · cycle retro · subtraction candidate · the reviewer
  was wrong · the reviewer missed this · this finding was over-reach · that gate
  misfired · feedback ledger · list the feedback · how much feedback is open ·
  tidy the feedback · consume the ledger · 記一下這個回饋 · 記錄回饋 · 這個
  reviewer 判錯了 · reviewer 漏掉了 · 這條 finding 過度了 · 這個 gate 誤擋 ·
  流程回饋 · 回饋有幾筆 · 整理回饋 · 看一下回饋
  NOT for: the /plan cycle itself → /plan (this is only its Step 6.7 sink) ·
  running a review → /review · in-flight thread state → /session-journal ·
  Notion backlog rows → /archivist · code-style or architecture rules →
  `.claude/rules/` (that is where a CONSUMED entry lands, not where it is filed)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
---

# Feedback ledger

Four categories, fixed. Each is a directory under `entries/`; each feedback item
is one markdown file in it.

| Category | What lands here |
|---|---|
| `process` | Friction in the `/plan` cycle — a gate that misfired, a step that duplicated another, the per-cycle retro (gate `R/H/L` + the mandatory subtraction candidate) |
| `code-review` | How `code-reviewer` performed — a finding that was over-reach, a real defect it missed, a pattern worth teaching it |
| `security-review` | Same, for `security-reviewer` |
| `privacy-review` | Same, for `privacy-reviewer` |

**Every entry names its `source`.** For the three review categories that is
`agent` (the reviewer raised it about itself, e.g. a finding it later withdrew)
or `founder` (Kai judged the review). **The founder half is the point** — an
agent's self-assessment is cheap and abundant; a founder saying "this finding was
over-reach" or "the review missed X" is the signal that actually improves the
gate, and it is the half that evaporates into chat if nobody files it. Process
entries use `runner` (the session that just executed a cycle) or `founder`.

## Operations — always through the script

`plan-feedback` is this plugin's launcher for the ledger script; it is on the
Bash tool's `PATH` whenever the plugin is enabled, so call it by bare name.

```bash
plan-feedback add <category> --source <founder|agent|runner> --title "<one line>" \
     [--cycle <slug>] <<'BODY'
…what happened, why it matters, what should change…
BODY

plan-feedback list [category]     # date · source · title · path
plan-feedback count [category]    # per-category counts (+ TOTAL when bare)
plan-feedback over [n]            # categories above n (default 5); silent + exit 0 if none
```

`add` is the only writer — it stamps the frontmatter (`category` / `source` /
`date` / optional `cycle`), slugifies the title into the filename, and never
overwrites an existing file. Don't hand-author entry files; the frontmatter is
what `list` and the `--cycle` gate read.

## The ledger is bounded, not append-only

This is the whole discipline, and the reason the old single-table ledger was
replaced: **collection is automatic, consumption is not.** Every cycle appends;
nothing prunes. So:

- **Consuming an entry means landing it somewhere durable** — a rule in
  `.claude/rules/`, a change to the owning skill, or a reasoned decision to drop
  it — and then **deleting the entry file** (`trash`, never `rm`).
- An entry that is "read and agreed with" but still on disk is **not consumed**.
- Never add a tombstone, a `— consumed —` divider, or a "done" marker. Git holds
  the history; the directory holds only what is still open.

`.claude/hooks/feedback-tidy.sh` (Stop) reminds **once per session** when any
category exceeds 5 — it prints nothing at all below the threshold, and the
one-shot marker is what keeps a reminder from becoming a per-turn nag. It never
tidies anything itself: what gets folded in and what gets dropped is the
founder's call.

## Who files what

- **`/plan` Step 6.7** files the per-cycle `process` entry at close-out, with
  `--cycle <slug>`. `plan-cycle.sh clear` greps `entries/` for that slug and
  **refuses to clear a shipped cycle until the entry exists** — so a dropped
  retro cannot pass silently. That gate is why `--cycle` matters.
- **`/review`** files a `code-review` / `security-review` / `privacy-review`
  entry whenever a finding was wrong, missed, or over-reaching — from either
  side. A normal clean review files nothing.
- **The founder**, any time, in any category.

## What this is not

- **Not the Notion TaskList.** An entry that turns out to be real backlog work
  becomes a TaskList row via `/archivist` — and then the entry is deleted.
- **Not a plan-cycle state ledger.** Where a cycle *is* lives in
  `.claude/.plan-cycle/` (gitignored, per-session); this holds what the cycle
  *taught us*.
- **Not a review log.** Reviewers are 不落檔 — they return findings inline; only
  the *lesson about the gate* is filed here.
