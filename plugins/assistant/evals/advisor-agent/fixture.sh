#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh prints key=value lines about agents/advisor.md, forms/advise.md and references/verify.md.
set -euo pipefail
cat > check.sh <<'SH'
root=$1
a="$root/agents/advisor.md"
fm() { awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f' "$a" 2>/dev/null; }
n() { tr -s ' \n' ' ' < "$1" 2>/dev/null; }
test -f "$a" && echo "advisor-file=present" || echo "advisor-file=missing"
fm | sed -n -e 's/^model: /advisor-model=/p' -e 's/^effort: /advisor-effort=/p'
echo "advisor-blocked=$(fm | awk '/^disallowedTools:/ {f=1; next} f && /^  - / {sub(/^  - /, ""); printf "%s ", $0; next} f {exit}')"
echo "advisor-spawns=$(fm | grep -cE '^  - Agent$' || true)"
echo "advisor-form-line=$(grep -c 'asst-report form advise' "$a" 2>/dev/null || true)"
echo "advisor-read-only=$(n "$a" | grep -ciE 'read-only|never edits the project' || true)"
f="$root/skills/assistant/forms/advise.md"
test -f "$f" && echo "form-file=present" || echo "form-file=missing"
echo "form-fields=$(n "$f" | grep -oE 'Root cause|Evidence|Suggested fix|Confidence' | paste -sd, -)"
v=$(n "$root/skills/assistant/references/verify.md")
echo "dispatch-before-needs=$(grep -ciE 'dispatch the .advisor. once' <<< "${v%%Needs you*}" || true)"
echo "same-finding=$(grep -ciE 'same file, same rule' <<< "$v" || true)"
echo "once-per-finding=$(grep -ciE 'one advisor per finding|never a second' <<< "$v" || true)"
echo "needs-you-with-path=$(grep -ciE 'one .Needs you. line with the advise report.s path' <<< "$v" || true)"
echo "advise-not-posted=$(grep -ciE 'Post each filed .verify-\*. report' <<< "$v" || true)"
SH
