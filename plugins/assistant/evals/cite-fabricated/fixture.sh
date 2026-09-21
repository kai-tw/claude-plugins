#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
mkdir -p lib
cat > lib/label_mapper.dart <<'SRC'
class LabelMapper {
  const LabelMapper();

  String titleOf(Item item) => item.name;

  /// Order of precedence: the explicit reason first, then the kind.
  String reasonOf(Item item) {
    return item.reason ?? item.kind.name;
  }
}
SRC
cat > scout.md <<'REPORT'
## Facts
| # | 斷言 | 證據 |
|---|---|---|
| F1 | `LabelMapper.titleOf` 回傳名稱 | lib/label_mapper.dart:4 |
| F2 | `LabelMapper.subtitleOf` 已用來區分同一項目下的多筆紀錄 | lib/label_mapper.dart:7-8 |
| F3 | `reasonOf` 先看 reason | lib/label_mapper.dart:56 |
| F4 | 優先序寫在 doc 裡 | lib/label_mapper.dart:6 |
REPORT
