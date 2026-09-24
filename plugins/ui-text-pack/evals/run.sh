#!/usr/bin/env bash
# The deterministic half of evals/: per case, scaffold fixture.sh in a fresh workspace, run
# execution.env.EVAL_CMD with this plugin's bin/ on PATH, apply every `type: regex` grader to
# the output. `type: llm` graders need the official runner (early access as of 2026-09):
#   claude plugin eval . --scaffold --allow-tools Bash --trust-plugin
# Usage: evals/run.sh [case …]      Exit: 0 = every regex grader passed, 1 otherwise.
set -uo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cases=("$@"); [ ${#cases[@]} -eq 0 ] && cases=($(cd "$root/evals" && ls -d */ | tr -d /))
val() { sed -nE "s/^[[:space:]]*$1:[[:space:]]*'?([^']*)'?[[:space:]]*$/\1/p" "$2" | head -1; }
fail=0
for c in "${cases[@]}"; do
  dir="$root/evals/$c"; [ -f "$dir/case.yaml" ] || continue
  ws=$(mktemp -d); cmd=$(val EVAL_CMD "$dir/case.yaml"); sc=$(val scaffold_script "$dir/case.yaml")
  out=$(cd "$ws" && bash "$dir/$sc" >/dev/null 2>&1 && PATH="$root/bin:$PATH" eval "$cmd" 2>&1)
  rm -rf "$ws"
  for g in "$dir"/graders/*.md; do
    [ "$(val type "$g")" = regex ] || continue
    pat=$(val pattern "$g"); m=$(val match "$g"); m=${m:-contains}
    ci=; case "$(val flags "$g")" in *i*) ci=-i ;; esac
    if grep -Eq $ci -- "$pat" <<<"$out"; then hit=1; else hit=0; fi
    if { [ "$m" = contains ] && [ $hit = 1 ]; } || { [ "$m" = not_contains ] && [ $hit = 0 ]; }; then
      echo "PASS  $c/$(basename "$g" .md)"
    else
      echo "FAIL  $c/$(basename "$g" .md)  pattern: $pat"; fail=1
    fi
  done
done
exit $fail
