---
name: dart-lsp-setup
description: Fix a Dart language server that is not running or not yet ready — when an LSP operation returns "No LSP server available for file type .dart", Claude Code reports 'failed to start LSP server "dart"', Dart navigation stops working, or a workspace symbol search comes back empty for a symbol that certainly exists.
---

# Dart language server: not ready vs not running

**Read this first if a query returned nothing.** An empty result early in a
session usually means the index is still building, not that the symbol is
unused — see "Warm-up" below. Only work the repair ladder if the server is
genuinely absent.

## Warm-up: the first query is slow, and one operation lies

The Dart analysis server indexes the whole package graph before it can answer
project-wide questions. On a large Flutter app (~1,500 files) that measured
**~40-65 seconds** on the first query of a session. After that, the same query
returns in ~0.0s.

Two behaviours, measured, that differ in how safe they are:

- **`findReferences` blocks until the index is ready.** It waited 39s and then
  returned the correct 399 references. Slow, never wrong — just let it finish.
- **`workspaceSymbol` answers early with an empty list.** It returned 0 matches
  for a class that has 62, purely because indexing had not finished.

So: **an empty `workspaceSymbol` result is not evidence that a symbol does not
exist.** Never conclude a symbol is unused, or delete anything, based on an
empty workspace-symbol result early in a session. Re-run it once something
else has warmed the server, or confirm with `findReferences` (which blocks) or
a plain text search before acting.

The other operations were not measured; treat a suspiciously empty result from
any of them the same way.

# Repairing a server that is not running

This plugin declares one LSP server: `dart language-server --protocol=lsp`,
which ships inside the Dart SDK (and inside the Flutter SDK at
`<flutter>/bin/dart`). The plugin runs it as `dart`, so **the SDK must be on
the PATH of the process that launched Claude Code**.

Work the ladder below in order and stop at the first step that fails — each
step's failure tells you which fix applies. Run the commands yourself rather
than asking the user to; you know which platform you are on.

## 1. Is the SDK reachable at all?

```
dart --version
```

Works → skip to step 4. Fails with "command not found" → step 2.

## 2. Find the SDK

Locate it, adapting to the platform:

- macOS / Linux: `which dart`, then look for a Flutter checkout —
  `ls ~/development/flutter/bin/dart ~/flutter/bin/dart`, `brew --prefix dart`
- Windows: `where dart`, then check the usual Flutter locations —
  `%LOCALAPPDATA%\flutter\bin\dart.exe`, `C:\flutter\bin\dart.exe`, `C:\src\flutter\bin\dart.exe`

Found a `dart` binary → step 3. Found nothing → step 5.

## 3. Installed, but not on PATH

This is the most common cause: Flutter is installed and works in the user's
terminal, but Claude Code was launched from an environment that never sourced
their shell profile.

Two fixes — offer both, and say which you recommend:

- **Preferred:** add the SDK's `bin` directory to the PATH in the shell profile
  (`~/.zshrc`, `~/.bashrc`, or the Windows user Path), then fully restart
  Claude Code. This fixes every tool, not just this plugin.
- **Escape hatch:** point the plugin at the binary directly. Edit the installed
  manifest's `lspServers.dart.command` to the absolute path you found in
  step 2, then restart. Locate the manifest under the plugin's install path
  (`claude plugin list` shows it). Note this edit is overwritten by a plugin
  update — the PATH fix is durable, this one is not.

## 4. SDK works but the server still does not

Check these in order:

1. `dart language-server --help` — confirms the subcommand exists. Very old
   Dart SDKs predate it; the fix is to upgrade the SDK.
2. `claude plugin list` — is `dart-lsp` present and **enabled**? An installed
   but disabled plugin registers nothing.
3. Look for a **duplicate registration**. If another installed plugin also
   claims `.dart`, Claude Code keeps one and reports
   `already registered a server for that extension` for the other. Disable or
   uninstall whichever one is redundant — two plugins cannot share an
   extension.
4. Restart Claude Code. LSP servers are spawned at session start, so a plugin
   installed or enabled mid-session does not run until the next one.

## 5. No SDK installed

Direct the user to install it, and let them pick:

- Flutter SDK (https://docs.flutter.dev/get-started/install) — the right choice
  if they build Flutter apps; it bundles Dart.
- Dart SDK alone (https://dart.dev/get-dart) — for pure Dart projects.

Do not run the installer for them; these are large, platform-specific
installs that touch their PATH. After they install, restart Claude Code and
re-run step 1 to confirm.

## Confirming the fix

After a restart, run any LSP operation against a `.dart` file — a
`goToDefinition` on a known symbol is enough. Success means a real location
comes back instead of `No LSP server available for file type .dart`.
