#!/usr/bin/env perl
# const_ctors.pl <file.dart> — print the line numbers of the const constructor
# declarations in a file that hold no logic, one per line, for coverage.sh to
# leave unmeasured.
#
# A const constructor has no body, and whether the VM records its declaration
# line depends on what else is loaded: measured, `const UseCase();` passed in a
# run where every use was const, and was reported unexecuted in a run that
# loaded a DI registration `() => const UseCase()` it never called. The same
# line passed in one test scope and failed in another, so the gate graded the
# scope, not the tests.
#
# What counts, and nothing else: `const Name(…)` or `const Name.named(…)` that
# starts a class member (after `;`, `{`, `}` or an annotation), declared in a
# class this file names, ending in `;` right after the parameters, or after an
# initializer list (`: field = …, super(…)`) with no `?`, `&&`, `||` or
# `assert` in it; and `const factory Name(…) = Other;`. An initializer list
# that branches or asserts is logic, and stays measured.
use strict;
use warnings;

my $path = shift or die "usage: const_ctors.pl <file.dart>\n";
open my $fh, '<', $path or exit 0;
my $src = do { local $/; <$fh> };
close $fh;

# Blank out comments and string contents, keeping every newline, so offsets
# still map to lines and no paren, colon or semicolon inside them counts.
my $code = $src;
$code =~ s{
    ( /\*.*?\*/ | //[^\n]* | r?'''.*?''' | r?""".*?""" | r'[^'\n]*' | r"[^"\n]*"
    | '(?:\\.|[^'\\\n])*' | "(?:\\.|[^"\\\n])*" )
}{ (my $m = $1) =~ s/[^\n]/ /g; $m }gsex;

my %classes = map { $_ => 1 } ($code =~ /\b(?:class|enum)\s+(\w+)/g);
exit 0 unless %classes;
my $line_of = sub { (substr($code, 0, $_[0]) =~ tr/\n//) + 1 };
my %out;

while ($code =~ /(?:^|[;{}]|\@\w+(?:\.\w+)*(?:\([^()]*\))?)\s*\bconst\s+(factory\s+)?(\w+)(?:\.\w+)?\s*\(/gs) {
  my ($factory, $name) = ($1, $2);
  my $open = pos($code) - 1;
  next unless $classes{$name};
  my $start = rindex(substr($code, 0, $open), 'const');
  # The parameter list, to its matching paren.
  my ($depth, $i) = (0, $open);
  for (; $i < length $code; $i++) {
    my $c = substr($code, $i, 1);
    $depth++ if $c eq '(';
    if ($c eq ')') { $depth--; last if $depth == 0 }
  }
  my $rest = substr($code, $i + 1);
  my $end;
  if ($factory) {
    $rest =~ /^\s*=\s*[\w.<>, ?]+\s*;/ or next;
    $end = $i + 1 + $+[0];
  } elsif ($rest =~ /^\s*;/) {
    $end = $i + 1 + $+[0];
  } elsif ($rest =~ /^\s*:\s*(?:super\b|this\b|_?\w+\s*=)/) {
    my $semi = index($rest, ';');
    next if $semi < 0;
    my $init = substr($rest, 0, $semi);
    next if $init =~ /\?|&&|\|\||\bassert\b|[{}]/;
    $end = $i + 1 + $semi + 1;
  } else {
    next;
  }
  $out{$_} = 1 for $line_of->($start) .. $line_of->($end - 1);
}

print "$_\n" for sort { $a <=> $b } keys %out;
