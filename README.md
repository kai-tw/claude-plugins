# claude-workflow

A Claude Code plugin marketplace holding the planning workflow shared across
Kai's projects.

## What's here

**`plan-cycle`** — the gated planning cycle: PM → designer → engineer → code →
QA → close-out, with a Stop-hook ledger that blocks turn-end when the cycle
advanced past a plan phase whose Notion row never landed.

## Install

```
/plugin marketplace add kai-tw/claude-workflow
/plugin install plan-cycle@kai-workflow
```

To develop against a local checkout instead:

```
claude --plugin-dir ~/GitHub/claude-workflow/plan-cycle
```

## Why this marketplace is private

The plugin here carries process that is specific to how Kai works: the house
rules and the incidents behind them, the Notion KB conventions, the review
judgment. That is not shareable material, so it lives in a private marketplace.

Generally useful tooling belongs in the **public** marketplace instead —
[`kai-tw/claude-plugins`](https://github.com/kai-tw/claude-plugins), which holds
`dart-lsp` and `session-journal`. Before adding anything here, check whether it
is actually general; if it is, it goes there.

**`plan-cycle` assumes `session-journal@kai-tw` is installed.** The cycle records
which threads are in flight and where each one lives, and that journal is the
public plugin's job — including its three hooks (inject, nudge, cleanup) that no
skill file can replace. Do not vendor a copy here.

## Per-project setup

Two things each consuming project must provide:

1. **Gitignore the ledger.** `bin/plan-cycle` writes session-scoped state into
   the project tree. Add to the project's `.gitignore`:

   ```
   .claude/.plan-cycle/
   ```

   Skip this and a per-session ledger lands in a commit.

2. **State the Notion KB root page id in the project's `CLAUDE.md`.** The
   archivist resolves every database by title among that page's children, so
   this is the only Notion id a project records. Every call passes it:

   ```
   node <plugin>/skills/archivist/scripts/notion_payload.mjs <cmd> … --root <page-id>
   ```

   Omitting it aborts on purpose — a default root would write one project's
   plans into another project's workspace.

Architecture guidance goes in the project's own `.claude/rules/`; optional
project-specific PM vocabulary goes in `.claude/pm-vocabulary.txt`.

If the project runs work in worktrees, invoke the **`worktree-setup`** skill
once per repo. It derives that project's `.worktreeinclude` and init step from
what the project actually generates, instead of copying a file list that
encodes some other project's build.

## The layering rule

The plugin ships **process**, never **architecture**. The split follows one
test — does the thing a rule constrains have a file path?

| | Lives in | Example |
|---|---|---|
| **Process** | this plugin | the phase sequence, the upload gate, review judgment, escalation |
| **Architecture** | the consuming project's `.claude/rules/` | state management, DI, error handling, naming |
| **KB config** | the consuming project's `archivist` | Notion DB ids, the feature taxonomy |

A rule with a file path belongs to the project, because projects disagree:
CherishCRM is Riverpod, NovelGlide is Cubit. Shipping either one's architecture
here would hand the other actively wrong guidance. There is deliberately no
SOP layer in this plugin — architecture guidance lives in `.claude/rules/`.

## The ledger

`bin/plan-cycle` is on the Bash tool's `PATH` whenever the plugin is enabled,
so the archivist mirrors each Notion write with a bare command — no path, no
knowledge of where the plugin is installed:

| The Notion write | Mirror it with |
|---|---|
| Created the TaskList task | `plan-cycle start "<slug>" "<Task Name>"` |
| Flipped the task's `Stage` | `plan-cycle enter "<Stage>"` |
| Wrote a plan row (after verify) | `plan-cycle uploaded <pm\|designer\|engineer> <url>` |
| Closed out | `plan-cycle clear` |

It no-ops silently when no cycle is active, so the calls are safe to run
unconditionally.

`hooks/plan-cycle-gate.sh` is the Stop-hook adapter: it translates the ledger's
exit-1-plus-reason into the `{"decision":"block"}` JSON the hook expects. It
runs **only** the gate — formatters, builds, and tests stay in each project's
own Stop hook, since those differ per repo.

Every failure path in the adapter exits 0 with no output. A planning gate that
blocked turn-end because `jq` was missing would be worse than the context decay
it exists to prevent.
