# dart-lsp

Dart and Flutter language server for Claude Code, providing code intelligence
features like go-to-definition, find references, hover types, rename, and error
checking.

## Supported Extensions

`.dart`

## Installation

The language server ships with the Dart SDK — if `dart` is on your `PATH`, there
is nothing to install. The Flutter SDK bundles it too, at
`<flutter>/bin/dart`.

Verify:

```bash
dart language-server --help
```

## Why this exists

Claude Code's official marketplace ships language servers for C/C++, C#, Go,
Java, Kotlin, Lua, PHP, Python, Ruby, Rust, Swift and TypeScript — but not Dart.
Without one, Claude falls back to text search on a Flutter codebase, which
misses aliased imports and re-exports and cannot tell two same-named symbols
apart.

## Troubleshooting

Two messages mean the server is not running:

```
failed to start LSP server "dart"
No LSP server available for file type .dart for operation goToDefinition on file ...
```

Almost always the cause is one of:

- **The SDK is not on PATH.** Flutter works in your terminal, but Claude Code
  was launched from an environment that never sourced your shell profile. Add
  the SDK's `bin` directory to your PATH and fully restart Claude Code.
- **No Dart SDK installed.** Install [Flutter](https://docs.flutter.dev/get-started/install)
  (bundles Dart) or the [Dart SDK](https://dart.dev/get-dart) alone.
- **Another plugin already claims `.dart`.** Claude Code keeps one server per
  extension and reports `already registered a server for that extension` for
  the loser. Disable whichever is redundant.
- **Installed mid-session.** LSP servers spawn at session start; restart Claude
  Code.

If PATH cannot be fixed, point the plugin at the binary directly: set
`lspServers.dart.command` in the installed manifest to the absolute path from
`which dart` (`where dart` on Windows). This is overwritten by plugin updates,
so prefer the PATH fix.

This plugin also ships a **`dart-lsp-setup` skill**, so Claude can walk you
through the above itself when it hits the error — you can just ask it why Dart
navigation is not working.

## Notes

- The server is the Dart Analysis Server run in LSP mode (`--protocol=lsp`),
  the same one that backs the official VS Code and IntelliJ Dart plugins.
- It runs out-of-process, so it adds no token cost to a session.
- `startupTimeout` is set to 120s: the analysis server indexes the whole package
  graph on a large Flutter project, and the default timeout can be tight on a
  cold start.

## More Information

- [Dart Analysis Server](https://github.com/dart-lang/sdk/tree/main/pkg/analysis_server)
- [dart.dev](https://dart.dev/)
