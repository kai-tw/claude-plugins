#!/usr/bin/env bash
# scan.sh <locale> — read prose on stdin, print its banned terms as one line
# "wrong→right、…", or nothing. A locale without banned.tsv never matches.
#
# A term inside one of its own exceptions (third column, 、-separated) does not
# count: substring matching alone flags 在線 in 在線上 and 界面 in 世界面臨.
# Longer terms are matched first and consume their text, so 字符串 is not also
# reported as 字符. A term written /…/ is a Perl regex, matched after every
# literal term and reported as the text it matched.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
list="$here/../locales/${1:-}/banned.tsv"
[ -n "${1:-}" ] && [ -r "$list" ] || exit 0
"$here/strip.sh" | perl -CSD -Mutf8 -e '
  open my $fh, "<:encoding(UTF-8)", $ARGV[0] or exit;
  my @rows;
  while (my $l = <$fh>) {
    $l =~ s/\r?\n$//; next unless length $l;
    my ($w, $r, $x) = split /\t/, $l;
    push @rows, [scalar @rows, $w, $r, [grep length, split /、/, $x // ""]];
  }
  my $t = do { local $/; <STDIN> } // "";
  my @hits;
  my $key = sub { $_[0] =~ m{^/.+/$} ? 0 : length $_[0] };
  for my $row (sort { $key->($b->[1]) <=> $key->($a->[1]) } @rows) {
    my ($i, $w, $r, $ex) = @$row;
    my $re = $w =~ m{^/(.+)/$} ? qr/$1/ : qr/\Q$w\E/;
    my @spans;
    for my $e (@$ex) { while ($t =~ /\Q$e\E/g) { push @spans, [$-[0], $+[0]] } }
    my @found;
    while ($t =~ /$re/g) {
      my ($s, $e) = ($-[0], $+[0]);
      push @found, [$s, $e] unless grep { $_->[0] <= $s && $_->[1] >= $e } @spans;
    }
    next unless @found;
    my %seen;
    my $label = $key->($w) ? $w : join "、", grep { !$seen{$_}++ } map { substr $t, $_->[0], $_->[1] - $_->[0] } @found;
    push @hits, [$i, "$label→$r"];
    substr($t, $_->[0], $_->[1] - $_->[0]) = "\x{FFFD}" x ($_->[1] - $_->[0]) for @found;
  }
  print join "、", map { $_->[1] } sort { $a->[0] <=> $b->[0] } @hits;
' "$list"
