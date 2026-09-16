#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
cat > body.md <<'BODY'
## Overview
LocalStore 內部改 batch write，公開介面不變。

## Key Decisions
- D1 保留簽名，只換實作。

## Deferred Items
- 無

## Final Approach
`put` 委派 `putAll`，一次 transaction。
BODY
