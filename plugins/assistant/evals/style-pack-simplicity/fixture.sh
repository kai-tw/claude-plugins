#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh prints one line per leftover: exemption or burden-of-proof wording in index.md or
# CONVENTIONS.md, an always-CRITICAL clause in S2, a deleted rule id named anywhere under
# skills/ or agents/, "named option" in builder.md or verifier.md, and the first section of
# index.md (for the graders and a regex on S16.1).
set -euo pipefail
cat > check.sh <<'SH'
root=$1; cd "$root" || exit 1
r=skills/style-pack/rules
grep -niE 'exemption' $r/index.md | sed 's/^/exemption-index=/'
grep -niE 'no exemption clauses?' $r/CONVENTIONS.md | sed 's/^/exemption-conventions=/'
grep -niE 'apply the higher rule' $r/index.md | sed 's/^/higher-rule=/'
# S2's section: from its heading to the next one.
awk '/^## S2 /{f=1; next} /^## /{f=0} f' $r/index.md | grep -n 'always proposed CRITICAL' | sed 's/^/s2-critical=/'
# S4.1 and S8.6 keep their "always proposed CRITICAL": each rule's block, to the next bullet.
block() { awk -v id="$1" 'index($0, "- **" id " ")==1 {f=1; print; next} /^- \*\*|^## /{f=0} f' $r/index.md | tr -s ' \n' ' '; }
grep -qF 'always proposed CRITICAL' <<<"$(block S4.1)" || echo "s4.1-missing=S4.1 lost always proposed CRITICAL"
grep -qF 'always proposed CRITICAL' <<<"$(block S8.6)" || echo "s8.6-missing=S8.6 lost always proposed CRITICAL"
# The first section: everything before "## Core rules".
first=$(awk '/^## Core rules/{exit} {print}' $r/index.md | tr -s ' \n' ' ')
echo "first-section=$first"
grep -qiE 'more specific' <<<"$first" || echo "specific-lacks=more specific"
grep -qF 'S16.1' <<<"$first" || echo "s16.1-lacks=S16.1 not in the first section"
# A deleted id named as a rule or a citation; -dart/-js/-csharp ids are distinct ids.
for i in S1.3 S5.1 S6.7 S7.4 S8.4 S9.5 S10.6 S11.3 S12.1 S12.2 S12.3 S12.5 S16.5 \
  S11.2-dart S16.1-csharp; do
  re=$(sed 's/\./\\./g' <<<"$i")
  grep -rnE "(^|[^A-Za-z0-9.])${re}([^-0-9A-Za-z]|\$)" skills agents \
    | sed "s/^/deleted-named=$i /"
done
grep -niE 'named option' agents/builder.md agents/verifier.md | sed 's/^/named-option=/'
SH
