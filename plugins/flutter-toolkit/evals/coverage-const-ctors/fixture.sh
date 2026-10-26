#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# lib/cc.dart holds const constructors with no logic (lines 1, 4, 8-12, 15, 21),
# one whose initializer branches (13), one that asserts (14), and uses of them
# (25-27). fake_test.sh stands in for `flutter test` and writes an lcov where
# every constructor line and the uses are at 0, as a run that loads a non-const
# call it never makes records them.
set -euo pipefail
git init -q
mkdir -p lib
cat > lib/cc.dart <<'D'
abstract class FooException { const FooException(this.message); final String message; }

class NotFound extends FooException {
  const NotFound() : super('not found: a ; b');
}

class Card {
  const Card.loading({
    required this.title,
    String? caption,
  })  : isLoading = true,
        caption = caption;
  const Card.toned(bool dark) : tone = dark ? 1 : 0;
  const Card.checked(this.n) : assert(n > 0);
  const factory Card.alias(String t) = Card.loading;
  final String title;
}

class UseCase {
  @Deprecated('x')
  const UseCase();
  int call() => 1;
}

final a = [const UseCase(), const NotFound()];
UseCase make() => const UseCase();
const map = {const UseCase(): 1};
D
cat > fake_test.sh <<'D'
mkdir -p coverage
{ echo SF:lib/cc.dart; for n in 1 4 8 11 13 14 21 25 26 27; do echo "DA:$n,0"; done; echo DA:22,1; echo end_of_record; } > coverage/lcov.info
D
