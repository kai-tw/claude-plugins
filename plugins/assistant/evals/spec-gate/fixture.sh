#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# Three projects — a spec at a URL, `spec: none`, no spec line — and the briefs and reviews
# check.sh files into them; check.sh prints `<case>=<exit code>` and each refusal's message.
set -euo pipefail
for p in wt wt-none wt-missing; do git init -q "$p"; mkdir -p "$p/.claude"; done
printf 'rules: none\nspec: https://spec.example/product   # the product spec\n' > wt/.claude/assistant.md
printf 'spec: none\n' > wt-none/.claude/assistant.md
printf 'rules: none\n' > wt-missing/.claude/assistant.md

pages='## Spec pages read
- Export · last edited 2026-11-18 09:12'
q1='- Needs you  Keep the old file? — A: keep / B: replace · Recommend A: undo · Cost of the wrong pick: data loss'
q2='- Needs you  Toast or dialog? — A: toast / B: dialog · Recommend A: quiet · Cost of the wrong pick: noise'
s1=' · spec: "Exports land in the Downloads folder." — names the folder, not a name clash'
s2=' · spec: none in Export § Feedback, Export § Errors'
head='# Export — Decision brief            demo · feature · 2026-11-20'
rest='- Decided  Stream the file · Reason: size

## System design
- Ownership: none'
mk() { printf '%s\n' "$@" > "$f"; }
f=brief-ok.md;        mk "$head" "$pages" '## Intent' "$q1$s1" "$q2$s2 · Picked A" "$rest"
f=brief-no-pages.md;  mk "$head" '## Intent' "$q1$s1" "$q2$s2" "$rest"
f=brief-bad-page.md;  mk "$head" '## Spec pages read' '- Export' '## Intent' "$q1$s1" "$rest"
f=brief-no-field.md;  mk "$head" "$pages" '## Intent' "$q1$s1" "$q2" "$rest"
f=brief-no-why.md;    mk "$head" "$pages" '## Intent' "$q1 · spec: \"Exports land in the Downloads folder.\"" "$rest"
f=brief-cjk.md;       mk "$head" "$pages" '## Intent' "$q1 · spec: 「匯出的檔案存到下載資料夾。」 — 只說資料夾" "$rest"
v1='- Keep the old file · verdict: spec silent'
v2='- Toast or dialog · verdict: spec ambiguous "Errors show a dialog." vs "Feedback is a toast."'
tail='## 1 Logic
passed: 1 2 5'
f=review-ok.md;          mk "$pages" '## Spec verdicts' "$v1" "$v2" "$tail"
f=review-no-pages.md;    mk '## Spec verdicts' "$v1" "$v2" "$tail"
f=review-short.md;       mk "$pages" '## Spec verdicts' "$v1" "$tail"
f=review-bad-verdict.md; mk "$pages" '## Spec verdicts' "$v1" '- Toast or dialog · verdict: unclear' "$tail"

cat > check.sh <<'SH'
ws=$PWD
put() { # put <case> <project> <slug> <kind> <file>
  ( cd "$ws/$2" && asst-report put "$3" "$4" < "$ws/$5" ) >/dev/null 2>"$ws/err"
  echo "$1=$?"; sed 's/^/  /' "$ws/err"
}
put missing         wt-missing x brief       brief-no-pages.md
put none            wt-none    x brief       brief-no-pages.md
put none-review     wt-none    y brief-review review-no-pages.md
put review-first    wt         x brief-review review-ok.md
put no-pages        wt         x brief       brief-no-pages.md
put bad-page        wt         x brief       brief-bad-page.md
put no-field        wt         x brief       brief-no-field.md
put no-why          wt         x brief       brief-no-why.md
put cjk             wt         c brief       brief-cjk.md
put ok              wt         x brief       brief-ok.md
put review-no-pages wt         x brief-review review-no-pages.md
put review-short    wt         x brief-review review-short.md
put review-bad      wt         x brief-review review-bad-verdict.md
put review-ok       wt         x brief-review review-ok.md
echo "filed=$(cd wt && asst-report list x | paste -sd, -)"
SH
