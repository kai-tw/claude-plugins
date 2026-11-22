# stoppable.sh — sourced by test_queue.sh and coverage.sh, never run.
#
# `run_stoppable <cmd...>` runs a command so that INT or TERM sent to this shell
# stops it, and returns its exit code once it has exited on its own. On a signal
# the command is sent TERM and waited for, and only then does this shell exit,
# 130 for INT and 143 for TERM — a test run holds its memory until its process
# is gone, so its test slot must stay held until then.
#
# Bash holds a trapped signal until a foreground command finishes, so the command
# runs in the background and the shell waits on it. Without job control, bash
# starts a background command with INT ignored, and a script cannot un-ignore it;
# that is why the stop is always passed on as TERM. `<&0` keeps the caller's
# stdin, which a background command would otherwise lose to /dev/null.
run_stoppable() {
  local rc
  trap 'stop_stoppable 130' INT
  trap 'stop_stoppable 143' TERM
  "$@" <&0 &
  wait "$!"
  rc=$?
  trap - INT TERM
  return "$rc"
}

stop_stoppable() {
  [ -n "$!" ] && kill -TERM "$!" 2>/dev/null && wait "$!"
  exit "$1"
}
