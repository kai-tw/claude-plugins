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

## Scripts

Not plugins — standalone snippets pasted into a surface that has no plugin
mechanism at all.

| Script | Where it goes |
| --- | --- |
| [scripts/flutter-cloud-setup.sh](scripts/flutter-cloud-setup.sh) | The **Setup script** field of a [Claude Code cloud environment](https://code.claude.com/docs/en/cloud-environments#setup-scripts). Installs the pinned Flutter SDK and resolves dependencies for every Flutter repo the environment cloned — one copy serves NovelGlide, CherishCRM and any environment added later, because it discovers projects instead of naming them. Its filesystem result is snapshotted, so the ~1.5 GB SDK download is paid once per cache generation, not once per session. |

## License

[MIT](LICENSE)
