#!/usr/bin/env perl
# drift_columns.pl <file.dart> — print the line numbers of the drift table
# definitions in a file, one per line, for coverage.sh to leave unmeasured.
#
# A drift column getter (`TextColumn get name => text().nullable()();`) is read
# by drift's code generator and never at runtime: the generated table class
# overrides it with a `GeneratedColumn`, and calling the builder throws. So the
# first call of the chain runs, if anything does, and the rest can never be
# executed by any test.
#
# What counts, and nothing else:
#   - a class that `extends Table`, or a mixin `on Table`, where `Table` is
#     drift's: the file imports `package:drift/drift.dart` so that `Table` is
#     visible (no `hide Table`, `show` names it; with `as p`, it's `p.Table`),
#     and the file declares no `Table` of its own;
#   - inside that body, an expression-bodied getter (`=>`) whose type is a
#     drift column (`TextColumn`, `IntColumn`, `Column<T>`, …), or one of the
#     Table members the generator reads: primaryKey, uniqueKeys, tableName,
#     withoutRowId, isStrict, dontWriteConstraints, customConstraints.
# A method, a block-bodied getter, or a getter of any other type in the same
# class is still measured.
use strict;
use warnings;

my $path = shift or die "usage: drift_columns.pl <file.dart>\n";
open my $fh, '<', $path or exit 0;
my $src = do { local $/; <$fh> };
close $fh;

# Blank out comments and string contents, keeping every newline, so offsets
# still map to lines and no brace or semicolon inside them counts.
my $code = $src;
$code =~ s{
    ( /\*.*?\*/ | //[^\n]* | r?'''.*?''' | r?""".*?""" | r'[^'\n]*' | r"[^"\n]*"
    | '(?:\\.|[^'\\\n])*' | "(?:\\.|[^"\\\n])*" )
}{ (my $m = $1) =~ s/[^\n]/ /g; $m }gsex;

my @supers;
while ($src =~ /^\s*import\s+['"]package:drift\/drift\.dart['"]([^;]*);/mg) {
  my $clause = $1;
  next if $clause =~ /\bhide\b[^;]*\bTable\b/;
  next if $clause =~ /\bshow\b/ && $clause !~ /\bshow\b[^;]*\bTable\b/;
  if ($clause =~ /\bas\s+(\w+)/) { push @supers, "$1\\.Table" }
  else { push @supers, 'Table' }
}
@supers = grep { $_ ne 'Table' } @supers
  if $code =~ /\b(?:class|mixin|enum|typedef|extension\s+type)\s+Table\b/;
exit 0 unless @supers;
my $super = join '|', @supers;

my $line_of = sub { (substr($code, 0, $_[0]) =~ tr/\n//) + 1 };
my $api = qr/primaryKey|uniqueKeys|tableName|withoutRowId|isStrict|dontWriteConstraints|customConstraints/;
my $column = qr/(?:\w+\.)?\w*Column(?:<[^=]*?>)?\??/;
my %out;

while ($code =~ /\b(?:class\s+\w+(?:<[^{]*?>)?\s+extends\s+(?:$super)|mixin\s+\w+\s+on\s+(?:$super))\b[^{;]*\{/g) {
  my $pos = pos($code);
  my ($depth, $start, $arrow) = (0, $pos, 0);
  for (my $i = $pos; $i < length $code; $i++) {
    my $c = substr($code, $i, 1);
    if ($c =~ /[{(\[]/) { $depth++; next }
    if ($c =~ /[})\]]/) {
      if ($depth == 0) { last }                       # the body's closing brace
      $depth--;
      next if $depth > 0 || $c ne '}' || $arrow;
    } elsif ($depth == 0 && substr($code, $i, 2) eq '=>') {
      $arrow = 1;
      next;
    } elsif (!($c eq ';' && $depth == 0)) {
      next;
    }
    # A member ended at $i: a `;` at depth 0, or a block body closing.
    $arrow = 0;
    my $member = substr($code, $start, $i + 1 - $start);
    if ($member =~ /^(\s*(?:\@\w+(?:\([^)]*\))?\s*)*)((?:$column)\s+get\s+\w+|\S+(?:<[^=]*?>)?\??\s+get\s+(?:$api))\s*=>/s) {
      my $from = $line_of->($start + length $1);
      $out{$_} = 1 for $from .. $line_of->($i);
    }
    $start = $i + 1;
  }
  pos($code) = $pos;
}
print "$_\n" for sort { $a <=> $b } keys %out;
