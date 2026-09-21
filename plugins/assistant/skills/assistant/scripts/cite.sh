#!/usr/bin/env bash
# asst-cite — check every `file:line` citation in a report's fact table against
# the tree it cites. Reviewers read reasoning, not sources: a citation to a
# method that never existed reads as verified and survives any number of review
# rounds, so this check is mechanical.
#
# Usage: asst-cite <tree> <report.md>
# Per table row: each cited file exists under <tree> and each line range fits in
# it, and the file holds at least one `backticked` identifier from the claim
# (`A.b` → `b`) — else FAIL. None of them within 10 lines prints `far`; a claim
# naming no identifier, or a path elided with `...`, prints `unchecked`.
# Exit: 0 = no FAIL · 1 = at least one FAIL · 2 = usage.
set -uo pipefail
tree="${1:-}"; report="${2:-}"
[ -d "$tree" ] && [ -f "$report" ] || { sed -n '7,13p' "$0" >&2; exit 2; }
perl -CSD -Mutf8 -e '
  use strict; use warnings;
  my ($tree, $report) = @ARGV; my $window = 10; my $fail = 0;
  my $ext = qr/\.(?:dart|md|swift|java|kt|m|h|js|mjs|ts|json|ya?ml|sh|arb|xml|gradle|plist|lock|txt)$/;
  open my $in, "<:encoding(UTF-8)", $report or die "asst-cite: $report: $!\n";
  while (my $row = <$in>) {
    next unless $row =~ /^\s*\|/ && $row !~ /^\s*\|[\s:|-]+\|\s*$/;
    my @cells = map { s/^\s+|\s+$//gr } split /\|/, $row; shift @cells;
    my ($id, $claim) = ($cells[0] // "?", $cells[1] // "");
    my %seen; my @names = grep { /^[A-Za-z_]\w*$/ && !$seen{$_}++ }
      map { (split /\./, s/[(\[].*$//r)[-1] // "" }
      grep { !m{/} && !/$ext/ } ($claim =~ /`([^`]+)`/g);
    my (@cites, $last);
    for my $cell (@cells[2 .. $#cells]) {
      while ($cell =~ /(?<![\w:])((?:~|[\w.~\/-])*\w\.\w+)?:(\d+)(?:-(\d+))?((?:,\d+(?:-\d+)?)*)/g) {
        my ($path, $from, $to, $more) = ($1 // $last, $2, $3 // $2, $4);
        next unless defined $path; $last = $path;
        push @cites, [$path, $from, $to];
        push @cites, [$path, $1, $2 // $1] while $more =~ /,(\d+)(?:-(\d+))?/g;
      }
    }
    next unless @cites;
    for my $c (@cites) {
      my ($path, $from, $to) = @$c;
      my $cite = "$path:$from" . ($to != $from ? "-$to" : "");
      if ($path =~ /\.\.\.|…/) { print "unchecked $id $cite — path elided\n"; next }
      my $f = $path =~ s/^~/$ENV{HOME}/r; $f = "$tree/$f" unless $f =~ m{^/};
      unless (-f $f) { print "FAIL $id $cite — no such file\n"; $fail = 1; next }
      open my $src, "<:encoding(UTF-8)", $f or do { print "FAIL $id $cite — unreadable\n"; $fail = 1; next };
      my @lines = <$src>; close $src;
      if ($to > @lines) { printf "FAIL %s %s — file has %d lines\n", $id, $cite, scalar @lines; $fail = 1; next }
      unless (@names) { print "unchecked $id $cite — claim names no `identifier`\n"; next }
      my $lo = $from - $window < 1 ? 1 : $from - $window;
      my $hi = $to + $window > @lines ? scalar @lines : $to + $window;
      my $all = join "", @lines;
      unless (grep { $all =~ /\b\Q$_\E\b/ } @names) {
        printf "FAIL %s %s — none of %s in the file\n", $id, $cite, join(", ", @names); $fail = 1; next
      }
      my $near = join "", @lines[$lo - 1 .. $hi - 1];
      print +(grep { $near =~ /\b\Q$_\E\b/ } @names) ? "ok $id $cite\n"
        : "far $id $cite — none of the claim identifiers within $window lines\n";
    }
  }
  exit $fail;
' "$tree" "$report"
