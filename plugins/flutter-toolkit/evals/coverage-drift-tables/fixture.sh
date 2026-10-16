#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# Three files declare a `class Rows extends Table`: in rows.dart `Table` is
# drift's; shadow.dart declares its own `Table`; hidden.dart imports drift with
# `hide Table`. fake_test.sh stands in for `flutter test` and writes the lcov a
# real run produces: every line after a builder chain's first call at 0.
set -euo pipefail
git init -q
mkdir -p lib
cat > lib/rows.dart <<'D'
import 'package:drift/drift.dart';

class Rows extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()
      .withDefault(const Constant('a'))
      .map(const C())();
  String label() => 'rows';
  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
D
cat > lib/shadow.dart <<'D'
import 'package:drift/drift.dart';
class Table {}

class Rows extends Table {
  TextColumn get id => text()();
}
D
cat > lib/hidden.dart <<'D'
import 'package:drift/drift.dart' hide Table;
import 'other.dart';
class Rows extends Table {
  TextColumn get id => text()();
}
D
cat > fake_test.sh <<'D'
mkdir -p coverage
cat > coverage/lcov.info <<'L'
SF:lib/rows.dart
DA:4,1
DA:5,1
DA:6,0
DA:7,0
DA:8,0
DA:10,0
end_of_record
SF:lib/shadow.dart
DA:5,0
end_of_record
SF:lib/hidden.dart
DA:4,0
end_of_record
L
D
