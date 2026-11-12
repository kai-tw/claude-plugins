# claude-plugins

Kai's [Claude Code](https://claude.com/claude-code) plugins.

**Written for one person's workflow, published as-is.** Several plugins here
carry process specific to how Kai works — the house rules and the incidents
behind them, Notion KB conventions, review judgment, and a ledger of Kai's
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
| [flutter-toolkit](plugins/flutter-toolkit) | Flutter testing on a shared machine: `plan-test` concurrency limit, line coverage over the diff |
| [assistant](plugins/assistant) | An assistant for your projects: request → decision brief → screen review → PR. Ships the cross-project rulebook its reviewers check against: `style-pack` (code style, core rules S1–S16 plus Dart, C# and JS) |
| [reclaim-space](plugins/reclaim-space) | Developer-disk reclamation on macOS: regenerable build output and toolchain caches, with a free-space floor on new git worktrees |
| [mother-tongue](plugins/mother-tongue) | Per-locale writing rules for the agent's own prose: detects the conversation's language each turn, attaches that locale's rules and the English ones for code and commits to the prompt, and blocks replies, commit messages, and comments or docs written to files that use its banned terms |

## Development

After cloning, run `git config core.hooksPath .githooks` so a commit with a
secret in it is blocked by [gitleaks](https://github.com/gitleaks/gitleaks)
(`brew install gitleaks`). CI runs the same scan on every push.

## License

[MIT](LICENSE)
