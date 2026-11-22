#!/usr/bin/env bash
# test_queue.sh — a machine-wide concurrency limit for test runs. Internal:
# only coverage.sh calls it, as `test_queue.sh --exec <cmd...>`.
#
# WHY THIS EXISTS
#   Several Claude sessions work on one machine at once, in different repos, and
#   none of them can see what the others are running. Each `flutter test` costs
#   roughly a gigabyte of baseline plus its test isolates; three at once on a
#   16 GB machine exhausts memory, and macOS answers that with a watchdog reboot.
#   The swapfile volume shares an APFS container with the worktrees, so a disk
#   full of build/ output caps how far swap can grow — the disk problem and the
#   memory problem are one problem.
#
#   This is the semaphore that stops over-subscription: a fixed number of slots,
#   taken before a run and released after. No central authority and no message
#   passing — a peer that never answers would just be a run that proceeds anyway,
#   which is the failure this exists to prevent.
#
# WHY THE SLOT COUNT AND NOT `-j`
#   Capping concurrent INVOCATIONS is arithmetic: N runs cost N times one run.
#   Capping each run's `--concurrency` is a different claim, and the one repo it
#   was measured on showed no memory benefit, so the tool's own `-j` is left alone.
#
# WHY IT REFUSES INSTEAD OF WAITING FOREVER
#   The Bash tool caps a call at 600s. Waiting out a five-minute suite and then
#   running a five-minute suite exceeds that, and the caller learns nothing from
#   a timeout. So the wait is bounded and the refusal names who is holding what,
#   for how long — a caller that knows the holder can narrow its scope or go do
#   something else. Silence would be the same failure in a quieter costume.
#
# SLOT FORMAT
#   Slots are directories `slot-<n>` in TEST_QUEUE_DIR, each with a `meta` file of
#   `pid=`, `name=`, `session=`, `started=` (epoch seconds) and `cmd=` lines. The
#   directory and the format are the ones 7.x wrote, so a 7.x run and this one on
#   one machine count each other's holders. The pid is this process's, which
#   stays alive for the whole run: a reaper frees a slot whose pid is dead.
#
# EXIT
#   the command's own exit code; 75 (EX_TEMPFAIL — busy, not broken) when no slot
#   came free within the wait, so retrying later is valid; 2 for a usage error.
#
# Env:
#   TEST_QUEUE_SLOTS  slot count      (default: max(1, (RAM_GB - 8) / 4))
#   TEST_QUEUE_WAIT   seconds to wait (default: 120)
#   TEST_QUEUE_DIR    slot directory  (default: $HOME/.claude/.flutter-toolkit/slots)
#   TEST_QUEUE_NAME   holder name     (default: the working directory's name)
set -uo pipefail

SLOT_DIR="${TEST_QUEUE_DIR:-$HOME/.claude/.flutter-toolkit/slots}"
WAIT_S="${TEST_QUEUE_WAIT:-120}"
POLL_S=3

ram_gb=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 8589934592) / 1073741824 ))
default_slots=$(( ram_gb > 12 ? (ram_gb - 8) / 4 : 1 ))
[ "$default_slots" -lt 1 ] && default_slots=1
SLOTS="${TEST_QUEUE_SLOTS:-$default_slots}"

HELD=""   # the slot path this process owns

now()  { date +%s; }
mine() { printf '%s' "${TEST_QUEUE_NAME:-$(basename "$PWD")}"; }

slot_field() { sed -n "s/^$2=//p" "$1/meta" 2>/dev/null | head -1; }

# Report every live holder: name, pid, how long, and what it is running. The
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

# `mkdir` is the atomic claim: of two callers racing for one slot, one wins.
acquire() {
  local i slot
  for i in $(seq 1 "$SLOTS"); do
    slot="$SLOT_DIR/slot-$i"
    if mkdir "$slot" 2>/dev/null; then
      printf 'pid=%s\nname=%s\nsession=%s\nstarted=%s\ncmd=%s\n' \
        "$$" "$(mine)" "${CLAUDE_CODE_SESSION_ID:-unknown}" "$(now)" "$*" \
        > "$slot/meta" 2>/dev/null
      HELD=$slot
      return 0
    fi
  done
  return 1
}

# Only ever release a slot this process still owns — a slot reaped out from
# under us belongs to whoever holds it now.
release() {
  [ -n "$HELD" ] && [ "$(slot_field "$HELD" pid)" = "$$" ] && rm -rf "$HELD"
  HELD=""
}
trap release EXIT INT TERM

# ------------------------------------------------------------------ command

if [ "${1:-}" != "--exec" ] || [ $# -lt 2 ]; then
  echo "test_queue.sh: usage: test_queue.sh --exec <cmd...>" >&2
  exit 2
fi
shift

# A slot store we cannot create is a tooling gap, not a reason to refuse. Run
# unthrottled and say so loudly on stderr — refusing here would mean a broken
# helper could stop every test run.
if ! mkdir -p "$SLOT_DIR" 2>/dev/null; then
  echo "plan-coverage: WARNING — cannot use $SLOT_DIR; running WITHOUT a test slot." >&2
  exec "$@"
fi

deadline=$(( $(now) + WAIT_S ))
waited=0
while :; do
  reap_stale
  acquire "$*" && break
  if [ "$(now)" -ge "$deadline" ]; then
    {
      echo "plan-coverage: REFUSED — none of $SLOTS test slots free after ${WAIT_S}s."
      echo
      echo "Holding now:"
      holders
      echo
      echo "This machine cannot run more test suites at once without exhausting"
      echo "memory. Narrow your scope, wait for a holder to finish, or ask them."
    } >&2
    exit 75
  fi
  [ $waited -eq 0 ] && echo "plan-coverage: all $SLOTS test slots are held — waiting up to ${WAIT_S}s..." >&2
  waited=1
  sleep "$POLL_S"
done

echo "plan-coverage: test slot ${HELD##*/} · $*" >&2
# Marks the child as already inside a slot, so a nested call runs through
# instead of blocking on a semaphore this process holds.
export TEST_QUEUE_SLOT_HELD="$HELD"
"$@"
exit $?
