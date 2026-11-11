#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh measures style-pack's rule files and prints one line per breach: a file over its
# byte bound, a rule bullet whose Check is still a question, a language heading that is more
# than `## S<N>` or sits under another rule's heading, a sub-check id that went missing, any
# trace of S10.4, a deleted id that is a rule bullet again, and what S2.10 or CONVENTIONS.md lacks.
set -euo pipefail
cat > check.sh <<'SH'
root=$1; r="$root/skills/style-pack/rules"
cd "$r" || exit 1
for x in index=38000 dart=7000 csharp=5400 js=2500; do
  b=$(wc -c < "${x%=*}.md" | tr -d ' '); [ "$b" -lt "${x#*=}" ] || echo "over=${x%=*} $b"
done
# One line per rule bullet, whitespace squeezed.
bullets() {
  awk '/^- \*\*S[0-9]/ { if (b != "") print b; b = $0; next }
       /^(## |$|\*\*|- )/ { if (b != "") print b; b = ""; next }
       b != "" { b = b " " $0 }
       END { if (b != "") print b }' "$@" | tr -s ' '
}
id() { grep -oE '^- \*\*S[0-9]+\.[0-9]+(-[a-z]+)?' | sed 's/^- \*\*//'; }
bullets index.md dart.md csharp.md js.md > "$OLDPWD/bullets.txt"
b="$OLDPWD/bullets.txt"
sed 's/`[^`]*`//g' "$b" | grep '?' | id | sed 's/^/question=/'
grep -E 'If (so|not|the latter|the former|you cannot say|no one)\b|One: it violates' "$b" | id | sed 's/^/anaphora=/'
grep -hE '^## ' dart.md csharp.md js.md | grep -vE '^## S[0-9]+$' | sed 's/^/heading=/'
awk '/^## S[0-9]/ { n = $2; sub(/ .*/, "", n) }
     /^- \*\*S[0-9]/ { s = $2; sub(/^\*\*/, "", s); i = s; sub(/\..*/, "", i); if (i != n) print "misfiled=" FILENAME " " s }' dart.md csharp.md js.md
grep -c '`## S<N>`' CONVENTIONS.md | sed 's/^/conventions-heading=/'
tr -s ' \n' ' ' < CONVENTIONS.md | grep -c 'otherwise be reasonably broken' | sed 's/^/conventions-reason=/'
grep -n 'S10\.4' *.md | sed 's/^/s10.4=/'
for i in \
  S1.1 S1.4 S1.6 S2.1 S2.2 S2.3 S2.4 S2.5 S2.6 S2.7 S2.8 S2.9 S2.10 \
  S3.1 S3.2 S3.3 S3.4 S3.5 S4.1 S4.2 S4.3 S4.4 S4.5 S5.2 S5.3 S5.4 \
  S6.1 S6.2 S6.3 S6.4 S6.5 S6.6 S7.1 S7.2 S7.3 S7.5 S7.6 \
  S8.1 S8.2 S8.3 S8.5 S8.6 S9.1 S9.2 S9.3 S9.4 S9.6 \
  S10.1 S10.2 S10.3 S10.5 S11.1 S11.2 S11.4 \
  S12.6 S13.1 S13.2 S14.1 S14.2 S15.1 S15.2 S15.3 \
  S16.1 S16.2 S16.3 S16.4 S16.6 \
  S2.1-dart S2.2-dart S3.1-dart S4.1-dart S5.1-dart S6.1-dart S7.1-dart S9.1-dart \
  S10.1-dart S11.1-dart S16.1-dart \
  S3.1-csharp S4.1-csharp S4.2-csharp S6.1-csharp S7.1-csharp S8.1-csharp S9.1-csharp \
  S10.1-csharp S15.1-csharp \
  S3.1-js S3.2-js S4.1-js S5.1-js S7.1-js; do
  id < "$b" | grep -qxF "$i" || echo "missing=$i"
done
# Ids a later round deleted must not come back as a rule bullet.
for i in S1.3 S5.1 S6.7 S7.4 S8.4 S9.5 S10.6 S11.3 S12.1 S12.2 S12.3 S12.5 S16.5 \
  S11.2-dart S16.1-csharp; do
  ! id < "$b" | grep -qxF "$i" || echo "deleted-present=$i"
done
s=$(grep -E '^- \*\*S2\.10 ' "$b")
echo "s2.10=$s"
for p in 'more than one site' 'configuration value' 'top of its file' 'finite set' 'inline' \
  'declared in one file and used in another' 'multi-line data tables' \
  'enumerations another unit reads' 'S4.2' 'may stay named with one use site'; do
  grep -qiF "$p" <<<"$s" || echo "s2.10-lacks=$p"
done
! grep -qF 'Named even with one use site' <<<"$s" || echo "s2.10-stale=Named even with one use site"
s=$(grep -E '^- \*\*S4\.4 ' "$b")
p='a version mismatch that falls back to a default instead of being converted version by version violates it too, always proposed CRITICAL'
grep -qF "$p" <<<"$s" || echo "s4.4-lacks=$p"
s=$(grep -E '^- \*\*S16\.2 ' "$b")
grep -qF 'in full or simplified' <<<"$s" || echo "s16.2-lacks=in full or simplified"
SH
