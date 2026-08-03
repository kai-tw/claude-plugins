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
