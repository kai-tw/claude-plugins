#!/usr/bin/env bash
# Plan well-formedness lint (deterministic, plan-stage).
#
# Two kinds of check against the engineering-plan template
# (section schema: run `notion-payload hints engineering-plan`):
#
#   HARD (affect exit code) — language-invariant, safe to gate on:
#     - not empty / not just the skeleton
#     - no banned placeholders (TBD / decide later / as needed / ...) except
#       where a line routes via `## Open questions` / `pending PM|designer|user`
#     - every §Blocks file marked (MOD)/(DEL) exists in the repo
#     - every numbered §Conformance row is claimed by ≥1 §Tasks entry
#
#   ADVISORY (printed, never affects exit code) — anything a correct plan can
#   trip: section presence (headings are TRANSLATED to 繁體中文 under the
#   per-skill §Language section, so an English-only match would false-FAIL),
#   (NEW) files that already exist (legitimate mid-implementation), unresolved
#   §-refs (most point at the upstream plan), and back-referenced counts.
#
# THE MECHANICAL HALF OF THE ENGINEERING-PLAN GATE.
#   `blueprint-reviewer` owns the judgment; this script owns the
#   comparisons. Everything here is a
#   comparison a reviewer should never be spent on: does the thing the plan
#   names actually exist, does every promise map to a task, does every pointer
#   resolve. Measured motivation — one cycle wrote the same call-site count
#   wrong three revisions running, and another asserted a method signature that
#   did not exist, each burning an opus round-trip. Judgement items (silent
#   failure, right owner, SSOT, race) are NOT here.
#
# Usage: plan_lint.sh <engineering-plan.md>
# Exit: 0 = no hard failures, 1 = hard failure printed above, 2 = bad usage.
set -uo pipefail

# CJK-safe bracket expressions — this machine ships no UTF-8 locale, so an
# unset LC_CTYPE makes `[^，。]` match bytes and truncate multi-byte tokens.
export LC_ALL=en_US.UTF-8

plan="${1:-}"
if [ -z "$plan" ] || [ ! -f "$plan" ]; then
  echo "usage: plan-lint <engineering-plan.md>" >&2
  exit 2
fi

fail=0

# Body of the first section whose heading matches $1 (bilingual regex).
section_body() {
  awk -v pat="$1" '
    /^##+ / { inside = ($0 ~ pat) ? 1 : 0; if (inside) next }
    inside  { print }
  ' "$plan"
}

# 1. HARD — empty / skeleton
nonblank="$(grep -cve '^[[:space:]]*$' "$plan" || true)"
if [ "${nonblank:-0}" -lt 30 ]; then
  echo "FAIL  empty/thin — only ${nonblank:-0} non-blank lines (looks empty or skeleton)"
  fail=1
fi

# 2. HARD — banned placeholders (template §Error handling) — allowed only
#    on a line that names an Open-questions route.
placeholders="$(grep -nEi '\b(TBD|decide later|as needed|as appropriate|handle( errors)? appropriately|figure (it )?out)\b' "$plan" 2>/dev/null \
  | grep -viE 'Open questions|pending (PM|designer|user)' || true)"
if [ -n "$placeholders" ]; then
  echo "FAIL  banned placeholder(s) — resolve in the plan body or route via ## Open questions:"
  echo "$placeholders" | sed 's/^/        /'
  fail=1
fi

# 3. §Blocks file reality — the plan's highest-risk sentence is "same as the
#    existing X". A (MOD)/(DEL) row naming a file that isn't in the repo is
#    that sentence, already false. The marker applies to every file token on
#    its row; a row carrying both markers is ambiguous and is skipped.
repo_files=""
if repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  repo_files="$(git -C "$repo_root" ls-files 2>/dev/null)"
fi
# `.md` is deliberately absent — the SOP-reference column cites the project's state-management rule,
# `service-impl.md` etc., which are not files the plan edits.
FILE_TOKEN='`[A-Za-z0-9_/-]+(\.[A-Za-z0-9_-]+)*\.(dart|swift|kt|kts|java|ts|js|mjs|yaml|yml|json|arb|xcstrings|plist|entitlements|xml|gradle|podspec|sh)`'

# Herestrings, not `printf | grep -q`: under `pipefail` a -q grep exits on the
# first match, printf takes SIGPIPE, and the pipeline reports failure — every
# hit would read as a miss.
path_in_repo() {
  local esc
  esc="$(printf '%s' "$1" | sed 's/[.[*^$\\]/\\&/g')"
  grep -qE "(^|/)${esc}\$" <<< "$repo_files"
}

if [ -n "$repo_files" ]; then
  missing=""; premature=""; ambiguous=""
  while IFS= read -r line; do
    has_new=0; has_old=0
    grep -qE '\((\*\*)?NEW' <<< "$line" && has_new=1
    grep -qE '\((\*\*)?(MOD|DEL)' <<< "$line" && has_old=1
    [ $((has_new + has_old)) -eq 0 ] && continue
    # `…/abbreviated/path.dart` is a plan-prose ellipsis, not a real path.
    tokens="$(grep -oE "$FILE_TOKEN" <<< "$line" | tr -d '`' | grep -v '\.\.' | sort -u)"
    [ -z "$tokens" ] && continue
    if [ "$has_new" -eq 1 ] && [ "$has_old" -eq 1 ]; then
      ambiguous="${ambiguous}$(printf '%s' "$tokens" | tr '\n' ' ')"$'\n'
      continue
    fi
    while IFS= read -r tok; do
      [ -z "$tok" ] && continue
      if [ "$has_old" -eq 1 ]; then
        path_in_repo "$tok" || missing="${missing}${tok}"$'\n'
      else
        path_in_repo "$tok" && premature="${premature}${tok}"$'\n'
      fi
    done <<< "$tokens"
  done <<< "$(section_body 'Blocks|積木|區塊')"

  if [ -n "$missing" ]; then
    echo "FAIL  §Blocks marks file(s) (MOD)/(DEL) that are not in the repo — the plan asserts an edit to something that doesn't exist:"
    printf '%s' "$missing" | sort -u | sed 's/^/        /'
    fail=1
  fi
  if [ -n "$premature" ]; then
    echo "ADVISORY  §Blocks (NEW) file(s) that already exist — expected mid-implementation, wrong at first draft:"
    printf '%s' "$premature" | sort -u | sed 's/^/        /'
  fi
  if [ -n "$ambiguous" ]; then
    echo "ADVISORY  §Blocks row(s) carrying both NEW and MOD/DEL — not checked; split the row if the markers apply to different files:"
    printf '%s' "$ambiguous" | sort -u | sed 's/^/        /'
  fi
fi

# 4. ADVISORY — §Conformance ↔ §Tasks, the anti-drop inverse. A row nobody
#    builds is a promise the plan already broke. Advisory rather than hard
#    because plans link the two ends by more than one convention (a task
#    naming `Conformance 2/3/6`, a row naming `Task 15`, or an
#    `Impl block-or-task` column naming the block) — a row this misses may
#    still be covered, so it prints and the author confirms.
conf_body="$(section_body 'Conformance|符合性|對照')"
tasks_body="$(section_body 'Tasks|任務|工作清單')"
conf_nums="$(printf '%s\n' "$conf_body" | grep -oE '^\|[[:space:]]*[0-9]+[[:space:]]*\|' | grep -oE '[0-9]+' || true)"
if [ -n "$conf_nums" ] && [ -n "$tasks_body" ]; then
  # Numbers a task claims, ranges (20–25) expanded.
  claimed="$(printf '%s\n' "$tasks_body" \
    | grep -oE '(Conformance|符合性)[ ：:]*[0-9][0-9/、,，·～－–—[:space:]-]*' \
    | sed -E 's/^(Conformance|符合性)[ ：:]*//' \
    | awk '{
        n = split($0, parts, /[^0-9–—～-]+/)
        for (i = 1; i <= n; i++) {
          if (parts[i] == "") continue
          if (parts[i] ~ /^[0-9]+[–—～-][0-9]+$/) {
            split(parts[i], r, /[–—～-]/); for (k = r[1]; k <= r[2]; k++) print k
          } else if (parts[i] ~ /^[0-9]+$/) print parts[i]
        }
      }' || true)"
  uncovered=""
  while IFS= read -r n; do
    [ -z "$n" ] && continue
    grep -qx "$n" <<< "$claimed" && continue
    # Fallback: the row itself points at a task or an impl block.
    row="$(grep -E "^\|[[:space:]]*${n}[[:space:]]*\|" <<< "$conf_body" || true)"
    grep -qE '(Task|任務)[ ：:]*[0-9]+|`' <<< "$row" && continue
    uncovered="${uncovered}${n} "
  done <<< "$conf_nums"
  if [ -n "$uncovered" ]; then
    echo "ADVISORY  §Conformance row(s) with no discoverable §Tasks link: ${uncovered}"
    echo "        confirm each is built by something — a task naming 'Conformance <n>', or the row naming its task/block"
  fi
fi

# 5. ADVISORY — required-section presence (bilingual; never gates).
#    Each entry: "Label::<english-regex>|<chinese-regex>" matched against `## ` headings.
sections=(
  "Summary::Summary|摘要|總結"
  "Composition::Composition|組合|裝配"
  "Decisions::Decisions?|決策"
  "Risks::Risks|風險"
  "Migration impact::Migration impact|Migration|遷移|相容性|向後相容"
  "Blocks::Blocks|積木|區塊"
  "Data flow::Data flow|資料流"
  "Error handling::Error handling|錯誤處理"
  "Tasks::Tasks|任務|工作清單"
  "Revision history::Revision history|修訂.*(歷史|紀錄)|變更紀錄"
)
headings="$(grep -E '^#{2,3} ' "$plan" 2>/dev/null || true)"
echo "ADVISORY  required-section presence (bilingual; confirm any 'confirm' by eye):"
for entry in "${sections[@]}"; do
  label="${entry%%::*}"
  pat="${entry##*::}"
  if grep -qiE "$pat" <<< "$headings"; then
    echo "        ok       $label"
  else
    echo "        confirm  $label  (no heading matched /$pat/ — translated differently? or missing)"
  fi
done

# 6. ADVISORY — §-refs resolving to no heading in THIS file. Most are upstream
#    (`§Non-goals`, `§AC`); a renamed internal section shows up in the same
#    list, which is the point. `<file>.md §Section` belongs to
#    tool/check-doc-links.sh and is stripped first.
all_headings="$(grep -E '^#+ ' "$plan" | sed -E 's/^#+ *//' || true)"
unresolved=""
while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  grep -qiF -- "$ref" <<< "$all_headings" || unresolved="${unresolved}§${ref} "
done <<< "$(sed -E 's/[A-Za-z0-9_-]+\.md §[^ ]*//g' "$plan" \
  | grep -oE '§[^ 	`|()*（），。、；：！？「」『』／·]+' | sed 's/^§//' | sort -u)"
if [ -n "$unresolved" ]; then
  echo "ADVISORY  §-ref matching no heading here (upstream refs expected; an internal one means a renamed section): ${unresolved}"
fi

# 7. ADVISORY — a count that points back at the document goes stale the moment
#    the thing it counts changes. Prefer naming the items over counting them.
#    Adjacency matters: the marker and the count must be the same phrase, or
#    every long paragraph mentioning both trips it.
backref="$(grep -nE '(上面|上述|前述|以上|下面|如下|前面)(那|這)?[[:space:]]*(兩|三|四|五|六|七|八|九|十|[0-9]+)[[:space:]]*(項|條|個|處|點|列|種)' "$plan" || true)"
if [ -n "$backref" ]; then
  echo "ADVISORY  back-referenced count(s) — re-verify against what they point at, or name the items instead:"
  printf '%s\n' "$backref" | cut -c1-120 | sed 's/^/        /'
fi

# A rev edits the body; it never stacks a layer on top of it (§Plan integrity I1).
stacked="$(grep -nE '^#+ .*(Rev|修訂)[[:space:]]*[0-9]' "$plan" \
  | grep -viE 'Revision history|修訂(歷史|紀錄)|變更紀錄' || true)"
if [ -n "$stacked" ]; then
  echo "ADVISORY  rev section(s) stacked on the body — fold into the prose and record the change in §Revision history (I1):"
  printf '%s\n' "$stacked" | sed 's/^/        /'
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS  no hard failures (advisory lines above still need an eyeball)"
fi
exit "$fail"
