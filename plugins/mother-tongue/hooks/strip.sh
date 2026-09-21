#!/usr/bin/env bash
# strip.sh — read text on stdin, print only its prose. detect.sh and scan.sh both
# go through here so that what decides the locale and what gets scanned agree.
#
# Dropped: fenced blocks (``` and ~~~), `inline` and ``double`` code spans, URLs,
# and paths (a token with a slash and no CJK). Code spans are also how a reply
# quotes a banned term on purpose; paths are Latin in every language and would
# turn a pasted `~/repo/file.md` into an English prompt.
exec perl -CSD -0777 -pe '
  s/(```|~~~).*?\1//gs;
  s/``.*?``//gs; s/`[^`\n]*`//g;
  s{\bhttps?://\S+}{}g;
  s{(?<!\S)[^\s\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}]*/[^\s\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}]*}{}g;
'
