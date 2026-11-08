#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# Builds one project per scenario, each with its own .claude/assistant.md `rules:` line, and
# check.sh prints `<id>-<what>=1|0` for what style-pack --paths printed there.
set -euo pipefail
proj() { # proj <dir> <rules-line-or-empty>
  mkdir -p "$1/.claude/rules"; git init -q "$1"
  if [ -n "$2" ]; then printf 'vcs: git\n%s\n' "$2" > "$1/.claude/assistant.md"; else printf 'vcs: git\n' > "$1/.claude/assistant.md"; fi
  printf 'PROJ-ALWAYS\n' > "$1/.claude/rules/always.md"
  printf -- '---\npaths: lib/**\n---\nPROJ-LIB\n' > "$1/.claude/rules/lib.md"
  printf -- '---\npaths: web/**\n---\nPROJ-WEB\n' > "$1/.claude/rules/web.md"
}
proj s1 'rules: .claude/rules'
proj s3 'rules: .claude/rules/lib.md'
proj b1none 'rules: none'
proj b1absent ''
proj b2 'rules: .claude/rules'
proj b3 'rules: .claude/rules'
proj f1 'rules: .claude/no-such-rules'
cat > check.sh <<'SH'
root=$1
# on <dir> <args…>: run style-pack there; leaves out, err and rc beside it.
on() { local d=$1; shift; (cd "$d" && style-pack "$@" >../$d.out 2>../$d.err; echo $? >../$d.rc); }
# has <file> <regex> <id>: <id>=1 when the file matches.
has() { grep -Eq -- "$2" "$1" && echo "$3=1" || echo "$3=0"; }
on s1 --paths lib/a.dart
has s1.out '^## S1 — ' s1-core
has s1.out 'S[0-9]+\.[0-9]+-dart' s1-dart
has s1.out PROJ-ALWAYS s1-always
has s1.out PROJ-LIB s1-matching
has s1.out PROJ-WEB s1-other
echo "s1-rc=$(cat s1.rc)"
on s3 --paths lib/a.dart
has s3.out PROJ-LIB s3-file
has s3.out PROJ-ALWAYS s3-always
has s3.out PROJ-WEB s3-web
on b1none --paths lib/a.dart
has b1none.out '^## S1 — ' b1-none-core
has b1none.out 'S[0-9]+\.[0-9]+-dart' b1-none-dart
has b1none.out 'PROJ-' b1-none-proj
echo "b1-none-rc=$(cat b1none.rc)"
on b1absent --paths lib/a.dart
has b1absent.out '^## S1 — ' b1-absent-core
has b1absent.out 'S[0-9]+\.[0-9]+-dart' b1-absent-dart
has b1absent.out 'PROJ-' b1-absent-proj
echo "b1-absent-rc=$(cat b1absent.rc)"
on b2 --paths x.md
has b2.out '^## S1 — ' b2-core
has b2.out PROJ-ALWAYS b2-proj
has b2.out 'S[0-9]+\.[0-9]+-(dart|js|csharp)' b2-lang
echo "b2-rc=$(cat b2.rc)"
on b3 --paths test/a_test.dart
has b3.out PROJ-ALWAYS b3-always
has b3.out PROJ-LIB b3-lib
on f1 --paths lib/a.dart
[ "$(cat f1.rc)" != 0 ] && echo f1-rc=nonzero || echo f1-rc=zero
has f1.err '\.claude/no-such-rules' f1-names-path
# No plugin file still reads the old hard-coded folder.
echo "old-folder=$(grep -rl 'style-rules' "$root" --exclude-dir=evals | wc -l | tr -d ' ')"
SH
