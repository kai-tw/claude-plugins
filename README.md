# claude-plugins

Kai's [Claude Code](https://claude.com/claude-code) plugins.

**Written for one person's workflow, published as-is.** Several plugins here
carry process specific to how Kai works — the house rules and the incidents
behind them, Notion KB conventions, review judgment, and a ledger of founder
corrections. Nothing is sanitised for an audience: a rule that exists because
something broke says so, with what broke. Read them as worked examples of
mechanisms, not as a framework to adopt — most are worth forking and cutting
down rather than installing whole.

## Usage

Add the marketplace once:

```bash
claude plugin marketplace add kai-tw/claude-plugins
```

Then install any plugin from it:

```bash
claude plugin install dart-lsp@kai-tw
```

## Plugins

| Plugin | Description |
| --- | --- |
| [dart-lsp](plugins/dart-lsp) | Dart/Flutter language server (Dart Analysis Server in LSP mode) for code intelligence |
| [flutter-toolkit](plugins/flutter-toolkit) | Flutter test gates for a shared machine: `plan-test` slot budget, per-line coverage and mutation score over the diff |
| [session-journal](plugins/session-journal) | Cross-session task-state journal — which threads are in flight and where each one lives, surviving context compaction, `/clear`, and resume |
| [google-reporting](plugins/google-reporting) | GA4 and Search Console readers via keyless service-account impersonation |
| [style-pack](plugins/style-pack) | The founder's cross-project 撰寫法: 母法 S1–S15 plus Dart/JS language files, printed by `style-pack` for any reviewer |
| [ui-text-pack](plugins/ui-text-pack) | The founder's cross-project 使用者可見文字撰寫法: 母法 U1–U5 plus zh-Hant / ja / en locale files, printed by `ui-text-pack` for any reviewer grading UI strings and their translations |
| [reclaim-space](plugins/reclaim-space) | Developer-disk reclamation on macOS: regenerable build output and toolchain caches, with a free-space floor on new git worktrees |
| [mother-tongue](plugins/mother-tongue) | Per-locale writing rules for the agent's own prose: detects the conversation's language each turn, attaches that locale's rules to the prompt, and blocks replies and commit messages that use its banned terms |
| [guardrails](plugins/guardrails) | Turns corrections into rules that fire — a bounded inbox, a fusion gate, and hooks that speak at the moment of the mistake |

## Scripts

Not plugins — standalone snippets pasted into a surface that has no plugin
mechanism at all.

| Script | Where it goes |
| --- | --- |
| [scripts/cloud-setup.sh](scripts/cloud-setup.sh) | The **Setup script** field of a [Claude Code cloud environment](https://code.claude.com/docs/en/cloud-environments#setup-scripts). Installs the pinned Flutter SDK, resolves dependencies for every Flutter repo the environment cloned, installs **every** `@kai-tw` plugin plus the plugins they depend on from other marketplaces (a missing one makes the CLI skip its dependant whole) and seeds them for later sessions, and installs `ntn` for the assistant's scribe — a fresh container has **no marketplace registered** and **no Notion credentials**, so without this the assistant silently isn't there. One copy serves NovelGlide, CherishCRM and any environment added later, because it discovers projects and plugins instead of naming them. Its filesystem result is snapshotted, so the ~1.5 GB SDK download is paid once per cache generation, not once per session. Needs three **Environment variables** set alongside it: `CLAUDE_CODE_PLUGIN_SEED_DIR`, `NOTION_API_TOKEN`, `NOTION_WORKSPACE_ID` (the script's header says why each one cannot be an export). |

## License

[MIT](LICENSE)
