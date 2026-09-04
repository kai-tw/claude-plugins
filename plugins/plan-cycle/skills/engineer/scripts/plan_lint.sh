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
#     - every §Facts evidence cell is one of the five typed forms (file:line /
#       實驗：指令 → 觀察 / 未讀 / 只能實測：<how> / 今天成立：<event>); an
#       實驗 cell without both halves is a claim wearing an experiment's clothes
#     - every §Classes summary-table (NEW) row answers `為何要新增` in one of the
#       schema's sanctioned forms (框架/平台：…→… / canonical home：grep … /
#       套件 <名>@<版>：… / 歸屬：…) — the "should this exist" column is the
#       reuse question's only landing spot, and a blank one passed for months
#     - every §Classes canonical-home cell names an actual search term, and no
#       two NEW rows claim the same term has no owner — canonical-home's corpus
#       is defined to include this plan's own §Classes, not just existing code
#     - every contract-table `既有方法夠嗎` cell is typed evidence, same
#       vocabulary as §事實帳 (file:line / 貼出簽名 / F<n> / 實驗：指令 → 觀察 /
#       不足 → <調整> / 今天成立：<條件> / 未讀) — 憑印象作答 is the one
#       illegal answer, and free text is 憑印象 wearing a table cell's clothes
#
#   SKIP (printed, exit code unchanged) — a HARD check whose precondition was
#   empty. It reports WHICH precondition and HOW MUCH went unchecked, and the
#   verdict degrades to `PASS*`: silence is not a verdict.
#
#   ADVISORY (printed, never affects exit code) — anything a correct plan can
#   trip: section presence (headings are TRANSLATED to 繁體中文 under the
#   per-skill §Language section, so an English-only match would false-FAIL),
#   (NEW) files that already exist (legitimate mid-implementation), unresolved
#   §-refs (most point at the upstream plan), back-referenced counts, and a
#   §事實帳 absence/count claim backed by only one verification method (a
#   Chinese-keyword heuristic — eyeball, don't trust blindly).
#
# THE MECHANICAL HALF OF THE ENGINEERING-PLAN GATE.
#   `blueprint-reviewer` owns the judgment; this script owns the
#   comparisons. Everything here is a
#   comparison a reviewer should never be spent on: does the thing the plan
#   names actually exist, does every promise map to a method, does every pointer
#   resolve. Measured motivation — one cycle wrote the same call-site count
#   wrong three revisions running, another asserted a method signature that
#   did not exist, and a third stacked two DAOs on one table because each NEW
#   row's canonical-home grep only ever saw existing code, never the sibling
#   NEW row the same plan was adding — each burning an opus round-trip.
#   Judgement items (silent failure, right owner, SSOT, race) are NOT here.
#
# Usage: plan_lint.sh <engineering-plan.md> [--diff]
# Exit: 0 = no hard failures, 1 = hard failure printed above, 2 = bad usage.
#
# `--diff` is the SAME contract run in the OTHER direction, at commit time
# (closeout Step 5.5's reconciliation leg). Plan-stage checks verify that what
# the plan names exists; `--diff` verifies that what the diff grew was named —
# every added file / class must map to a §Classes NEW row. It is the one
# mechanical net against "the implementer quietly built its own subsystem",
# which no reviewer is scoped to catch (conformance walks spec→code and only
# ever finds what is MISSING; code-reviewer grades the diff's quality, not its
# inventory). Run it AFTER `git add` — untracked files are invisible before.
#
# `PASS*` (a HARD check whose precondition was empty) exits 0 by default —
# deliberate, because a small plan legitimately has no §Data flow, and for a
# human reading the output the printed SKIP lines are the answer.
#
# That was written with a condition attached: give `PASS*` a machine-readable
# form BEFORE wiring this into an automated gate, because a gate reading only the
# exit code would take "3 HARD checks never ran" for a pass. The condition has
# arrived — the caller is an agent now — so `--strict` exists and is what an
# automated caller passes. It exits **3** on PASS*: not 1, which means something
# failed, and not 2, which means the invocation was wrong. Nothing failed here
# and the invocation was fine; the run was simply incomplete, and that is its own
# answer.
#
# Anything automated should pass `--strict`. Without it the old behaviour is
# unchanged, which is the right default for a person at a terminal.
set -uo pipefail

# CJK-safe bracket expressions — this machine ships no UTF-8 locale, so an
# unset LC_CTYPE makes `[^，。]` match bytes and truncate multi-byte tokens.
export LC_ALL=en_US.UTF-8

plan=""; mode=""; strict=""
for a in "$@"; do
  case "$a" in
    --strict) strict=1 ;;
    --diff)   mode=--diff ;;
    -*)       echo "plan-lint: unknown option \"$a\"" >&2
              echo "usage: plan-lint <engineering-plan.md> [--diff] [--strict]" >&2; exit 2 ;;
    *)        [ -z "$plan" ] && plan="$a" || { echo "plan-lint: one plan at a time" >&2; exit 2; } ;;
  esac
done
if [ -z "$plan" ] || [ ! -f "$plan" ]; then
  echo "usage: plan-lint <engineering-plan.md> [--diff] [--strict]" >&2
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

# ── `--diff` — implementation reconciliation (commit stage) ──────────────────
# The reverse direction of check 3: does every class the diff GREW map back to
# a §Classes NEW row? Runs as closeout Step 5.5's reconciliation leg, after
# `git add`. Two legal exits from a FAIL, and only two: Phase 11 divergence
# (add the row — 為何要新增 included — re-run plan-lint + the stage's matrix
# gate, then re-run this), or delete the addition and reuse what exists.
# "A sub-decision inside an approved layer" does not exempt a class here: a
# name the plan never wrote is exactly what this leg exists to surface.
if [ "$mode" = "--diff" ]; then
  if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    echo "FAIL  --diff 需要在 git repo（worktree）內執行"
    exit 1
  fi
  if [ -z "$SECTION_DEFS" ]; then
    # A commit-stage leg fails CLOSED — an unreadable schema here would other-
    # wise wave every unplanned class through on the day node went missing.
    echo "FAIL  --diff：schema unreadable（node 不在？不在 plugin tree？）——§Classes 的 heading 無從解析，對帳沒得跑"
    exit 1
  fi
  classes_body="$(section_body "$(section_pat 'Classes')")"
  if [ -z "$classes_body" ]; then
    echo "FAIL  --diff：計畫沒有 §Classes section，diff 無從對帳"
    exit 1
  fi
  diff_base="--cached"
  if [ -z "$(git diff --cached --name-only 2>/dev/null)" ]; then
    diff_base="HEAD"
    echo "NOTE  staged diff 是空的——退回與 HEAD 比對；untracked 新檔在這個基準下看不到，git add 之後重跑才算數"
  fi
  # Generated / test files are not plan inventory; private classes (_X) are
  # implementation detail. Both excluded by design, not oversight.
  added_files="$(git diff $diff_base --name-only --diff-filter=A 2>/dev/null \
    | grep -E '\.(dart|swift|kt|kts|java|ts|mjs|js)$' \
    | grep -vE '\.g\.dart$|\.freezed\.dart$|(^|/)generated/|(^|/)test/|_test\.[a-z]+$' || true)"
  unplanned_files=""; n_files=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n_files=$((n_files + 1))
    grep -F "$f" <<< "$classes_body" | grep -qE '\((\*\*)?NEW' \
      || unplanned_files="${unplanned_files}${f}"$'\n'
  done <<< "$added_files"
  decls="$(git diff $diff_base -U0 2>/dev/null | grep -E '^\+' \
    | grep -oE '\b(class|mixin) +[A-Z][A-Za-z0-9_]*' \
    | awk '{ print $NF }' | sort -u || true)"
  unplanned_cls=""; n_cls=0
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    n_cls=$((n_cls + 1))
    grep -qE "(^|[^A-Za-z0-9_])${c}([^A-Za-z0-9_]|$)" <<< "$classes_body" \
      || unplanned_cls="${unplanned_cls}${c} "
  done <<< "$decls"
  unplanned_adv=""
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    grep -qE "(^|[^A-Za-z0-9_])${c}([^A-Za-z0-9_]|$)" <<< "$classes_body" \
      || unplanned_adv="${unplanned_adv}${c} "
  done <<< "$(git diff $diff_base -U0 2>/dev/null | grep -E '^\+' \
    | grep -oE '\b(enum|extension) +[A-Z][A-Za-z0-9_]*' | awk '{ print $NF }' | sort -u || true)"
  if [ -n "$unplanned_files" ]; then
    echo "FAIL  diff 新增了 §Classes 沒有任何 NEW 列認領的檔案："
    printf '%s' "$unplanned_files" | sed 's/^/        /'
    fail=1
  fi
  if [ -n "$unplanned_cls" ]; then
    echo "FAIL  diff 新增了 §Classes 沒寫過的 class/mixin：${unplanned_cls}"
    fail=1
  fi
  if [ "$fail" -eq 1 ]; then
    echo "        兩條路，擇一：走 Phase 11 divergence（補進 §Classes——含 為何要新增——重跑"
    echo "        plan-lint 與該 stage 的 matrix gate，再回來重跑本對帳），或刪掉它、reuse 既有機制。"
  fi
  [ -n "$unplanned_adv" ] && echo "ADVISORY  diff 新增了 §Classes 沒寫過的 enum/extension（常是合法實作細節，過目即可）：${unplanned_adv}"
  echo "NOTE  --diff 對帳：${n_files} 個新增檔案、${n_cls} 個新增 class/mixin 已比對（基準：git diff ${diff_base}）"
  [ "$fail" -eq 0 ] && echo "PASS  diff ↔ §Classes 對帳無差異"
  exit "$fail"
fi

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
else
  # No repo → the highest-value reality check never ran. Say so (silence is
  # not a verdict); an unannounced skip here printed a clean PASS for months.
  skip_check "§Classes (MOD)/(DEL) 檔案存在性（HARD）沒跑" \
    "不在 git repo 內（git ls-files 無輸出）" \
    "所有帶標記的檔案列這次一個都沒驗"
fi

# 3b. HARD — §Classes 總表 `為何要新增`. The schema calls this column the ONLY
#     landing spot for "should this exist at all" — and the drafter's duty, not
#     the gate's, precisely because blueprint-reviewer scores inside the design
#     space the author drew. A duty that is nobody's to check decays like any
#     other prose obligation, so the CELL SHAPE is checked here, the same way
#     §事實帳 evidence is: the three sanctioned forms all start with their
#     evidence discipline visible (框架/平台：<查過什麼> → <結論> /
#     canonical home：grep <什麼> → … / 套件 <名>@<版>：…), plus 歸屬：… for a
#     MOD that adds a public member to someone else's owner. Whether the answer
#     is TRUE stays blueprint-reviewer's judgment; that a NEW row ANSWERED, in
#     an evidence-bearing form, is a comparison — and comparisons live here.
classes_body="$(section_body "$(section_pat 'Classes')")"
if [ -z "$classes_body" ]; then
  skip_check "§Classes 為何要新增（HARD）沒跑" "找不到 §Classes section"
elif ! grep -q '為何要新增' <<< "$classes_body"; then
  if grep -qE '\((\*\*)?NEW' <<< "$classes_body"; then
    echo "FAIL  §Classes 總表缺 \`為何要新增\` 欄，但表裡有 NEW 列——「該不該存在」這一題整份計畫沒有落點"
    echo "        總表欄位：| Class | Layer | Kind | File (NEW/MOD/DEL) | 職責 | 持有狀態 | 為何要新增 |"
    fail=1
  else
    skip_check "§Classes 為何要新增（HARD）沒跑" "總表沒有該欄也沒有 NEW 列（純 MOD/DEL 計畫屬正常）"
  fi
else
  reuse_out="$(awk -F'|' '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    /^\|/ {
      if (!inTab && $0 ~ /為何要新增/ && $0 !~ /^[|: -]+$/) {
        for (i = 2; i <= NF; i++) if (trim($i) ~ /為何要新增/) col = i
        ncols = NF; inTab = 1; next
      }
      if (!inTab) next
      if ($0 ~ /^[|: -]+$/) next
      first = trim($2); gsub(/[`*]/, "", first)
      if (first == "" || first == "Class") next
      if ($0 !~ /\((\*\*)?NEW/) next
      nnew++
      if (NF != ncols) { print "MISMATCH\t" first; next }
      cell = trim($col); gsub(/`/, "", cell)
      if (cell == "" || cell == "—" || cell == "-" || cell ~ /^未讀/) { print "MISSING\t" first; next }
      ok = 0
      if (cell ~ /^框架\/平台[：:]/ && cell ~ /→/) ok = 1
      if (cell ~ /^canonical home[：:]/ && cell ~ /grep/) {
        gpos = index(cell, "grep"); apos = index(cell, "→")
        term = (apos > gpos + 4) ? substr(cell, gpos + 4, apos - gpos - 4) : ""
        gsub(/^[ \t`:：]+|[ \t`:：]+$/, "", term)
        if (term != "") { ok = 1; print "CHOME\t" first "\t" term }
      }
      if (cell ~ /^套件/) ok = 1
      if (cell ~ /^歸屬[：:]./) ok = 1
      if (!ok) print "BADFORM\t" first "\t" cell
      next
    }
    !/^\|/ { if (inTab) exit }
    END { print "COUNT\t" nnew + 0 }
  ' <<< "$classes_body")"
  reuse_missing="$(grep '^MISSING	' <<< "$reuse_out" | cut -f2 | tr '\n' ' ')"
  reuse_badform="$(grep '^BADFORM	' <<< "$reuse_out" | cut -f2,3 | sed 's/\t/ → /')"
  reuse_mismatch="$(grep '^MISMATCH	' <<< "$reuse_out" | cut -f2 | tr '\n' ' ')"
  reuse_n="$(grep '^COUNT	' <<< "$reuse_out" | cut -f2)"
  # Same search term cited "→ 無既有擁有者" by ≥2 NEW rows: canonical-home's
  # corpus is defined to include this plan's own §Classes, not just existing
  # code — a grep is structurally blind to a sibling NEW row, so two rows can
  # each honestly report zero hits on the same term and both be wrong together.
  chome_dup="$(grep '^CHOME	' <<< "$reuse_out" | cut -f2,3 | awk -F'\t' '
    { term = $2; gsub(/^[ \t]+|[ \t]+$/, "", term); norm = tolower(term)
      rows[norm] = rows[norm] $1 " "; cnt[norm]++ }
    END { for (t in cnt) if (cnt[t] >= 2) print t "\t" rows[t] }
  ')"
  if [ -n "$reuse_missing" ]; then
    echo "FAIL  §Classes NEW 列的 \`為何要新增\` 空白／—／未讀: ${reuse_missing}"
    echo "        NEW 列必答，擇一或並列：框架/平台：<查過什麼 → 結論>／canonical home：grep <什麼> → <為何 reuse 不了>／"
    echo "        套件 <名>@<版>：<contract clause> → <source>。這一欄沒答，「該不該存在」就沒人問過。"
    fail=1
  fi
  if [ -n "$reuse_badform" ]; then
    echo "FAIL  §Classes NEW 列的 \`為何要新增\` 不是三種帶證據的形式（自由散文＝憑印象；canonical home 沒有逐字搜尋詞——\"grep → 無\" 不是答案——也算）:"
    printf '%s\n' "$reuse_badform" | sed 's/^/        /'
    fail=1
  fi
  if [ -n "$chome_dup" ]; then
    echo "FAIL  §Classes 有 ≥2 個 NEW 列對同一個 canonical-home 搜尋詞都答「無既有擁有者」——這幾列彼此看不見對方，都自認是唯一歸屬:"
    while IFS=$'\t' read -r term rows; do
      [ -n "$term" ] || continue
      echo "        搜尋詞「${term}」→ 列 ${rows}"
    done <<< "$chome_dup"
    echo "        擇一：把其中一列的理由改成指向另一列（本計畫 §Classes 的 <Class> 已是這個資料源的擁有者），或合併成一個 class。"
    fail=1
  fi
  [ -n "$reuse_mismatch" ] && echo "ADVISORY  §Classes 總表列的欄數與表頭不符——這幾列沒進比對: ${reuse_mismatch}"
  echo "NOTE  §Classes 為何要新增: 檢查 ${reuse_n:-0} 個 NEW 列"
fi

# 3c. HARD — contract-table `既有方法夠嗎` typing. Same vocabulary as §事實帳,
#     same reason (the schema says so; until now only the schema said so). A
#     cell that is none of the typed forms is 憑印象作答 — the one illegal
#     answer. `未讀` stays legal and non-gating: it converts to a recon TODO
#     and is surfaced below exactly like §事實帳's 未讀 rows.
if [ -n "$classes_body" ] && grep -q '既有方法夠嗎' <<< "$classes_body"; then
  enough_out="$(awk -F'|' '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    /^### / {
      cls = $0; sub(/^### +/, "", cls); gsub(/[`*]/, "", cls)
      sub(/[^A-Za-z0-9_].*$/, "", cls); intable = 0; next
    }
    cls != "" && /^\|/ {
      hdr = $0; gsub(/[`* |]/, "", hdr)
      if (hdr ~ /^method/) {
        ecol = 0; ncols = NF
        for (i = 2; i <= NF; i++) { c = trim($i); gsub(/[`*]/, "", c); if (c ~ /既有方法夠嗎/) ecol = i }
        intable = 1
        if (!ecol) print "NOCOL\t" cls
        next
      }
      if (!intable || !ecol) next
      if ($0 ~ /^[|: -]+$/) next
      m = trim($2); gsub(/[`*]/, "", m); sub(/\(.*$/, "", m)
      if (m == "" || m ~ /^</) next
      if (NF != ncols) { print "MISMATCH\t" cls "." m; next }
      cell = trim($ecol); gsub(/^`+|`+$/, "", cell)
      if (cell ~ /^未讀/)                    { print "UNREAD\t" cls "." m; next }
      if (cell == "—" || cell == "-")        next
      if (cell ~ /^F[0-9]+$/)                next
      if (cell ~ /^實驗[：:]/)               { if (cell ~ /→/) next
                                               print "BAD\t" cls "." m "\t" cell "（實驗缺 指令 → 觀察）"; next }
      if (cell ~ /今天成立[：:]./)           next
      if (cell ~ /不足/ && cell ~ /→/)       next
      if (cell ~ /[A-Za-z0-9_.\/-]+\.[A-Za-z0-9_]+:[0-9]+/) next
      if (cell ~ /\(/)                       next
      print "BAD\t" cls "." m "\t" cell
      next
    }
    cls != "" && intable && !/^\|/ { intable = 0 }
  ' <<< "$classes_body")"
  enough_bad="$(grep '^BAD	' <<< "$enough_out" | cut -f2,3 | sed 's/\t/ → /')"
  enough_nocol="$(grep '^NOCOL	' <<< "$enough_out" | cut -f2 | tr '\n' ' ')"
  enough_unread="$(grep '^UNREAD	' <<< "$enough_out" | cut -f2 | tr '\n' ' ')"
  enough_mm="$(grep '^MISMATCH	' <<< "$enough_out" | cut -f2 | tr '\n' ' ')"
  if [ -n "$enough_bad" ]; then
    echo "FAIL  \`既有方法夠嗎\` cell(s) 不是型別化證據（憑印象作答）:"
    printf '%s\n' "$enough_bad" | sed 's/^/        /'
    echo "        合法答案：\`file:line\`／貼出簽名／\`F<n>\`／實驗：<指令> → <觀察>／不足 → <調整>／今天成立：<條件>／未讀"
    fail=1
  fi
  if [ -n "$enough_nocol" ]; then
    echo "FAIL  契約表缺 \`既有方法夠嗎\` 欄: ${enough_nocol}"
    fail=1
  fi
  [ -n "$enough_mm" ] && echo "ADVISORY  契約表列欄數與表頭不符——這幾列沒進比對: ${enough_mm}"
  [ -n "$enough_unread" ] && echo "NOTE  既有方法夠嗎 未讀（recon 待辦，approval 前要歸零或明示接受）: ${enough_unread}"
elif [ -n "$classes_body" ]; then
  # A §Classes with contract tables but no 既有方法夠嗎 column anywhere is the
  # same failure as 3b's missing column — the reuse question has no cell to
  # live in. Only fire when a contract table actually exists.
  if grep -qiE '^\|[`* ]*method' <<< "$classes_body"; then
    echo "FAIL  契約表存在但整個 §Classes 沒有 \`既有方法夠嗎\` 欄——每個 method 的 reuse 質問沒有落點"
    fail=1
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
  echo "        否則它們的簽名 / 呼叫 / Error 欄不可能同時正確。"
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
  dangling=""; conf_rows=0; conf_global=0; conf_sibling=0
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
    # A cross-cutting flow may answer 同儕：<feature> <file:line> instead of a
    # Class.method — naming the sibling mechanism it mirrors. The file:line is
    # what consistency-reviewer walks checkpoint-by-checkpoint, so a 同儕 with
    # no anchor is a claim with nothing to compare against.
    if grep -qE '同儕[：:]' <<< "$row"; then
      if grep -qE '同儕[：:][^|]*[A-Za-z0-9_./-]+\.[A-Za-z0-9_]+:[0-9]+' <<< "$row"; then
        conf_sibling=$((conf_sibling + 1)); continue
      fi
      dangling="${dangling}${first}(同儕 未附 file:line 錨點) "
      continue
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
    echo "        或標 \`全域：<怎麼驗>\`（沒有 owning method 的全域斷言，例如某目錄不得存在），"
    echo "        或標 \`同儕：<feature> <file:line>\`（cross-cutting 流程鏡射的既有機制——必附錨點）"
    fail=1
  fi
  echo "NOTE  §Conformance: 檢查 ${conf_rows} 列（全域 ${conf_global}・同儕 ${conf_sibling}）"
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

# 6d. HARD — §Facts (事實帳) evidence typing. The ledger exists so that every
#     load-bearing existing-behavior claim carries evidence a reviewer can spot-
#     check; an evidence cell that is none of the five typed forms is a claim
#     that only LOOKS ledgered — the exact false-confidence the section exists
#     to end. 實驗 additionally needs both halves (指令 → 觀察): a command with
#     no observation proves nothing, an observation with no command cannot be
#     re-run, and 可重跑是實驗與軼事的分界.
facts_body="$(section_body "$(section_pat 'Facts')")"
fact_ids=""
if [ -z "$facts_body" ]; then
  skip_check "事實帳 證據型別（HARD）沒跑" "找不到 §事實帳 section（0.13.0 新增——舊計畫沒有屬正常；新計畫該有，至少一行「不依賴任何既有行為斷言」）"
else
  bad_ev=""; exp_broken=""; exp_undecided=""; fact_rows=0
  n_unread=0; n_device=0; n_exp=0
  device_rows=""; unread_rows=""; absence_single=""
  while IFS= read -r row; do
    case "$row" in \|*) ;; *) continue ;; esac
    grep -qE '^\|[[:space:]|:-]*$' <<< "$row" && continue
    first="$(sed -E 's/^\|[[:space:]]*//; s/[[:space:]]*\|.*$//' <<< "$row" | tr -d '\`*')"
    case "$first" in ''|'#') continue ;; esac
    fact_rows=$((fact_rows + 1))
    fact_ids="${fact_ids}${first}"$'\n'
    ev="$(awk -F'|' '{ gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4 }' <<< "$row")"
    # Classify on the cell with lead backtick/space stripped — authors backtick
    # keywords inconsistently, and a type check that fails on formatting would
    # teach the author to distrust the whole check (same lesson as check 4).
    evs="$(sed -E 's/^[\` []+//' <<< "$ev")"
    # A claim asserting absence or a count ("只有一處"／"沒有任何呼叫端"／"僅 3
    # 個") needs a second, DIFFERENT method — the same corpus searched twice
    # (two greps, two reads of the same doc) shares one blind spot. Heuristic
    # on Chinese function words, so this stays advisory, never a HARD gate.
    claim="$(awk -F'|' '{ gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3 }' <<< "$row")"
    if grep -qE '只有|只由|全部|沒有|從來|唯一|僅有|僅[0-9]|[0-9]+ *(個|次|條|處|列|種)' <<< "$claim"; then
      methods=0
      grep -qE '[A-Za-z0-9_/.-]+\.[A-Za-z0-9_]+:[0-9]+|grep' <<< "$ev" && methods=$((methods + 1))
      grep -qE '實驗|只能實測' <<< "$ev" && methods=$((methods + 1))
      grep -qE '文件|spec|§|計畫|plan' <<< "$ev" && methods=$((methods + 1))
      grep -qE 'pubspec\.lock|git ls-tree|建置狀態|lock 檔' <<< "$ev" && methods=$((methods + 1))
      [ "$methods" -le 1 ] && absence_single="${absence_single}${first} "
    fi
    if grep -qE '^未讀' <<< "$evs"; then
      n_unread=$((n_unread + 1)); unread_rows="${unread_rows}${first} "
    elif grep -qE '^實驗[：:]' <<< "$evs"; then
      n_exp=$((n_exp + 1))
      grep -q '→' <<< "$ev" || exp_broken="${exp_broken}${first} "
      grep -qE '升格|銷毀' <<< "$ev" || exp_undecided="${exp_undecided}${first} "
    elif grep -qE '^只能實測' <<< "$evs"; then
      n_device=$((n_device + 1)); device_rows="${device_rows}${first} "
      grep -qE '^只能實測[：:].' <<< "$evs" || bad_ev="${bad_ev}${first}（只能實測 未指名裝置／方法） "
    elif grep -qE '^今天成立' <<< "$evs"; then
      grep -qE '^今天成立[：:].' <<< "$evs" || bad_ev="${bad_ev}${first}（今天成立 未指名失效事件） "
    elif grep -qE '[A-Za-z0-9_/.-]+\.[A-Za-z0-9_]+:[0-9]+' <<< "$ev"; then
      :  # file:line citation — resolution is the reviewer's spot-check, not ours
    else
      bad_ev="${bad_ev}${first}（非五種證據型別） "
    fi
  done <<< "$facts_body"
  if [ -n "$bad_ev" ]; then
    echo "FAIL  §事實帳 evidence cell(s) outside the five typed forms: ${bad_ev}"
    echo "        每列證據限五型別：\`file:line\`／實驗：<指令> → <觀察>／未讀／只能實測：<裝置或方法>／今天成立：<失效事件>"
    fail=1
  fi
  if [ -n "$exp_broken" ]; then
    echo "FAIL  §事實帳 實驗 row(s) missing 指令 → 觀察 (both halves): ${exp_broken}"
    echo "        沒有觀察的指令證明不了什麼；沒有指令的觀察無法重跑——可重跑是實驗與軼事的分界"
    fail=1
  fi
  if [ "$fact_rows" -gt 0 ]; then
    echo "NOTE  §事實帳: 檢查 ${fact_rows} 列（未讀 ${n_unread}・實驗 ${n_exp}・只能實測 ${n_device}）"
    [ -n "$unread_rows" ] && echo "        未讀（recon 待辦，approval 前要歸零或明示接受）: ${unread_rows}"
    [ -n "$device_rows" ] && echo "        只能實測（每列要有對應的驗證任務，散文不得自行銷案）: ${device_rows}"
    [ -n "$exp_undecided" ] && echo "        實驗列未標 升格／銷毀（任務清單定案時要二選一）: ${exp_undecided}"
  else
    echo "NOTE  §事實帳: 0 列——沒有任何載重斷言的計畫罕見；確認那一行「不依賴」的理由成立"
  fi
  if [ -n "$absence_single" ]; then
    echo "ADVISORY  §事實帳 缺席／計數斷言（含 只/全部/沒有/從來/唯一/N個）疑似只用了一種方法查證: ${absence_single}"
    echo "        同一語料庫查兩次不算兩種——換一種再查一次：搜程式碼・讀實作・實驗・讀文件或本計畫其他章節・查建置狀態；"
    echo "        或者這句其實是單點宣告（一種夠），眼球確認即可。"
  fi
fi

# 6e. ADVISORY — F-refs in prose must resolve to a ledger row. A dangling F-ref
#     is prose leaning on a fact that was renumbered or deleted — the Rev-3-rot
#     shape (one section moved on, the pointers did not). ADVISORY because the
#     `F<digits>` shape can collide with foreign notation; eyeball, don't gate.
if [ -n "$fact_ids" ]; then
  dangling_f=""
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    grep -qxF "$ref" <<< "$fact_ids" || dangling_f="${dangling_f}${ref} "
  done <<< "$(grep -oE '(^|[^A-Za-z0-9_])F[0-9]+' "$plan" | grep -oE 'F[0-9]+' | sort -u)"
  if [ -n "$dangling_f" ]; then
    echo "ADVISORY  F-ref(s) resolving to no §事實帳 row (renumbered or deleted fact — or foreign F-notation): ${dangling_f}"
  fi
fi

# 6c. HARD — a `〔使用者〕` note carries the founder's words VERBATIM (`I4`). A note
#     with no 「」 quote is a paraphrase, and a paraphrase cannot be diffed against
#     what was actually said. That is where a ruling silently loses the
#     distinction it turned on — and `I4` licenses an in-place overwrite every
#     rev, so each one re-authors it. `〔自行裁定〕` is exempt: those words are
#     yours, there is nothing to quote.
paraphrased="$(grep -nE '〔使用者〕' "$plan" | grep -v '「' || true)"
if [ -n "$paraphrased" ]; then
  echo "FAIL  〔使用者〕 note(s) with no 「逐字原話」——裁示被改寫了 (I4):"
  printf '%s\n' "$paraphrased" | cut -c1-120 | sed 's/^/        /'
  fail=1
fi

# 6d. HARD — §Later phases entries must be addressable and concrete.
#     A just-in-time Phased plan (`engineer/SKILL.md` §Right-size the plan)
#     authors one phase and defers the rest to this section, so this section IS
#     the deferred scope — nothing else records it. An entry with no phase id
#     cannot be cited by the rev that later fills it in, and a vague one cannot
#     be told apart from scope that quietly evaporated during the cut. Check 2
#     already bans the English placeholders anywhere in the body; the Chinese
#     ones are banned HERE and only here, because 「之後再說」is legitimate prose
#     in §Risks and is exactly the failure mode in this section.
#
#     Absence of the section is not a skip: a fully-authored plan has no
#     deferred phases, and announcing that as unchecked would fire on every
#     ordinary plan.
later_body="$(section_body '^#{1,2} +(Later phases|後續 ?phase|後續階段)')"
if [ -n "$(printf '%s' "$later_body" | tr -d '[:space:]')" ]; then
  later_rows=0; later_bad=""
  while IFS= read -r line; do
    # Data lines only: a `- ` bullet or a `| … |` table row, never prose,
    # separators or headers.
    case "$line" in
      \|*) grep -qE '^\|[[:space:]|:-]*$' <<< "$line" && continue ;;
      -\ *|\*\ *) ;;
      *) continue ;;
    esac
    body="$(sed -E 's/^[-*][[:space:]]*//; s/^\|[[:space:]]*//' <<< "$line" | tr -d '`*')"
    # The header row must be identified by its FIRST CELL, not by the whole
    # row — `| Phase | 延後範圍 |` matched neither, so every table-form section
    # reported its own header as an entry with no phase id.
    cell1="$(sed -E 's/[[:space:]]*\|.*$//; s/[[:space:]]+$//' <<< "$body")"
    case "$cell1" in ''|Phase|phase|階段|Scope|範圍|延後範圍|內容|說明) continue ;; esac
    later_rows=$((later_rows + 1))
    # Addressable: opens with a phase id (`B`, `Phase B`, `階段 B`, `B-1`).
    if ! grep -qE '^((Phase|階段)[[:space:]]*)?[A-Z][0-9-]*([[:space:]]|[—–:：|]|$)' <<< "$body"; then
      later_bad="${later_bad}
        無 phase 代號: $(cut -c1-90 <<< "$body")"
      continue
    fi
    # Concrete: the deferral says WHAT is deferred, not that it is deferred.
    if grep -qE '(之後再說|再說|待定|另議|其餘|等等|視情況)' <<< "$body"; then
      later_bad="${later_bad}
        佔位語: $(cut -c1-90 <<< "$body")"
    fi
  done <<< "$later_body"
  if [ -n "$later_bad" ]; then
    echo "FAIL  §Later phases 有無法追蹤的延後項目——切分把 scope 弄丟就是從這裡開始:${later_bad}"
    echo "        每列開頭給一個 phase 代號（B / Phase B / 階段 B），內容寫「延後什麼」而非「延後」。"
    echo "        真的要縮 scope 就不是延後，走 plan/divergence.md 回上游改 plan。"
    fail=1
  fi
  echo "NOTE  §Later phases: ${later_rows} 個延後 phase（此計畫為 just-in-time phased）"
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
    # The exit code has to carry it too. This file has said for eight versions
    # that PASS* and PASS share exit 0 and only the printed SKIP lines separate
    # them, and that this is "fine for a human reading output" — with the
    # instruction to give PASS* a machine-readable form BEFORE wiring the script
    # into an automated gate. The caller is now an agent, so that condition has
    # arrived. `--strict` is that form: exit 3, distinct from 1 (a real failure)
    # and from 2 (bad usage), because "some checks never ran" is neither.
    [ -n "$strict" ] && { echo "plan-lint: --strict — exiting 3, because ${skipped} HARD check(s) did not run."; exit 3; }
  else
    echo "PASS  no hard failures (advisory lines above still need an eyeball)"
  fi
fi
exit "$fail"
