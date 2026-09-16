#!/usr/bin/env bash
# Scaffold for the eval workspace (empty dir → this repo shape). Runs only under --scaffold / evals/run.sh.
set -euo pipefail
git init -q && mkdir -p lib
cat > lib/store.dart <<'DART'
class LocalStore {
  Future<void> put(String id, Object value) async {}
  Future<void> putAll(Map<String, Object> entries) async {}
}
DART
cat > plan.md <<'PLAN'
## Summary
`LocalStore` 內部改 batch write，公開介面不變。
選了保留簽名、只換實作。

## Facts
| # | 斷言 | 證據 | 依賴它的設計決策 |
|---|---|---|---|
| F1 | `LocalStore.put` 逐筆寫入 | `lib/store.dart:2` | §Classes：只改 body |

## Classes
| Class | Layer | Kind | File (NEW/MOD/DEL) | 職責 | 持有狀態 | 為何要新增 |
|---|---|---|---|---|---|---|
| `LocalStore` | data | repository | `lib/store.dart` (MOD) | `put` 改為委派 `putAll`，公開介面不變 | `—` | — |

### `LocalStore`
SOP: —

| method | 簽名 | 職責 | 呼叫 | 既有方法夠嗎 | Error → 處置 |
|---|---|---|---|---|---|
| `put` | `Future<void> put(String id, Object value)` | 委派 `putAll` | `LocalStore.putAll` | `lib/store.dart:3` 簽名相符 | `—` |

## Data flow
```mermaid
flowchart LR
  U(["呼叫端 put"]) --> A["LocalStore.put"]
```

## Error policy
Policy: 寫入失敗上拋，不重試。

無 ≥2 來源的共享狀態。

## Startup
無新增啟動期工作 —— 只改 method body。

## Migration impact
無持久化 / schema / API 變更 —— 只改 method body。

## Risks
| Risk | Mitigation |
|---|---|
| batch 半途失敗留下部分寫入 | 單元測試覆蓋失敗路徑 |

## Conformance
| # | Requirement | Source | 實作於 | 驗證 |
|---|---|---|---|---|
| 1 | 公開介面不變 | product plan §提議方法 | `LocalStore.put` | 既有測試 |

## Revision history
- 2026-09-16: Created.
PLAN
git add -A
