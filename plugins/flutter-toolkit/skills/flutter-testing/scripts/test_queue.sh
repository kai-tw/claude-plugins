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
#   one taken for each run. No central authority and no message passing — a peer
#   that never answers would just be a run that proceeds anyway, which is the
#   failure this exists to prevent.
#
# WHY THE KERNEL HOLDS THE SLOT
#   A slot is an exclusive `flock` on the file `slot-<k>` in TEST_QUEUE_DIR. The
#   lock is taken on a descriptor without close-on-exec, and this process then
#   execs, by way of bash, into the test command, so the test process itself
#   holds the slot, and so does any child that inherits the descriptor. The
#   kernel drops the lock when the last of them exits, however it exits, SIGKILL
#   included — nothing here releases a slot, so nothing can leave one behind.
#   Perl takes the lock because `flock(1)` is missing on macOS and `lockf(1)` on
#   Linux.
#
#   Once locked, the slot file is rewritten with `name=`, `pid=`, `started=`
#   (epoch seconds) and `cmd=` lines, for the refusal below to show. Content in
#   a file nobody has locked is a finished run's and means nothing.
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
# EXIT
#   the command's own exit code; 75 (EX_TEMPFAIL — busy, not broken) when no slot
#   came free within the wait, so retrying later is valid; 2 for a usage error.
#   INT and TERM while waiting end it at once, holding nothing.
#
# Env:
#   TEST_QUEUE_SLOTS  slot count      (default: max(1, (RAM_GB - 8) / 4))
#   TEST_QUEUE_WAIT   seconds to wait (default: 120)
#   TEST_QUEUE_DIR    slot directory  (default: $HOME/.claude/.flutter-toolkit/queue)
#   TEST_QUEUE_NAME   holder name     (default: the working directory's name)
set -uo pipefail

if [ "${1:-}" != "--exec" ] || [ $# -lt 2 ]; then
  echo "test_queue.sh: usage: test_queue.sh --exec <cmd...>" >&2
  exit 2
fi
shift

ram_gb=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 8589934592) / 1073741824 ))
default_slots=$(( ram_gb > 12 ? (ram_gb - 8) / 4 : 1 ))
[ "$default_slots" -lt 1 ] && default_slots=1

exec perl -e '
use strict;
use warnings;
use Fcntl qw(:flock O_RDWR O_CREAT F_SETFD);
use File::Path qw(make_path);

my ($dir, $slots, $wait, $name, @cmd) = @ARGV;
my $poll = 3;

# Through the exec builtin of bash, not the execvp perl uses: execvp hands a
# script with no shebang line to /bin/sh, which is dash on Ubuntu; bash runs it
# under bash.
sub run_command {
  no warnings "exec";
  exec { "bash" } "bash", "-c", q{exec "$@"}, "plan-coverage", @cmd;
  print STDERR "test_queue.sh: cannot run bash: $!\n";
  exit 127;
}

# A queue that cannot be used is a tooling gap, not a reason to refuse: refusing
# here would let a broken helper stop every test run. So it runs unthrottled,
# and says so on stderr.
sub run_unthrottled {
  print STDERR "plan-coverage: WARNING — cannot use $_[0] ($_[1]); running WITHOUT a test slot.\n";
  run_command();
}

sub fields {
  my %f;
  open(my $in, "<", $_[0]) or return %f;
  while (<$in>) { chomp; $f{$1} = $2 if /^(\w+)=(.*)$/ }
  return %f;
}

make_path($dir, { error => \my $mkdir_errors });
-d $dir or run_unthrottled($dir, "cannot make the directory");

my $deadline = time + $wait;
my $announced = 0;
my $held;
while (1) {
  for my $k (1 .. $slots) {
    my $path = "$dir/slot-$k";
    sysopen(my $fh, $path, O_RDWR | O_CREAT) or run_unthrottled($path, "$!");
    # Only a lock someone holds means busy; any other failure, such as a
    # filesystem without flock, is a queue that cannot be used.
    unless (flock($fh, LOCK_EX | LOCK_NB)) {
      next if $!{EWOULDBLOCK};
      run_unthrottled($path, "cannot lock it: $!");
    }
    $held = [$fh, $path];
    last;
  }
  last if $held;
  if (time >= $deadline) {
    my $now = time;
    print STDERR "plan-coverage: REFUSED — none of $slots test slots free after ${wait}s.\n\nHolding now:\n";
    for my $k (1 .. $slots) {
      my %f = fields("$dir/slot-$k");
      my $for = $f{started} && $f{started} =~ /^\d+$/
        ? sprintf("%dm%02ds", ($now - $f{started}) / 60, ($now - $f{started}) % 60) : "?";
      printf STDERR "  slot-%d  %-24s pid=%-7s %s\n      %s\n",
        $k, $f{name} // "?", $f{pid} // "?", $for, $f{cmd} // "?";
    }
    print STDERR "\nThis machine cannot run more test suites at once without exhausting\n",
                 "memory. Narrow your scope, wait for a holder to finish, or ask them.\n";
    exit 75;
  }
  print STDERR "plan-coverage: all $slots test slots are held — waiting up to ${wait}s...\n" unless $announced++;
  sleep $poll;
}

my ($fh, $path) = @$held;
truncate($fh, 0);
sysseek($fh, 0, 0);
syswrite($fh, "name=$name\npid=$$\nstarted=" . time . "\ncmd=@cmd\n");
fcntl($fh, F_SETFD, 0) or run_unthrottled($path, "cannot pass the lock on: $!");
(my $slot = $path) =~ s{.*/}{};
print STDERR "plan-coverage: test slot $slot · @cmd\n";
run_command();
' "${TEST_QUEUE_DIR:-$HOME/.claude/.flutter-toolkit/queue}" "${TEST_QUEUE_SLOTS:-$default_slots}" \
  "${TEST_QUEUE_WAIT:-120}" "${TEST_QUEUE_NAME:-$(basename "$PWD")}" "$@"
