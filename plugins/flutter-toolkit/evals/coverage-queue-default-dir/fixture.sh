#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# home/ stands in for $HOME and holds what 7.x leaves on a machine: the directory
# .claude/.flutter-toolkit/slots with a slot-9 directory and its meta file, every
# entry dated 2020 so any write to it changes its mtime. fake_test.sh stands in for
# `flutter test`: it records whether slot-1 under $HOME/.claude/.flutter-toolkit/queue
# is held while it runs, then writes a fully executed lcov. check.sh points HOME at
# home/, unsets TEST_QUEUE_DIR and runs plan-coverage on lib/a.dart in the
# background, killed if it is still running after 20 s; it prints what the case
# grades, among it whether the slots directory's entries, modes, sizes, mtimes and
# meta content are the same afterwards.
# A slot is held while its file is locked: held when an exclusive flock cannot be
# taken on it right now.
set -euo pipefail
git init -q
mkdir -p lib report home/.claude/.flutter-toolkit/slots/slot-9
printf 'int a() => 1;\n' > lib/a.dart
printf 'pid=%s\nname=old-session\nsession=unknown\nstarted=1577836800\ncmd=flutter test test/\n' "$$" \
  > home/.claude/.flutter-toolkit/slots/slot-9/meta
find home/.claude/.flutter-toolkit/slots -exec touch -t 202001010000 {} +
cat > fake_test.sh <<'SH'
s="$HOME/.claude/.flutter-toolkit/queue/slot-1"
if [ ! -e "$s" ]; then held=free; elif [ ! -f "$s" ]; then held=not-a-lock-file
elif perl -MFcntl=:flock -e 'open(my $f, "<", $ARGV[0]) or exit 2; exit(flock($f, LOCK_EX | LOCK_NB) ? 0 : 1)' "$s"; then held=free
else held=held; fi
echo "queue-slot-1=$held" > "$(dirname "$0")/during.txt"
mkdir -p coverage
printf 'SF:lib/a.dart\nDA:1,1\nend_of_record\n' > coverage/lcov.info
SH
cat > check.sh <<'SH'
w=$PWD
export HOME="$w/home" TEST_QUEUE_SLOTS=1 TEST_QUEUE_WAIT=0 PLAN_QA_REPORT_DIR="$w/report"
unset TEST_QUEUE_DIR
old="$HOME/.claude/.flutter-toolkit/slots"
snap() {
  find "$old" | sort | perl -ne 'chomp; my @s = lstat $_; print "$_ $s[2] $s[7] $s[9]\n"'
  cat "$old/slot-9/meta"
}
before=$(snap)
plan-coverage --files lib/a.dart -- bash "$w/fake_test.sh" > out.txt 2>&1 &
pc=$!
for _ in $(seq 1 100); do kill -0 "$pc" 2>/dev/null || break; sleep 0.2; done
if kill -0 "$pc" 2>/dev/null; then
  kill -KILL "$pc"; wait "$pc" 2>/dev/null
  echo "rc=killed"
else
  wait "$pc"; echo "rc=$?"
fi
cat during.txt 2>/dev/null || echo "queue-slot-1=not-run"
echo "warnings=$(grep -c WARNING out.txt)"
grep -m1 WARNING out.txt
if [ "$(snap)" = "$before" ]; then echo "old-slots=unchanged"; else echo "old-slots=changed"; fi
echo "left-running=$(pgrep -f "$w/" | grep -c .)"
SH
