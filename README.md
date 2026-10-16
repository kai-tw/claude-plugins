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
| [flutter-toolkit](plugins/flutter-toolkit) | Flutter test gates for a shared machine: `plan-test` slot budget, per-line coverage and mutation score over the diff (Dart and JS/TS) |
| [session-journal](plugins/session-journal) | Cross-session task-state journal — which threads are in flight and where each one lives, surviving context compaction, `/clear`, and resume |
| [google-reporting](plugins/google-reporting) | GA4 and Search Console readers via keyless service-account impersonation |
| [assistant](plugins/assistant) | The founder's assistant: request → decision brief → screens → PR, across projects. Ships the cross-project rulebooks its reviewers grade against: `style-pack` (code style, charter S1–S16 plus Dart, C# and JS) and `ui-text-pack` (user-visible text, charter U1–U5 plus zh-Hant, ja and en) |
| [reclaim-space](plugins/reclaim-space) | Developer-disk reclamation on macOS: regenerable build output and toolchain caches, with a free-space floor on new git worktrees |
| [mother-tongue](plugins/mother-tongue) | Per-locale writing rules for the agent's own prose: detects the conversation's language each turn, attaches that locale's rules and the English ones for code and commits to the prompt, and blocks replies and commit messages that use its banned terms |
| [guardrails](plugins/guardrails) | Turns corrections into rules that fire on their own: hooks that warn about or block a known mistake as it happens, and a short discipline loaded at session start |

## Scripts

Not plugins — standalone snippets pasted into a surface that has no plugin
mechanism at all.

| Script | Where it goes |
| --- | --- |
| [scripts/cloud-setup.sh](scripts/cloud-setup.sh) | What a [Claude Code cloud environment](https://code.claude.com/docs/en/cloud-environments#setup-scripts) runs at setup. The environment's **Setup script** field holds only [scripts/cloud-setup-field.sh](scripts/cloud-setup-field.sh), which fetches this file from `main` — never paste this one, and after merging a change to it, bump the version line in the field script and paste that again, or the snapshot keeps the old run. Installs the pinned Flutter SDK, resolves dependencies for every Flutter repo the environment cloned, installs **every** `@kai-tw` plugin plus the plugins they depend on from other marketplaces (a missing one makes the CLI skip its dependant whole) and seeds them for later sessions, and installs `ntn` for the assistant's Notion board — a fresh container has **no marketplace registered** and **no Notion credentials**, so without this the assistant silently isn't there. One copy serves NovelGlide, CherishCRM and any environment added later, because it discovers projects and plugins instead of naming them. Its filesystem result is snapshotted, so the ~1.5 GB SDK download is paid once per cache generation, not once per session. Needs three **Environment variables** set alongside it: `CLAUDE_CODE_PLUGIN_SEED_DIR`, `NOTION_API_TOKEN`, `NOTION_WORKSPACE_ID` (the script's header says why each one cannot be an export). |
| [scripts/cloud-runner-setup-field.sh](scripts/cloud-runner-setup-field.sh) | The Setup script field of the **one** cloud environment that runs self-hosted Actions jobs; every other environment keeps `cloud-setup-field.sh` and gets no runner. It runs `cloud-setup.sh` and then [scripts/cloud-runner-setup.sh](scripts/cloud-runner-setup.sh), which unpacks the Actions runner into `/opt/actions-runner` and installs [`cloud-ci-runner`](scripts/cloud-ci-runner.sh). That command runs `<owner/repo>`'s queued self-hosted jobs with one just-in-time runner per job (labels `self-hosted`, `flutter`, `linux`, `cloud`), then exits after 5 idle minutes. The environment needs `CI_RUNNER_TOKEN` (or `CI_RUNNER_TOKEN_<OWNER>` per owner) in its Environment variables: a token with administration write on each repo, since the session's own credentials can't register a runner. Its network access must reach GitHub's Actions hosts. One routine per repo on that environment, on Haiku, whose prompt runs `cloud-ci-runner <that repo>`; a PR's `wake-cloud-runner` job calls its `/fire` endpoint with the repo secrets `CLOUD_RUNNER_FIRE_URL` and `CLOUD_RUNNER_FIRE_TOKEN`. |

## License

[MIT](LICENSE)
