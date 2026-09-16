#!/usr/bin/env bash
# plan-test — a machine-wide concurrency budget for test runs.
#
# WHY THIS EXISTS
#   Several Claude sessions work on this machine at once, in different repos,
#   and none of them can see what the others are running. Each `flutter test`
#   costs roughly a gigabyte of baseline plus its test isolates; three at once
#   on a 16 GB machine exhausts memory, and macOS answers that with a watchdog
#   reboot. Worse, the swapfile volume shares an APFS container with the
#   worktrees, so a disk full of build/ output caps how far swap can grow —
#   the disk problem and the memory problem are one problem.
#
#   This is the semaphore that stops over-subscription: a fixed number of
#   slots, taken before a run and released after. No central authority and no
#   message passing — a peer that never answers would just be a run that
#   proceeds anyway, which is the failure this exists to prevent.
#
# WHY THE SLOT COUNT AND NOT `-j`
#   Capping concurrent INVOCATIONS is arithmetic: N runs cost N times one run.
#   Capping each run's `--concurrency` is a different claim, and `qa/SKILL.md`
#   §Running the suite currently records the opposite for NovelGlide ("no
#   memory benefit on this repo"). So this does NOT touch `-j` by default.
#   `PLAN_TEST_J` is there for whoever measures it; until someone does, the
#   flag would be a number nobody can defend.
#
# WHY IT REFUSES INSTEAD OF WAITING FOREVER
#   The Bash tool caps a call at 600s. Waiting out a five-minute suite and then
#   running a five-minute suite exceeds that, and the caller learns nothing from
#   a timeout. So the wait is bounded and the refusal names who is holding what,
#   for how long — a caller that knows the holder can narrow its scope or go do
#   something else. Silence would be the same failure in a quieter costume.
#
# Usage:
#   plan-test test/features/foo/      # scoped run (flutter or dart, auto-detected)
#   plan-test --full                  # the whole suite, deliberately
#   plan-test --exec <cmd...>         # hold a slot around an arbitrary command
#   plan-test --status                # who is holding what
#   plan-test --help
#
# WHY `--exec` EXISTS
#   A budget with holes is not a budget. `plan-mutation` and `plan-test-first`
#   each run a suite — mutation runs MANY — without ever typing `flutter test`
#   at the top level, so the hook cannot see them and they would spend memory
#   off the books. Their launchers route through here instead. `--exec` takes
#   ONE slot for the whole operation, not one per inner run: mutation's inner
#   loop must not thrash the semaphore, and it is a single long-running job as
#   far as the machine is concerned.
#
# Env:
#   PLAN_TEST_SLOTS    slot count      (default: max(1, (RAM_GB - 8) / 4))
#   PLAN_TEST_WAIT     seconds to wait (default: 120)
#   PLAN_TEST_J        pin --concurrency (default: unset — leave the tool's own)
#   PLAN_TEST_DIR      slot directory  (default: $HOME/.claude/.plan-cycle/slots)
set -uo pipefail

SLOT_DIR="${PLAN_TEST_DIR:-$HOME/.claude/.plan-cycle/slots}"
WAIT_S="${PLAN_TEST_WAIT:-120}"
POLL_S=3

ram_gb=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 8589934592) / 1073741824 ))
default_slots=$(( ram_gb > 12 ? (ram_gb - 8) / 4 : 1 ))
[ "$default_slots" -lt 1 ] && default_slots=1
SLOTS="${PLAN_TEST_SLOTS:-$default_slots}"

HELD=""

now()  { date +%s; }
mine() { printf '%s' "${PLAN_TEST_NAME:-$(basename "$PWD")}"; }

slot_field() { sed -n "s/^$2=//p" "$1/meta" 2>/dev/null | head -1; }

# Report every live holder: repo, pid, how long, and what it is running. The
# session id is included because it is the only cross-session handle available
# from a shell — it is NOT the short ref ListAgents prints (verified: they are
# different ids), so do not present it as one.
holders() {
  local slot pid started elapsed found=0
  for slot in "$SLOT_DIR"/slot-*; do
    [ -d "$slot" ] || continue
    pid=$(slot_field "$slot" pid)
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null || continue
    started=$(slot_field "$slot" started)
    elapsed=$(( $(now) - ${started:-$(now)} ))
    printf '  %-24s pid=%-7s %3dm%02ds  session=%s\n      %s\n' \
      "$(slot_field "$slot" name)" "$pid" $((elapsed/60)) $((elapsed%60)) \
      "$(slot_field "$slot" session)" "$(slot_field "$slot" cmd)"
    found=1
  done
  [ $found -eq 0 ] && echo "  (none)"
  return 0
}

# Reclaim slots whose holder died. The corpse is claimed with an atomic rename
# so two reapers cannot both free the same slot and hand it to two callers.
# A slot with no meta yet is a holder mid-write, not a corpse — it only counts
# as stale once it is over a minute old.
reap_stale() {
  local slot pid
  for slot in "$SLOT_DIR"/slot-*; do
    [ -d "$slot" ] || continue
    pid=$(slot_field "$slot" pid)
    if [ -z "$pid" ]; then
      [ -n "$(find "$slot" -maxdepth 0 -mmin +1 2>/dev/null)" ] || continue
    elif kill -0 "$pid" 2>/dev/null; then
      continue
    fi
    mv "$slot" "$slot.dead.$$" 2>/dev/null && rm -rf "$slot.dead.$$"
  done
}

acquire() {
  local i slot
  for i in $(seq 1 "$SLOTS"); do
    slot="$SLOT_DIR/slot-$i"
    if mkdir "$slot" 2>/dev/null; then
      printf 'pid=%s\nname=%s\nsession=%s\nstarted=%s\ncmd=%s\n' \
        "$$" "$(mine)" "${CLAUDE_CODE_SESSION_ID:-unknown}" "$(now)" "$*" \
        > "$slot/meta" 2>/dev/null
      HELD="$slot"
      return 0
    fi
  done
  return 1
}

# Only ever release a slot this process still owns — a slot reaped out from
# under us belongs to whoever holds it now.
release() {
  [ -n "$HELD" ] || return 0
  [ "$(slot_field "$HELD" pid)" = "$$" ] && rm -rf "$HELD"
  HELD=""
}
trap release EXIT INT TERM

# --------------------------------------------------------------------- args

case "${1:-}" in
  --help|-h) sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --status)
    echo "plan-test · $SLOTS slots · $SLOT_DIR"
    mkdir -p "$SLOT_DIR" 2>/dev/null
    reap_stale
    holders
    exit 0 ;;
  "")
    echo "plan-test: no scope given." >&2
    echo "  plan-test <path>   run that scope     plan-test --full   the whole suite" >&2
    exit 2 ;;
esac

# ------------------------------------------------------------------ command

if [ "${1:-}" = "--exec" ]; then
  shift
  [ $# -gt 0 ] || { echo "plan-test: --exec needs a command." >&2; exit 2; }
  CMD=("$@")
else
  [ "${1:-}" = "--full" ] && shift
  if [ ! -f "$PWD/pubspec.yaml" ]; then
    echo "plan-test: no pubspec.yaml here — run from a Dart or Flutter project root." >&2
    exit 2
  fi
  # `sdk: flutter` under dependencies is the discriminator: NovelGlide and
  # CherishCRM carry it, kai-packages (pure Dart, `dart test`) does not.
  if grep -qE '^[[:space:]]*sdk:[[:space:]]*flutter[[:space:]]*$' "$PWD/pubspec.yaml"; then
    RUNNER=(flutter test)
  else
    RUNNER=(dart test)
  fi
  [ -n "${PLAN_TEST_J:-}" ] && RUNNER+=("--concurrency=$PLAN_TEST_J")
  CMD=("${RUNNER[@]}" "$@")
fi

# Already inside a slot — a launcher routed through --exec and the command it
# ran reached plan-test again. Run straight through: waiting here would be a
# process blocking on a semaphore it is itself holding, and the refusal would
# name the deadlocked caller as the holder to go and ask.
if [ -n "${PLAN_TEST_SLOT_HELD:-}" ]; then
  exec "${CMD[@]}"
fi

# ------------------------------------------------------------------ acquire

# A slot store we cannot create is a tooling gap, not a budget decision. Run
# unthrottled and say so loudly on stderr — refusing here would mean a broken
# helper could stop every test run in three repos.
if ! mkdir -p "$SLOT_DIR" 2>/dev/null; then
  echo "plan-test: WARNING — cannot use $SLOT_DIR; running WITHOUT a slot." >&2
  exec "${CMD[@]}"
fi

deadline=$(( $(now) + WAIT_S ))
waited=0
while :; do
  reap_stale
  acquire "${CMD[*]}" && break
  if [ "$(now)" -ge "$deadline" ]; then
    {
      echo "plan-test: REFUSED — all $SLOTS test slots busy after ${WAIT_S}s."
      echo
      echo "Holding now:"
      holders
      echo
      echo "This machine cannot run more test suites at once without exhausting"
      echo "memory. Narrow your scope, wait for a holder to finish, or ask them."
    } >&2
    exit 75          # EX_TEMPFAIL — busy, not broken. Retrying later is valid.
  fi
  [ $waited -eq 0 ] && echo "plan-test: all $SLOTS slots busy — waiting up to ${WAIT_S}s..." >&2
  waited=1
  sleep "$POLL_S"
done

echo "plan-test: slot $(basename "$HELD") · ${CMD[*]}" >&2
# Children see that a slot is already held, so anything nested (a launcher that
# routes through --exec, a script that calls plan-test again) runs through
# instead of blocking on a semaphore this process holds.
export PLAN_TEST_SLOT_HELD="$HELD"
"${CMD[@]}"
exit $?
