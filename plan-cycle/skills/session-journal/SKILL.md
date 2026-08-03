---
name: session-journal
description: >-
  Cross-session task-state journal — the institutional replacement for
  hand-written ~/.claude memory + ad-hoc task notes. Maintains a
  per-session, in-repo (gitignored) journal under docs/session-journal/ so work
  state survives context compaction, /clear, and resume: which task threads are
  in flight, WHERE each one lives (worktree / branch / PR# / Notion plan row),
  how the threads relate, and a bounded conversation-compression block
  (decisions / open questions / user direction / focus / next action) that the
  harness auto-summary drops. Two tiers: the durable cross-session index
  `_active.md` that EVERY new or cleared session reads, plus a per-session
  `<session-id>/` DIRECTORY holding `_detail.md` and any /plan draft files —
  a terminal SessionEnd trashes that WHOLE directory. Hooks inject it; this
  skill is the WRITE/maintain side. Use it PROACTIVELY, without being asked,
  whenever you start / pick up / close a task, create a worktree, open a PR, a
  plan changes revision, you make a load-bearing decision, or you sense a
  compaction is near — and at session start, to reconcile it against reality.
  Complements (never replaces) the Notion plan DBs, /plan and /archivist.
  TRIGGER: session journal · update the journal · record this task · track this
  thread · what's in flight · where was I · note where this lives ·
  記一下這個 task · 更新 journal · 在飛的 task 有哪些 · 我剛在哪個 worktree ·
  這個 thread 記一下
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
---

# /session-journal — Cross-session task-state journal

> **Iron Law:** state that tells you *where you are working* — worktree, branch,
> PR#, the Notion plan row and its gate — must live in the journal, not only in
> chat context. Chat context is erased by compaction and `/clear`; the journal
> is not.

## The failure mode this prevents

A session began as a bookmark fix (its own worktree, shipped as PR #33), then
drifted into a *different* feature's planning (AppTransfer) with only
auto-compaction in between — no `/clear`. Compaction quietly dropped the "I'm
inside the bookmark worktree" fact, and the continuation got confused about
which tree it was in and nearly redid shipped work. The journal makes that
impossible: the location of every live thread is written down and re-injected
after every compaction.

## Two-tier model + storage

All journal files live under **`docs/session-journal/`**, resolved against the
**main repo root** (so it is the same directory from inside any worktree) and
**gitignored** (local-only working state, never committed).

- **`_active.md` — cross-session index.** Every *unclosed* thread across all
  sessions, one compact block each, with a back-link to the owning session's
  detail file. This is the durable tier: it survives `/clear` and is read by
  every new session. A `/clear` mints a new session id, so without this index a
  fresh session would know nothing about threads it didn't itself open.

- **`<session-id>/` — per-session directory.** Holds this session's `_detail.md`
  (full thread detail + the conversation-compression block) **plus any /plan draft
  files** authored during the session's cycle (`engineering-plan.md`,
  `product-plan.md`, … — the bodies the archivist uploads byte-exact via
  `bodyFile`, so CJK is never re-typed at upload). The whole dir survives this
  session's compactions and `--resume` (same id). A `/clear` starts a new id + new
  dir and trashes this one via the SessionEnd hook — UNLESS an open `_active.md`
  thread still back-links it, so a **mid-cycle plan draft is kept until the thread
  closes**, then gc'd with the dir (this is exactly a draft's desired lifecycle —
  no separate cleanup). LEGACY sessions are a flat `<session-id>.md` file and
  coexist; they gc away over time.

Session id == `$CLAUDE_CODE_SESSION_ID` (it equals the transcript `.jsonl`
filename). You rarely need it directly — the script defaults to it.

## Use the script, don't hand-roll bash

`scripts/journal.sh` is the single, stable implementation of every mechanical
operation. The hooks and this skill both call it so path resolution and the file
skeletons never drift. Run it from anywhere (it self-anchors to the main root):

| Command | Use |
|---|---|
| `journal.sh dir` | print the journal directory |
| `journal.sh init [SID]` | create `_active.md` + this session's `<sid>/_detail.md` (idempotent) — **do this first** |
| `journal.sh detail-path [SID]` | path of a session's detail file (`<sid>/_detail.md`, or a legacy flat `<sid>.md`) |
| `journal.sh plan-path SID ARTIFACT` | path of a /plan draft inside the session dir (`<sid>/<artifact>.md`) — author the plan there, then hand it to the archivist as `bodyFile` |
| `journal.sh active-path` | path of `_active.md` |
| `journal.sh list [DAYS]` | show every journal file with its age + keep/GC status (use this to see what is deletable) |
| `journal.sh gc [DAYS]` | trash stale orphan detail files (default 14d) — runs automatically at session start; rarely run by hand |

`init` writes correctly-structured skeletons with the field layout baked in; you
then fill them with `Edit`/`Write`. `inject` and `cleanup` exist for the hooks —
you do not call those by hand.

## When to write

The journal is only useful if it is current. Update it at these moments — treat
them as the trigger, not an explicit user request:

- **Session start** — read what the hook injected, then reconcile it against
  reality (a PR may have merged, a worktree may now exist). Fix stale lines.
- **Open / pick up a task** — `journal.sh init`, add a thread block.
- **Create a worktree / open a PR / branch** — record *where the thread lives*
  immediately. This is the single highest-value field.
- **A plan changes revision or gate status** — update the thread's Plan line
  (link + Status/gate); the plan body itself stays in Notion.
- **A load-bearing decision, a user correction, or a fork resolved** — add it to
  the compression block while it is fresh.
- **You sense a compaction is near** (long turn, lots of tool output) — flush
  current focus + next action so the post-compaction self can recover.
- **Close a task** (merged / shipped / abandoned) — remove the thread from
  `_active.md` **and delete its block from the detail file too**. A fully
  completed task (shipped + closed out) leaves no record in either tier — don't
  leave a "done" stub behind; if it was the session's last thread, reset the
  detail file to the empty `init` skeleton. **"Closed out" means the Notion
  close-out actually landed** (e.g. the TaskList Stage is verified `Archived`) —
  delete the journal record only after that's confirmed, not on merge alone.

## `_active.md` — the cross-session index

Keep each thread to a compact block. Prune ruthlessly: a thread that has merged
or shipped must leave `_active.md` the same turn, because the hook re-injects
this file into *every* session — a stale "open" thread is actively misleading.
Per-thread fields: title · status, **Lives** (worktree / branch / PR# / main
tree), **Plan** (Notion row + id · Status/gate, omit if none), **Next** (one
line), **Detail** back-link, **Relations**.

**Edit individual thread blocks; never whole-file `Write` `_active.md`.** It is
the one file parallel sessions share, and it has no lock. A targeted block
`Edit` lets concurrent sessions' changes coexist — and a stale one fails loud
(`old_string` not found → re-read), which is the guard. A whole-file rewrite
clobbers another session's in-flight update. Add, change, or prune one block at
a time. (Per-session detail files are session-id-keyed, so they never contend —
this rule is only about the shared index.)

## `<session-id>/_detail.md` — the detail file

Two parts: a **Threads** section (one block per thread with Lives / Plan /
Progress / Next / Relations) and a **Conversation compression** block. (Its
sibling `/plan` draft files in the same `<sid>/` dir are authored by the plan
roles and uploaded via `bodyFile`, not covered by this file's discipline.)
Discipline that keeps it useful:

- **Update in place** — overwrite the relevant lines; never append a running log.
  Git is not tracking this, so there is no history to preserve here.
- **Bounded** — keep the whole file under ~150 lines, each thread under ~12. If
  it grows past that, you are dumping transcript, not compressing.

## Conversation compression — the part the harness summary drops

The harness auto-summary captures the gist of the dialogue but loses exactly the
load-bearing scaffolding: which task/plan, where it lives, how threads relate,
and *why* a decision was made. That scaffolding is this block's job. Fill these
five lines and keep them tight:

- **Key decisions** — what was decided **and why** (the why is what you can't
  reconstruct later).
- **Open questions** — unresolved forks awaiting an answer.
- **User corrections / direction** — steers the user gave, near-verbatim.
- **Current focus** — the one thing in hand right now.
- **Next action** — the immediate next step.

## Relationship vocabulary

Name how threads relate so a future session doesn't treat a blocked thread as
ready:

- **deferred-behind** — X waits on Y (X cannot start until Y reaches a point).
- **blocks** — X blocks Y (the inverse, stated from X's side).
- **sibling** — same cycle, independent, can proceed in parallel.
- **parent** — both belong to one parent feature.
- **supersedes** — X replaces Y; Y should be closed/abandoned.

## What is automatic vs your job

- **Automatic (hooks):** the SessionStart hook injects `_active.md` + this
  session's detail file on startup / resume / clear / compact, and runs a light
  `gc` first. The SessionEnd hook trashes the per-session detail file on a
  *terminal* end. `_active.md` always persists. **Worktree self-identification:**
  the inject also reads this tree's git branch — when it *uniquely* matches a
  thread's `Lives:` line, a ▶ banner names that thread so a `/clear`'d worktree
  session resumes the right one without being told. A shared `dev`/`main` branch
  (all planning threads sit on it) or an ambiguous match never auto-binds — it
  falls back to the plain index for you to pick from.
- **Automatic (write-side nudge):** a `PostToolUse` hook
  (`session-journal-nudge.sh`) fires a one-shot reminder the moment you enter a
  worktree (`EnterWorktree`) or run a `gh pr create` / `git worktree add` /
  `git push -u` — the exact actions that mint the highest-value `Lives:` field,
  mid-session, after the SessionStart reminder has scrolled out of context. It is
  non-blocking (just a prompt to record where the thread lives); acting on it is
  still your job.
- **Your job (this skill):** keeping the content true. The hook re-injects
  whatever you last wrote — garbage in, garbage re-injected. Prune `_active.md`
  when a thread closes; that is also what lets `gc` reclaim the detail file.

## Lifecycle & cleanup — what gets deleted, and when

Deletion uses `trash` (recoverable), never `rm`. There is one **retention rule**
that both the SessionEnd cleanup and `gc` obey:

> A detail file is **never** deleted while it is the current session, while it is
> `_active.md`, or while an **open `_active.md` thread still back-links to it**.
> Everything else is an orphan.

- **`/clear` or logout** (SessionEnd) → trashes *that session's* detail file —
  unless it is still referenced by an open thread (then it is kept; the work
  isn't done). A plain quit / Ctrl-C does **not** delete (it may be resumed).
- **Session start** (every startup / resume / clear / compact) → `gc` trashes
  orphan detail files that are stale. "Stale" is measured against the **newest
  session in the chain**, not wall-clock: a file is only eligible when it is
  more than `DAYS` (default 14) older than the most recently active session. So
  while a chain of sessions is still being worked, its older members survive —
  *the old ones are still useful*. Once the whole chain goes quiet the reference
  stops advancing and nothing new becomes eligible.

To see what is deletable, run **`journal.sh list`** — it prints each file's age
and one of: `KEEP` (current / index / referenced), `GC-eligible`, or `orphan,
kept (within window)`. This is the answer to "which journals can I delete": the
`GC-eligible` ones (and `gc` will take them itself).

## Division of labor

- **Notion plan DBs are the source of truth for plan content** (PM / design /
  engineering). The journal only *links* to the row and records its
  Status/gate + where the thread lives + how it relates. Never duplicate plan
  bodies here. Route Notion reads/writes through `/archivist`.
- **`/plan`** authors and gates plans; the journal tracks where a `/plan` cycle
  is parked (which phase, gate-clean or not, awaiting which approval).

## What this is not

- **Not the Notion plan DB** — that holds plan content; this holds working
  state + pointers.
- **Not the machine-local auto-memory** (`~/.claude/projects/<id>/memory/`) —
  that is cross-cutting corrections, preferences, and reference. The journal is
  task/thread working-state. This system *retired* the hand-written in-flight
  threads register memory.
- **Not a commit log or changelog** — git owns history. The journal tracks
  current state only; update in place.
- **Not a verbatim transcript** — the compression block is bounded and
  structured. If you are pasting dialogue, stop and compress.
- **Not test plans / qa-logs** — those have their own owners under `docs/`.
