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
