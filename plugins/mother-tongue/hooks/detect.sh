#!/usr/bin/env bash
# detect.sh — print the locale tag of the prose on stdin, or nothing when it
# cannot tell. Every hook routes through this one judgment so that the reminder,
# the reply check and the commit check never disagree about the language.
#
# Code, URLs and paths are stripped first (strip.sh): they are Latin in every
# language and would drag CJK prose toward `en`.
#
# CJK wins when it has at least as many characters as there are Latin words —
# one Han character carries roughly one word, so "把 worktree 的 cache 清掉" is
# Chinese and "rename 設定 in the settings page" is English. Within CJK: Hangul
# majority is `ko`; kana at 20% or more of kana+Han is `ja` (Japanese prose is
# Han-heavy, so a majority test would miss it); the rest is Chinese.
#
# Script cannot tell zh-TW from zh-HK, so Chinese maps to MOTHER_TONGUE_ZH
# (default zh-TW).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tag=$("$here/strip.sh" | perl -CSD -0777 -ne '
  my $kana   = () = /[\p{Hiragana}\p{Katakana}]/g;
  my $hangul = () = /\p{Hangul}/g;
  my $han    = () = /\p{Han}/g;
  my $words  = () = /\p{Latin}+/g;
  my $cjk = $kana + $hangul + $han;
  if ($cjk >= 2 && $cjk >= $words) {
    if    ($hangul * 2 > $cjk)             { print "ko" }
    elsif ($kana * 5 >= $kana + $han)      { print "ja" }
    else                                   { print "zh" }
  } elsif ($words >= 3) { print "en" }
')
[ "$tag" = zh ] && tag="${MOTHER_TONGUE_ZH:-zh-TW}"
printf '%s' "$tag"
