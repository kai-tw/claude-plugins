#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
cat > plan.md <<'PLAN'
## Summary
改 batch write。
## Classes
| Class | Layer | Kind | File (NEW/MOD/DEL) | 職責 | 持有狀態 | 為何要新增 |
|---|---|---|---|---|---|---|
| `LocalStore` | data | repository | `lib/store.dart` (MOD) | 內部改 batch write | `—` | — |
## Migration impact
無持久化 / schema / API 變更 —— 只動 method body。
## Revision history
- 2026-09-16: Created.
PLAN
