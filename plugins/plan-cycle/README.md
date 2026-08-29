# plan-cycle

The gated planning cycle — PM → designer → engineer → code → QA → close-out,
with a Stop-hook ledger that blocks turn-end when the cycle advanced past a plan
phase whose Notion row never landed.

## Install

```
/plugin marketplace add kai-tw/claude-plugins
/plugin install plan-cycle@kai-tw
```

To develop against a local checkout instead:

```
claude --plugin-dir ~/GitHub/claude-plugins/plugins/plan-cycle
```

## Why this marketplace is private

This plugin carries process that is specific to how Kai works: the house
rules and the incidents behind them, the Notion KB conventions, the review
judgment. That is not shareable material, which is why the whole
`kai-tw/claude-plugins` marketplace is private.

Generally useful tooling still lives here — `dart-lsp`, `session-journal` —
it simply is not published. If any of it ever becomes worth sharing, moving
it out is a per-plugin decision, not a reason to loosen this one.

**`plan-cycle` assumes `session-journal@kai-tw` is installed.** The cycle records
which threads are in flight and where each one lives, and that journal is the sibling
`session-journal` plugin's job — including its three hooks (inject, nudge, cleanup) that no
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
   notion-payload <cmd> … --root <page-id>
   ```

   Omitting it aborts on purpose — a default root would write one project's
   plans into another project's workspace. Only the commands that actually need
   a data source or the project's live vocabulary resolve the KB
   (`create` / `update` / `set` / `filter`, and `schema` when you pass a root);
   the structural ones a planning cycle calls over and over — `hints`,
   `criteria` — read the embedded schemas and stay offline and instant.

Architecture guidance goes in the project's own `.claude/rules/`. Two optional
files let a project extend the plugin without editing it:

| File | Extends |
|---|---|
| `.claude/pm-vocabulary.txt` | the PM abstraction checker's leaky-term list — one extended-regex fragment per line |
| `.claude/kb-databases.txt` | the Notion database titles resolved under the KB root — `<registry-key> = <exact title>`, one per line |

`kb-databases.txt` exists because a project may title its databases in its own
language. The plugin's defaults are English (`Release Log`, `TaskList`, …); a KB
that calls one of them `版本紀錄` maps it there rather than renaming the database
or teaching the plugin one project's vocabulary. Get it wrong and the failure
now says so — a registry key the plugin knows but the workspace did not yield
reports the title it looked for and points at this file, instead of the database
silently vanishing from the registry.

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

## How this plugin refers to its own files

A plugin installs to `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`
— a path that no skill file can hardcode and that moves on every version bump.
So nothing here refers to itself by a project-relative `.claude/skills/…` path;
that would resolve inside the *consuming project*, where these files do not
exist. Two mechanisms, by what is being referred to:

- **Scripts → a bare command.** `bin/` is on the Bash tool's `PATH` whenever the
  plugin is enabled, so every script has a launcher there and is invoked by name
  from anywhere: `plan-cycle`, `notion-payload`, `plan-lint`, `plan-scope-gate`,
  `pm-abstraction-check`, `render-mockups`, `plan-feedback`, `plan-test-first`.
  The implementations
  stay with the skills that own them; `bin/` holds three-line `exec` launchers.
  Names carry a `plan-`/`pm-` prefix where the bare word would be too generic
  for a global `PATH`, or would collide with a skill of the same name
  (`plan-feedback` vs the `feedback-ledger` skill).
- **Files to read → `${CLAUDE_PLUGIN_ROOT}/skills/…`.** The harness expands that
  token when it injects a `SKILL.md`, so a skill body gets a real absolute path.
  It does **not** expand inside reference files an agent opens with `Read`, or
  inside YAML frontmatter — there the token stays literal and the reader
  substitutes the plugin root it was already given. Frontmatter therefore names
  the owning **skill** ("the `qa` skill") rather than a path, because that text
  is shown in listings where nothing can expand it.

One path is deliberately *not* a plugin path at all: the feedback ledger's
entries are the **project's** data, resolved from the git root and living at
`docs/feedback-ledger/entries/`. It sits under `docs/` rather than
`.claude/skills/feedback-ledger/` precisely because the skill ships with this
plugin — writing data into a skill directory the consuming project does not
have would leave an orphan folder with no `SKILL.md` beside it.

`feedback.sh` holds the only definition of that path and exposes it as
`plan-feedback dir`; `plan-cycle`'s close-out gate asks for it instead of
keeping a second copy. Two copies of a path that must always agree is a defect
waiting for the day they don't — and here the stale copy would have failed
*silently*, because a wrong path reads as "no retro filed" and blocks close-out
forever rather than erroring. Relocating the ledger is now one line in
`feedback.sh`.

## The ledger

`bin/plan-cycle` is on the Bash tool's `PATH` whenever the plugin is enabled,
so the archivist mirrors each Notion write with a bare command — no path, no
knowledge of where the plugin is installed:

| The Notion write | Mirror it with |
|---|---|
| Created the TaskList task | `plan-cycle start "<slug>" "<Task Name>"` |
| Flipped the task's `Stage` | `plan-cycle enter "<Stage>"` |
| Wrote a plan row (after verify) | `plan-cycle uploaded <pm\|designer\|engineer> <url>` |
| Posted a `/review` report to the PR | `plan-cycle reviewed <the sha reviewed>` |
| Closed out | `plan-cycle clear` |

It no-ops silently when no cycle is active, so the calls are safe to run
unconditionally.

`check` runs six gates, each blocking turn-end on its own evidence rather than
on a flag: **0** — commits held unpushed on a worktree branch; **1** — a plan
phase advanced past without its Notion row; **2** — a merged PR with no
close-out; **3** — an open PR whose branch has run too far past the last
reviewed sha; **4** — a `// review-dismiss:` marker that breaks its own one-line /
specific-reason rule; **5** — an existing test edited while the stage is
`Implementation`, with no `// test-change:` reason at the site. Gates 0 and 4
need no ledger; Gate 5 needs one, because "the implementation loop is running"
is a cycle fact with no signal in git.

`sweep` runs at SessionStart and only reports. It covers the two things no gate
can: a merged PR whose cycle ledger was opened in some other session, and —
reading git rather than the ledger — branches and worktrees still standing after
their PR merged. That second half exists because `clear`'s teardown check is the
last thing that ever looks, and `clear` deletes the ledger that would have asked
again. Merge state comes from `gh` (only when git finds candidates, so the steady
state makes no network call) and every failure path reports nothing.

`hooks/plan-cycle-gate.sh` is the Stop-hook adapter: it translates the ledger's
exit-1-plus-reason into the `{"decision":"block"}` JSON the hook expects. It
runs **only** the gate — formatters, builds, and tests stay in each project's
own Stop hook, since those differ per repo.

Every failure path in the adapter exits 0 with no output. A planning gate that
blocked turn-end because `jq` was missing would be worse than the context decay
it exists to prevent.
