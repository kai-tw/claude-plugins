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
#     - every §Classes file marked (MOD)/(DEL) exists in the repo
#     - every §Conformance row points at a `Class.method` §Classes defines,
#       or declares `全域：<how it is verified>`
#     - §Data flow graph nodes exist in §Classes; every ≥2-origin state node has
#       an §Error policy row
#
#   SKIP (printed, exit code unchanged) — a HARD check whose precondition was
#   empty. It reports WHICH precondition and HOW MUCH went unchecked, and the
#   verdict degrades to `PASS*`: silence is not a verdict.
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
#   names actually exist, does every promise map to a method, does every pointer
#   resolve. Measured motivation — one cycle wrote the same call-site count
#   wrong three revisions running, and another asserted a method signature that
#   did not exist, each burning an opus round-trip. Judgement items (silent
#   failure, right owner, SSOT, race) are NOT here.
#
# Usage: plan_lint.sh <engineering-plan.md>
# Exit: 0 = no hard failures, 1 = hard failure printed above, 2 = bad usage.
#
# `PASS*` (a HARD check whose precondition was empty) also exits 0 — deliberate,
# because a small plan legitimately has no §Data flow. The consequence: healthy,
# broken, and "you fed me a design plan" are the SAME exit code, and only the
# printed SKIP lines tell them apart. That is fine for a human reading output.
# **Before wiring this into any automated gate, give `PASS*` a machine-readable
# form first** (a `--strict` flag, or exit 2) — a gate that reads only the exit
# code would treat "3 HARD checks never ran" as a pass, which is the exact
# failure this script spent eight versions learning to say out loud.
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

# Section definitions straight from schemas/engineering-plan.mjs, one
# `Key::<heading regex>` per line — read once. Empty when node is missing or we
# run outside the plugin tree; every caller then degrades to an announced skip
# rather than a wrong answer. Keeping a copy of this list here is what let a
# retired section linger in the linter, so there is no fallback list.
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SECTION_DEFS="$(node "$here/../../archivist/scripts/notion_payload.mjs" \
  sections engineering-plan 2>/dev/null || true)"
[ -n "$SECTION_DEFS" ] || echo "ADVISORY  schema unreadable (node missing, or run outside the plugin tree) — the §Conformance, §Data flow and section-presence checks below are SKIPPED, not passed"

# The heading regex for one section key. Empty if unknown.
section_pat() {
  printf '%s\n' "$SECTION_DEFS" | awk -F'::' -v k="$1" '$1 == k { print $2; exit }'
}

# Body of the first section whose heading matches $1 (bilingual regex).
# An empty pattern matches nothing — never the whole file.
#
# A `##` section ends at the next `#` or `##`, NEVER at a `###`. The old rule
# tested every `^##+ ` line, so a section whose content hangs under `###`
# subheadings (`## Data flow` → `### 情境 A`) returned a one-byte body — and the
# checks that read it skipped without a word.
section_body() {
  [ -n "$1" ] || return 0
  awk -v pat="$1" '
    /^#{1,2} [^#]/ { inside = ($0 ~ pat) ? 1 : 0; if (inside) next }
    inside  { print }
  ' "$plan"
}

# A HARD check that never ran must not hide behind PASS.
#
# The SKIP also carries HOW MUCH went unchecked. "no §Data flow in a small plan"
# and "a full §Conformance table sat there and not one row was verified" are the
# same state and wildly different news; without the number the reader has to go
# and count, and whoever would do that was never the one at risk. A count of
# zero gets its own wording — a bare `0` in a severity line reads as reassurance.
skipped=0
skip_check() {   # skip_check "<what did not run>" "<why>" ["<how much went unchecked>"]
  echo "SKIP  $1 —— $2"
  [ -n "${3:-}" ] && echo "        $3"
  skipped=$((skipped + 1))
}

# Data rows of a pipe table body — the same "not the separator, not the header"
# rule check 4 uses, hoisted so it can also run when check 4 cannot.
count_data_rows() {
  printf '%s\n' "$1" | awk '
    /^\|/ {
      if ($0 ~ /^[|: -]+$/) next
      first = $0; sub(/^\|[[:space:]]*/, "", first); sub(/[[:space:]]*\|.*$/, "", first)
      gsub(/[`*]/, "", first)
      if (first == "" || first == "#" || first == "Requirement" || first == "需求") next
      n++
    }
    END { print n + 0 }
  '
}

# 1. HARD — empty / skeleton
nonblank="$(grep -cve '^[[:space:]]*$' "$plan" || true)"
if [ "${nonblank:-0}" -lt 30 ]; then
  echo "FAIL  empty/thin — only ${nonblank:-0} non-blank lines (looks empty or skeleton)"
  fail=1
fi

# 2. HARD — banned placeholders (template §Error policy) — allowed only
#    on a line that names an Open-questions route.
placeholders="$(grep -nEi '\b(TBD|decide later|as needed|as appropriate|handle( errors)? appropriately|figure (it )?out)\b' "$plan" 2>/dev/null \
  | grep -viE 'Open questions|pending (PM|designer|user)' || true)"
if [ -n "$placeholders" ]; then
  echo "FAIL  banned placeholder(s) — resolve in the plan body or route via ## Open questions:"
  echo "$placeholders" | sed 's/^/        /'
  fail=1
fi

# 3. §Classes file reality — the plan's highest-risk sentence is "same as the
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
  done <<< "$(section_body "$(section_pat 'Classes')")"

  if [ -n "$missing" ]; then
    echo "FAIL  §Classes marks file(s) (MOD)/(DEL) that are not in the repo — the plan asserts an edit to something that doesn't exist:"
    printf '%s' "$missing" | sort -u | sed 's/^/        /'
    fail=1
  fi
  if [ -n "$premature" ]; then
    echo "ADVISORY  §Classes (NEW) file(s) that already exist — expected mid-implementation, wrong at first draft:"
    printf '%s' "$premature" | sort -u | sed 's/^/        /'
  fi
  if [ -n "$ambiguous" ]; then
    echo "ADVISORY  §Classes row(s) carrying both NEW and MOD/DEL — not checked; split the row if the markers apply to different files:"
    printf '%s' "$ambiguous" | sort -u | sed 's/^/        /'
  fi
fi

# ── The closure checks ────────────────────────────────────────────────────────
# Everything below is a comparison between two things the plan already wrote.
# They live here, not in blueprint-reviewer's rubric, because a script settles
# them for free and deterministically — and because two verdicts on one question
# can disagree. The reviewer is told to take these as given.

# Every `Class.method` the plan defines: the ### class blocks' table rows.
# A contract row starts `| method |` under a `### <Class>` heading.
#
# NORMALISE, THEN REPORT WHAT WOULD NOT NORMALISE. Real plans write the heading
# as ``### `Store`（契約，MOD）`` and the first cell as `` `erase({a, b})` `` — a
# raw read of either yields a name that can never match a `Class.method`
# citation, so every downstream check silently compares against garbage. Take the
# leading identifier from each, and surface any cell that still isn't one name
# rather than letting it rot in the set.
extract="$(awk '
  # A class block ends at the next section. Without this the harvest runs on
  # through §Error policy / §Startup / §Risks and adopts their table rows as
  # methods of the last class seen — and an identifier-shaped cell there
  # (`| mirrorCache |`) enters the set as a method that does not exist.
  /^## / { if (cls != "" && !seen) print "NOTABLE\t" cls; cls = ""; intable = 0; next }
  /^### / {
    if (cls != "" && !seen) print "NOTABLE\t" cls
    cls = $0; sub(/^### +/, "", cls); gsub(/[`*]/, "", cls)
    sub(/[^A-Za-z0-9_].*$/, "", cls)          # `Store`（契約，MOD） → Store
    intable = 0; seen = 0
    next
  }
  # ONLY the contract table counts — the one opening with the `method` header.
  # A class block may hold further tables that argue a design decision, and
  # harvesting those reported their rows as broken method cells: a false
  # positive landing hardest on the plans that explain themselves best.
  cls != "" && /^\|/ {
    hdr = $0; gsub(/[`* |]/, "", hdr)
    if (hdr ~ /^method/) { intable = 1; seen = 1; next }
    if (!intable) next
    if ($0 ~ /^[|: -]+$/) next                 # the |---|---| separator row
    line = $0; gsub(/^\| *| *\|$/, "", line)
    split(line, f, /  *\| */); m = f[1]; gsub(/[`* ]/, "", m)
    if (m == "" || m ~ /^</) next
    raw = m
    sub(/\(.*$/, "", m)                        # erase({a,b}) → erase
    if (m ~ /^[A-Za-z_][A-Za-z0-9_]*$/) print "OK\t" cls "." m
    else print "BAD\t" cls "\t" raw
    next
  }
  # The contract table ends at the first line that is not one of its rows.
  cls != "" && intable { intable = 0 }
  END { if (cls != "" && !seen) print "NOTABLE\t" cls }
' "$plan")"
# A class block with no contract table harvests nothing — which would otherwise
# look identical to a class with no public surface. Say it.
no_table="$(grep '^NOTABLE	' <<< "$extract" | cut -f2 | sort -u)"
if [ -n "$no_table" ]; then
  echo "ADVISORY  §Classes block(s) with no \`| method |\` contract table — 它們的 method 不在比對集合裡:"
  printf '%s\n' "$no_table" | sed 's/^/        /'
fi
contract_methods="$(grep '^OK	' <<< "$extract" | cut -f2 | sort -u)"
malformed="$(grep '^BAD	' <<< "$extract" | cut -f2,3 | sort -u)"
if [ -n "$malformed" ]; then
  echo "ADVISORY  §Classes method cell(s) that are not a single method name — 這幾列不會參與比對:"
  printf '%s\n' "$malformed" | sed 's/\t/ → /' | sed 's/^/        /'
  echo "        一列一個 method；簽名放 \`簽名\` 欄。多個 method 擠一格（fetch·publish·remove）要拆成多列，"
  echo "        否則它們的簽名 / 複雜度 / Error 欄不可能同時正確。"
fi

# 4. HARD — §Conformance rows must point at a Class.method the plan defines,
#    or declare `全域：<how>` when the requirement genuinely has no owning method
#    (a directory that must not exist, a dead name that must not appear).
#    A row naming something that does not exist is a promise with no owner, and
#    it is the one direction nothing else catches (a missed requirement produces
#    no class, so absence is invisible to every other section).
#
#    THE ROW ID IS THE AUTHOR'S, NOT THIS SCRIPT'S. A previous version required
#    the first cell to be a bare integer and silently `continue`d otherwise, so a
#    plan numbering its rows `X-1` / `C-3` had EVERY row skipped while the run
#    still printed PASS. Identify a data row by what it is not — the separator
#    and the header — never by the shape of its id.
conf_body="$(section_body "$(section_pat 'Conformance')")"
if [ -z "$conf_body" ]; then
  skip_check "§Conformance ↔ Class.method（HARD）沒跑" "找不到 §Conformance section"
elif [ -z "$contract_methods" ]; then
  skip_check "§Conformance ↔ Class.method（HARD）沒跑" \
    "§Classes 沒有可比對的 method（section 名稱不符？或沒有 \`### <Class>\` + \`| method |\` 表）" \
    "§Conformance 有 $(count_data_rows "$conf_body") 列在等，這次一列都沒驗"
else
  dangling=""; conf_rows=0; conf_global=0
  while IFS= read -r row; do
    case "$row" in \|*) ;; *) continue ;; esac
    # Separator (`|---|---|`) and header (first cell `#` / `Requirement`).
    grep -qE '^\|[[:space:]|:-]*$' <<< "$row" && continue
    first="$(sed -E 's/^\|[[:space:]]*//; s/[[:space:]]*\|.*$//' <<< "$row" | tr -d '`*')"
    case "$first" in ''|'#'|Requirement|需求) continue ;; esac
    conf_rows=$((conf_rows + 1))
    # A requirement with no owning method is legal, but must say how it is
    # verified — an unexplained blank is the failure this check exists for.
    if grep -qE '全域[：:][^|[:space:]]' <<< "$row"; then
      conf_global=$((conf_global + 1)); continue
    fi
    # `privacy.md` / `pubspec.yaml` in a Source cell look exactly like
    # `Class.method`; excluding known file extensions costs one grep and a false
    # positive here would teach the author to distrust the whole check.
    refs="$(grep -oE '`[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*`' <<< "$row" \
      | tr -d '`' \
      | grep -viE '\.(md|dart|yaml|yml|json|arb|sh|mjs|ts|js|lock|txt|png|xml)$' || true)"
    if [ -z "$refs" ]; then
      dangling="${dangling}${first}(無 Class.method，也未標 全域：) "
      continue
    fi
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      grep -qxF "$r" <<< "$contract_methods" || dangling="${dangling}${first}→${r} "
    done <<< "$refs"
  done <<< "$conf_body"
  if [ -n "$dangling" ]; then
    echo "FAIL  §Conformance row(s) pointing at no defined method: ${dangling}"
    echo "        每列的「實作於」要指向 §Classes 某個 class 區塊裡實際存在的 Class.method，"
    echo "        或標 \`全域：<怎麼驗>\`（沒有 owning method 的全域斷言，例如某目錄不得存在）"
    fail=1
  fi
  echo "NOTE  §Conformance: 檢查 ${conf_rows} 列（其中 ${conf_global} 列標為 全域）"
fi

# 5. HARD — §Data flow graph nodes must exist in §Classes. A node naming a class
#    or method the plan never defines is name drift, and it silently breaks the
#    race derivation below (which counts edges into state nodes).
#    Accept the quoted and unquoted mermaid label forms both — matching only one
#    of them would examine zero nodes on a legal graph and still print PASS,
#    which is the same silent-skip failure as the id shape in check 4.
flow_body="$(section_body "$(section_pat 'Data flow')")"
# Every check below is really preconditioned on "is there a graph", not "is
# there a section" — a §Data flow full of prose has a body and no graph. Compute
# it ONCE: the three consumers drifted apart when each tested for itself, and a
# check that asserts `0 state nodes` about a graph that does not exist reads as
# a verified result.
has_graph=0
[ -n "$flow_body" ] && grep -q '```mermaid' <<< "$flow_body" && has_graph=1

if [ -z "$flow_body" ]; then
  skip_check "§Data flow 節點 ↔ §Classes（HARD）沒跑" "找不到 §Data flow section"
elif [ -z "$contract_methods" ]; then
  flow_pending="$(grep -oE '\["?[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*"?\]' <<< "$flow_body" | sort -u | grep -c . || true)"
  if [ "${flow_pending:-0}" -gt 0 ]; then
    skip_check "§Data flow 節點 ↔ §Classes（HARD）沒跑" "§Classes 沒有可比對的 method" \
      "圖上有 ${flow_pending} 個 Class.method 節點沒被比對"
  elif [ "$has_graph" -eq 1 ]; then
    skip_check "§Data flow 節點 ↔ §Classes（HARD）沒跑" "§Classes 沒有可比對的 method" \
      "圖裡沒有 [Class.method] 節點——圖在，但它沒有可以對回 §Classes 的東西"
  else
    # Reachable only with a NON-empty body (the empty case returned above), so
    # "nothing to compare" would be a lie: the section exists, it just never
    # got its graph. Naming that as normal is how a missing artefact reads as
    # a clean result.
    skip_check "§Data flow 節點 ↔ §Classes（HARD）沒跑" "§Classes 沒有可比對的 method" \
      "§Data flow 有內容但沒有 mermaid 圖 —— 這一節缺一張圖，不是沒東西要查"
  fi
else
  unknown=""; flow_nodes=0
  flow_list="$(grep -oE '\["?[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*"?\]' <<< "$flow_body" \
    | sed -E 's/^\["?//; s/"?\]$//' | sort -u)"
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    flow_nodes=$((flow_nodes + 1))
    grep -qxF "$n" <<< "$contract_methods" || unknown="${unknown}${n} "
  done <<< "$flow_list"
  if [ -n "$unknown" ]; then
    echo "FAIL  §Data flow node(s) not defined in §Classes: ${unknown}"
    echo "        圖上的 [\"Class.method\"] 節點必須逐字對上某個 class 區塊的一列"
    fail=1
  fi
  echo "NOTE  §Data flow: 檢查 ${flow_nodes} 個 Class.method 節點"
  [ "$flow_nodes" -eq 0 ] && echo "        0 個節點 —— 圖裡沒有可比對的 [Class.method]，這一項等於沒跑，不是通過"
fi

# The origin check needs only the graph, never `contract_methods` — keeping it
# inside that guard meant a plan with no graph at all skipped BOTH the node
# comparison and the one advisory that would have said the graph is missing.
if [ -n "$flow_body" ] && ! grep -qE '\(\[.*\]\)' <<< "$flow_body"; then
  if [ "$has_graph" -eq 1 ]; then
    echo "ADVISORY  §Data flow has no ([origin]) node — 沒有併發來源的圖回答不了它該回答的問題；真的只有單一入口就明寫一行"
  else
    echo "ADVISORY  §Data flow 沒有 mermaid 圖 — race 推導完全沒有輸入；§Error policy 的爭用表因此無從封閉"
  fi
fi

# 6. HARD — every state node written from ≥2 origins needs an §Error policy row.
#    This is the whole point of typing the graph: it turns "did you think of a
#    race" (unfalsifiable) into "did you account for what you drew" (checkable).
if [ -z "$flow_body" ]; then
  skip_check "共享狀態爭用 ↔ §Error policy（HARD）沒跑" "找不到 §Data flow section，無從推導"
elif [ "$has_graph" -eq 0 ]; then
  skip_check "共享狀態爭用 ↔ §Error policy（HARD）沒跑" "§Data flow 沒有 mermaid 圖，race 無從推導" \
    "這一節缺一張圖 —— 不是「圖上沒有爭用狀態」"
else
  policy_body="$(section_body "$(section_pat 'Error policy')")"
  uncovered=""; state_nodes=0; contended=0
  # mermaid declares a node once with its label (`M[("cache")]`) and refers to it
  # by id everywhere after (`A --> M`), so count edges by ID, not by label.
  # Quoted and unquoted labels both — see the note on check 5.
  while IFS=' ' read -r id label; do
    [ -n "$id" ] || continue
    state_nodes=$((state_nodes + 1))
    writers="$(grep -oE -- "--> *${id}\b" <<< "$flow_body" | grep -c . || true)"
    [ "${writers:-0}" -ge 2 ] || continue
    contended=$((contended + 1))
    grep -qF "$label" <<< "$policy_body" || uncovered="${uncovered}${label} "
  done <<< "$(grep -oE '[A-Za-z0-9_]+\[\("?[^]"]+"?\)\]' <<< "$flow_body" \
    | sed -E 's/^([A-Za-z0-9_]+)\[\("?(.*[^"])"?\)\]$/\1 \2/' | sort -u)"
  if [ -n "$uncovered" ]; then
    echo "FAIL  state node(s) written from ≥2 edges with no §Error policy row: ${uncovered}"
    echo "        圖上被多方寫入的狀態，每一個都要在 §Error policy 的爭用表有一列"
    fail=1
  fi
  echo "NOTE  §Error policy: 圖上 ${state_nodes} 個狀態節點，其中 ${contended} 個被多方寫入"
fi

# 6b. NOTE — claims with a shelf life. `未讀` marks "I did not check"; this marks
#     "I checked, it is true, and it will stop being true" — the only one of the
#     two that ROTS SILENTLY, because it reads like a settled fact. Surfacing the
#     count is what makes a rev re-examine them (§Re-audit every plan change).
perishable="$(grep -nE '今天成立[：:]' "$plan" || true)"
if [ -n "$perishable" ]; then
  perish_n="$(printf '%s\n' "$perishable" | grep -c .)"
  echo "NOTE  ${perish_n} 處標為「今天成立」——有保鮮期的斷言，每次 rev 都要重新確認:"
  printf '%s\n' "$perishable" | cut -c1-120 | sed 's/^/        /'
fi

# 7. ADVISORY — complexity cells carry both halves and a named variable.
#    An unnamed O(n) is decoration: nobody can falsify it.
bad_cx="$(grep -nE '^\|' "$plan" | grep -E 'T:|S:' \
  | grep -vE 'T:[^|]*S:' || true)"
if [ -n "$bad_cx" ]; then
  echo "ADVISORY  複雜度格只填了一半（要 T: 和 S: 兩半）:"
  printf '%s\n' "$bad_cx" | cut -c1-120 | sed 's/^/        /'
fi
unnamed_o="$(grep -nE 'O\([^)]*[a-z][^)]*\)' "$plan" | grep -vE '[nmk] *=' | grep -E 'T:|S:' || true)"
if [ -n "$unnamed_o" ]; then
  echo "ADVISORY  Big-O 沒指名變數（要寫 n=書籍數 之類，否則不可證偽）:"
  printf '%s\n' "$unnamed_o" | cut -c1-120 | sed 's/^/        /'
fi

# 5. ADVISORY — required-section presence (bilingual; never gates).
#    The list comes from schemas/engineering-plan.mjs, never from a copy here:
#    a second copy is how a retired section stayed in this linter, telling every
#    correct plan to add a heading that must not exist.
if [ -n "$SECTION_DEFS" ]; then
  headings="$(grep -E '^#{2,3} ' "$plan" 2>/dev/null || true)"
  echo "ADVISORY  required-section presence (bilingual; confirm any 'confirm' by eye):"
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    label="${entry%%::*}"
    pat="${entry##*::}"
    if grep -qiE "$pat" <<< "$headings"; then
      echo "        ok       $label"
    else
      echo "        confirm  $label  (no heading matched /$pat/ — translated differently? or missing)"
    fi
  done <<< "$SECTION_DEFS"
fi

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
  echo "ADVISORY  rev section(s) stacked on the body — fold into the prose and update the decision note there (I1/I4):"
  printf '%s\n' "$stacked" | sed 's/^/        /'
fi

if [ "$fail" -eq 0 ]; then
  if [ "$skipped" -gt 0 ]; then
    # An unqualified PASS after a check never ran is the failure this whole
    # script keeps re-learning: the reader takes silence for a verdict.
    echo "PASS*  no hard failures — 但有 ${skipped} 項 HARD 檢查沒跑（見上方 SKIP）。這不是「通過」，是「沒查」。"
  else
    echo "PASS  no hard failures (advisory lines above still need an eyeball)"
  fi
fi
exit "$fail"
