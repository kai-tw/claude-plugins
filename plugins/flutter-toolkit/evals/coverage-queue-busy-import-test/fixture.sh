#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# app/ is a Flutter package whose change edits lib/count.dart and adds an enum file
# (lib/shade.dart, no executable line), so plan-coverage needs its import-only test.
# main_test.sh is the test command: it records lib/count.dart as executed, marks that
# it started and waits for check.sh to say go. fake/flutter stands in for the
# import-only `flutter test` and marks that it ran. check.sh runs plan-coverage with
# one slot; while the test command runs it starts another session's process that
# blocks on the slot's lock, so the lock passes to that process the moment the test
# command exits and it writes its name into the slot. Every wait is bounded and the
# other session's process is killed before check.sh counts leftovers.
# A slot is held while its file is locked: slot() reports whether an exclusive flock
# could be taken on it right now.
set -euo pipefail
g() { git -c user.name=e -c user.email=e@e "$@"; }
mkdir -p fake app/lib report s
cat > fake/flutter <<'F'
#!/usr/bin/env bash
echo ran >> "$(dirname "$0")/../import-ran"
out=coverage/lcov.info; prev=""
for a in "$@"; do [ "$prev" = --coverage-path ] && out=$a; prev=$a; done
mkdir -p "$(dirname "$out")"
: > "$out"
F
chmod +x fake/flutter
cat > main_test.sh <<'SH'
w=$(dirname "$0")
mkdir -p coverage
printf 'SF:lib/count.dart\nDA:1,1\nend_of_record\n' > coverage/lcov.info
touch "$w/main-started"
for _ in $(seq 1 50); do [ -e "$w/go" ] && break; sleep 0.2; done
SH
cd app
printf 'name: app\ndependencies:\n  flutter:\n    sdk: flutter\n' > pubspec.yaml
printf 'int count() => 1;\n' > lib/count.dart
git init -q -b main && g add -A && g commit -qm base && git switch -qc work
printf 'enum Shade { light, dark }\n' > lib/shade.dart
printf 'int count() => 2;\n' > lib/count.dart
g add -A && g commit -qm change
cd ..
cat > check.sh <<'SH'
w=$PWD
export TEST_QUEUE_DIR="$w/s" TEST_QUEUE_SLOTS=1 TEST_QUEUE_WAIT=1 PLAN_QA_REPORT_DIR="$w/report"
export PATH="$w/fake:$PATH"
slot() {
  if [ ! -e "$1" ]; then echo free; elif [ ! -f "$1" ]; then echo not-a-lock-file
  elif perl -MFcntl=:flock -e 'open(my $f, "<", $ARGV[0]) or exit 2; exit(flock($f, LOCK_EX | LOCK_NB) ? 0 : 1)' "$1"; then echo free
  else echo held; fi
}
(cd app && plan-coverage --diff main -- bash "$w/main_test.sh") > out.txt 2> err.txt &
pc=$!
for _ in $(seq 1 50); do [ -e main-started ] && break; sleep 0.2; done
perl -MFcntl=:flock -e 'open(my $f, ">>", $ARGV[0]) or die; open(my $m, ">", $ARGV[1]) or die; close $m;
  flock($f, LOCK_EX) or die; truncate($f, 0);
  syswrite($f, "name=other-session\npid=$$\nstarted=" . time . "\ncmd=flutter test test/\n");
  open($m, ">", $ARGV[2]) or die; close $m; sleep 30' "$w/s/slot-1" "$w/holder-waiting" "$w/holder-locked" >/dev/null 2>&1 &
holder=$!
for _ in $(seq 1 25); do [ -e holder-waiting ] && break; sleep 0.2; done
sleep 0.5
touch go
for _ in $(seq 1 100); do kill -0 "$pc" 2>/dev/null || break; sleep 0.2; done
if kill -0 "$pc" 2>/dev/null; then
  kill -KILL "$pc"; wait "$pc" 2>/dev/null
  echo "finished=no"; echo "rc=killed"
else
  wait "$pc"; rc=$?
  echo "finished=yes"; echo "rc=$rc"
fi
sed "s/^/out: /" out.txt
sed "s/^/err: /" err.txt
if [ -e holder-locked ]; then echo "holder-got-slot=yes"; else echo "holder-got-slot=no"; fi
if [ -e import-ran ]; then echo "import-test=ran"; else echo "import-test=not-run"; fi
echo "holder-still=$(slot s/slot-1)"
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
echo "left-running=$(pgrep -f "$w/" | grep -c .)"
SH
