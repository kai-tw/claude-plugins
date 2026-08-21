# claude-plugins

Kai's [Claude Code](https://claude.com/claude-code) plugins.

**This marketplace is private.** Several plugins here carry process specific to
how Kai works — the house rules and the incidents behind them, Notion KB
conventions, review judgment, and a ledger of founder corrections. That is not
shareable material, and keeping the marketplace private is what lets a plugin
record an incident honestly instead of sanitising it.

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
| [session-journal](plugins/session-journal) | Cross-session task-state journal — which threads are in flight and where each one lives, surviving context compaction, `/clear`, and resume |
| [google-reporting](plugins/google-reporting) | GA4 and Search Console readers via keyless service-account impersonation |
| [plan-cycle](plugins/plan-cycle) | The gated planning cycle: PM → designer → engineer → code → QA → close-out, with a Stop-hook ledger |
| [guardrails](plugins/guardrails) | Turns corrections into rules that fire — a bounded inbox, a fusion gate, and hooks that speak at the moment of the mistake |

## License

[MIT](LICENSE)
