---
name: feedback-ledger
description: >-
  The bounded ledger of unconsumed feedback on this project's process and review
  gates: process · code-review · security-review · privacy-review ·
  recurring-bug. One entry = one file via `scripts/feedback.sh`; consuming =
  fold into a rule / skill / failure-class bucket, then delete the file.
  TRIGGER: log feedback · the reviewer was wrong / missed this · that gate
  misfired · 記錄回饋 · 整理回饋
  NOT for: the /plan cycle itself · running a review → /review · rules →
  `.claude/rules/` (where a consumed entry lands)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
---

# Feedback ledger

Five categories, fixed. Each is a directory under `entries/`; each feedback item
is one markdown file in it.

| Category | What lands here |
|---|---|
| `process` | Friction in the `/plan` cycle — a gate that misfired, a step that duplicated another, the per-cycle retro (gate `R/H/L` + the measurement row + the mandatory subtraction candidate) |
| `code-review` | How code review performed — a finding that was over-reach (`code-reviewer` filed it rather than 駁回 it), a real defect missed (`code-reviewer` never raised it, or raised it and wrongly 駁回), a pattern worth teaching either |
| `security-review` | Same, for `security-privacy-reviewer`'s **security** lens (threat model, leak paths) |
| `privacy-review` | Same, for its **privacy** lens (minimization, attestation) — one agent, but keep the lenses as separate categories: a consume batch needs to see which lens is misfiring |
| `recurring-bug` | **A defect class this codebase fixed before, back again** — caught by the founder at PR review, hit by `/qa` while authoring, or counted in the retro's measurement row. The entry must anchor **both ends**: the prior fix (commit / incident / test id) and the new sighting (file:line or minimal repro). 「又來了」 without anchors cannot be consumed into a check — the anchors are what become the mutation pin or the mechanism-table checkpoint. |

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

**Consume routing — each category has a named destination**, so a consume batch
is a sort, not a debate about where things go:

| Category | Lands in |
|---|---|
| `process` | the owning skill file / a deleted step (the subtraction channel) |
| `code-review` | `code-reviewer.md` — the rubric it rules against, or its ruling discipline — the `style-pack` plugin's rules (a 撰寫法 the review keeps missing — via its `CONVENTIONS.md` learning 更新法), or a `.claude/rules/` line |
| `security-review` / `privacy-review` | the matching rule pack, via its `CONVENTIONS.md` learning 更新法 |
| `recurring-bug` | **one of two, both checks**: the qa failure-class index (a new bucket, or a mutation pin / case template on an existing one — `qa/failure-classes.md`) or the project's `.claude/rules/consistency.md` mechanism table (a checkpoint the mechanism's canonical helper must now enforce). A recurring bug consumed into prose has not been consumed. |

No automatic nudge: the founder checks the ledger with `plan-feedback over <n>`
and `plan-feedback count recurring-bug`, and decides what is folded in or
dropped.

## Who files what

- **`/plan` Step 6.7** files the per-cycle `process` entry at close-out, with
  `--cycle <slug>`. `plan-cycle.sh clear` greps `entries/` for that slug and
  **refuses to clear a shipped cycle until the entry exists** — so a dropped
  retro cannot pass silently. That gate is why `--cycle` matters.
- **`/review`** files a `code-review` / `security-review` / `privacy-review`
  entry whenever a finding was wrong, missed, or over-reaching — from either
  side. A normal clean review files nothing.
- **Any non-zero count in Step 6.7's measurement row owes entries.** The counts
  are the trend; the entries are the content a consume batch acts on. A founder
  finding at PR review → its review category (`--source founder`); each
  recurring bug → `recurring-bug`; the retro `process` entry lists those entry
  filenames so the batch finds them together.
- **`/qa`** files a `recurring-bug` entry (`--source agent`) when a test it
  authors catches a bug class the failure-class index says shipped before.
- **The founder**, any time, in any category.

## What this is not

- **Not the Notion TaskList.** An entry that turns out to be real backlog work
  becomes a TaskList row via `/archivist` — and then the entry is deleted.
- **Not a plan-cycle state ledger.** Where a cycle *is* lives in
  `.claude/.plan-cycle/` (gitignored, per-session); this holds what the cycle
  *taught us*.
- **Not a review log.** Reviewers are 不落檔 — they return findings inline; only
  the *lesson about the gate* is filed here.
