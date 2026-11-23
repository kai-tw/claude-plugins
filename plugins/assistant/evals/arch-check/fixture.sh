#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# One project with `spec: none`; check.sh files each slug's reports in a set order, one minute
# apart (round numbers order reports only within a kind), then runs `asst-report reviewed` and
# prints `<case>=<exit code>` and each output line as `<case>: <line>`. Report kinds by word:
# brief, review (brief-review), ui/int/fix (build-ui/build-integration/build-fix), wire (an
# old build-wire file written by hand), vlogic (verify-code with a Logic `fix`), vother
# (verify-code with a `fix` only in block 6), arch/notarch (advise whose Architecture check
# says architecture/not architecture), plain (advise with per-finding sections only), loose
# (advise whose Architecture check first line is not one of the two exact lines).
set -euo pipefail
git init -q wt
mkdir -p wt/.claude
printf 'spec: none\n' > wt/.claude/assistant.md
git -C wt -c user.name=e -c user.email=e@e commit -q --allow-empty -m init
printf '# Export — Decision brief            demo · feature · 2026-11-20\n- Decided  Stream the file · Reason: size\n' > brief.md
printf '## 1 Logic\n## 2 Data flow\n## 5 Built vs approved design\n## Proportion\npassed: 1 2 5\n' > review.md
printf 'phase: build\nrules: style-pack --paths lib/export.sh\n' > build.md
printf '## 1 Logic\n[1.1] fix lib/export.sh:12 — the size is read before the write ends · Fix: read it after\n## 2 Data flow\n## 6 Tests\npassed: 2 6\n' > vlogic.md
printf '## 1 Logic\n## 2 Data flow\n## 6 Tests\n[6.1] fix test/export_test.sh:4 — the empty file case is missing · Fix: add it\npassed: 1 2\n' > vother.md
printf '## Architecture check\nRoot cause: architecture\nEvidence: the size is kept by two layers\nSuggested change: keep it in the store only; lib/export.sh, lib/store.sh; one round\n' > arch.md
printf '## Architecture check\nRoot cause: not architecture\nEvidence: the store alone holds the size\n' > notarch.md
printf '## [1.1] — lib/export.sh:12, Logic\nRoot cause: the size is read before the write ends\nEvidence: lib/export.sh:12\nSuggested fix: read it after\nConfidence: 80\n' > plain.md
printf '## Architecture check\nRoot cause: architecture, probably\nEvidence: the size is kept by two layers\n' > loose.md

cat > check.sh <<'SH'
ws=$PWD; m=0
file() { # file <slug> <kind…> — files each kind in order, one minute apart
  local s=$1 k p f kind; shift
  for k in "$@"; do
    case "$k" in
      brief) kind=brief f=brief ;; review) kind=brief-review f=review ;;
      ui) kind=build-ui f=build ;; int) kind=build-integration f=build ;; fix) kind=build-fix f=build ;;
      vlogic|vother) kind=verify-code f=$k ;; arch|notarch|plain|loose) kind=advise f=$k ;;
    esac
    if [ "$k" = wire ]; then # put files build-wire under its new name; an older version wrote this file
      p=$(cd "$ws/wt" && asst-report latest "$s" brief) && p="$(dirname "$p")/build-wire-1.md" && cp "$ws/build.md" "$p"
    else
      p=$(cd "$ws/wt" && asst-report put "$s" "$kind" < "$ws/$f.md")
    fi || { echo "file $s $k failed"; continue; }
    m=$((m + 1)); touch -t "202611$(printf %02d%02d%02d 20 $((10 + m / 60)) $((m % 60)))" "$p"
  done
}
run() { # run <case> — runs the check on the slug of the same name
  ( cd "$ws/wt" && asst-report reviewed "$1" ) >"$ws/out" 2>&1
  echo "$1=$?"; sed "s/^/$1: /" "$ws/out"
}
B="brief review"
# (a): the 2nd brief version filed after the first build-* report.
file a-fires          $B int brief review brief review
file a-one            $B int brief review
file a-before         $B brief review int brief review
file a-ui             $B ui brief review brief review
file a-fix            $B fix brief review brief review
file a-wire           $B wire brief review brief review
file a-cleared        $B int brief review brief review notarch
file a-cleared-arch   $B int brief review brief arch review
file a-advise-before  $B int brief review arch brief review
file a-plain          $B int brief review brief review plain
file a-loose          $B int brief review brief review loose
file a-third          $B int brief review brief review arch brief review
file a-cleared-unrev  $B int brief review brief notarch
# (b): the first verify-code report after the 2nd build-fix round has a [1.n] fix finding in its Logic block.
file b-fires          $B int vlogic fix vlogic fix vlogic
file b-other          $B int vlogic fix vlogic fix vother
file b-cleared        $B int vlogic fix vlogic fix vlogic notarch
file b-advise-before  $B int vlogic fix vlogic arch fix vlogic
file b-plain          $B int vlogic fix vlogic fix vlogic plain
file b-third          $B int vlogic fix vlogic fix vlogic notarch fix vlogic
file b-integration    $B int vlogic fix vlogic int vlogic fix vother
file b-integration-2  $B int vlogic fix vlogic int vlogic fix vlogic
file b-slices         $B int vlogic fix fix vlogic
file b-slices-2       $B int vlogic fix fix vlogic fix vlogic
for c in a-fires a-one a-before a-ui a-fix a-wire a-cleared a-cleared-arch a-advise-before a-plain a-loose a-third a-cleared-unrev \
         b-fires b-other b-cleared b-advise-before b-plain b-third b-integration b-integration-2 b-slices b-slices-2; do
  run "$c"
done
SH
