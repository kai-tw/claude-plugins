#!/usr/bin/env bash
# feedback.sh — the one mechanical interface to the feedback ledger.
#
# One feedback item = one markdown file under
# `.claude/skills/feedback-ledger/entries/<category>/`. Four categories, fixed:
# process · code-review · security-review · privacy-review.
#
# WHY per-file instead of the old single-table ledger: the table was appended by
# every cycle and pruned by nobody, so it grew one-way and every edit was a
# whole-file rewrite that two concurrent sessions could clobber. A file per item
# makes `add` an atomic create, makes `count` a directory listing, and makes
# "tidy this category" a delete of the files that got folded into a rule.
#
# NB macOS ships bash 3.2 — no associative arrays, and expanding an EMPTY array
# under `set -u` aborts. Everything here stays on plain strings and `case`.

set -uo pipefail

CATEGORIES='process code-review security-review privacy-review'
SOURCES='founder agent runner'

root() {
  # Resolve the MAIN repo root even when called from inside a worktree, so a
  # cycle running in a worktree still writes to the one canonical ledger.
  local d
  d=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || {
    printf '%s\n' "${CLAUDE_PROJECT_DIR:-$PWD}"; return
  }
  printf '%s\n' "$(dirname "$d")"
}

ROOT=$(root)
BASE="$ROOT/.claude/skills/feedback-ledger/entries"

die() { printf 'feedback: %s\n' "$1" >&2; exit 1; }

valid() { # valid <needle> <haystack-words>
  case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//' | cut -c1-48
}

usage() {
  cat <<'EOF'
feedback.sh — feedback ledger operations

  add <category> --source <who> --title "<one line>" [--cycle <slug>]
        Body is read from STDIN. Creates one file; prints its path.
  list [category]        Table every entry (category, date, source, title).
  count [category]       Per-category counts; bare `count` covers all four.
  over [n]               Print categories with more than n entries (default 5).
                         Exit 1 if any is over, 0 if none. Silent when none.

  category: process | code-review | security-review | privacy-review
  source:   founder | agent | runner

Record review feedback whether it came from the reviewer agent (--source agent)
or from the founder (--source founder) — a founder correction of a review is
the higher-signal half and is the one most often lost.
EOF
}

cmd_add() {
  local cat="${1:-}"; shift || true
  valid "$cat" "$CATEGORIES" || die "unknown category '${cat:-}' (want: $CATEGORIES)"
  local src='' title='' cycle=''
  while [ $# -gt 0 ]; do
    case "$1" in
      --source) src="${2:-}"; shift 2 ;;
      --title)  title="${2:-}"; shift 2 ;;
      --cycle)  cycle="${2:-}"; shift 2 ;;
      *) die "unexpected argument '$1'" ;;
    esac
  done
  [ -n "$src" ] || die "--source is required (want: $SOURCES)"
  valid "$src" "$SOURCES" || die "unknown source '$src' (want: $SOURCES)"
  [ -n "$title" ] || die "--title is required"

  local body; body=$(cat)
  [ -n "$body" ] || die "body is empty — pipe the finding on stdin"

  local date file
  date=$(date +%Y-%m-%d)
  mkdir -p "$BASE/$cat"
  file="$BASE/$cat/${date}-$(slugify "$title").md"
  # Collision (same title, same day) gets a numeric suffix rather than an
  # overwrite — losing a prior entry silently is the one failure mode here.
  if [ -e "$file" ]; then
    local i=2
    while [ -e "${file%.md}-$i.md" ]; do i=$((i+1)); done
    file="${file%.md}-$i.md"
  fi

  {
    printf -- '---\n'
    printf 'category: %s\n' "$cat"
    printf 'source: %s\n' "$src"
    printf 'date: %s\n' "$date"
    [ -n "$cycle" ] && printf 'cycle: %s\n' "$cycle"
    printf -- '---\n\n# %s\n\n%s\n' "$title" "$body"
  } > "$file"
  printf '%s\n' "$file"
}

entries() { # entries <category> — newline-separated paths, empty if none
  [ -d "$BASE/$1" ] || return 0
  find "$BASE/$1" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort
}

field() { # field <file> <key>
  sed -n "s/^$2: *//p" "$1" | head -1
}

cmd_list() {
  local cats="${1:-$CATEGORIES}"
  valid "$cats" "$CATEGORIES" || [ "$cats" = "$CATEGORIES" ] \
    || die "unknown category '$cats' (want: $CATEGORIES)"
  local any=0
  for c in $cats; do
    local files; files=$(entries "$c")
    [ -z "$files" ] && continue
    any=1
    printf '\n%s (%s)\n' "$c" "$(printf '%s\n' "$files" | grep -c .)"
    printf '%s\n' "$files" | while IFS= read -r f; do
      [ -n "$f" ] || continue
      printf '  %-11s %-8s %s\n' "$(field "$f" date)" "$(field "$f" source)" \
        "$(sed -n 's/^# //p' "$f" | head -1)"
      printf '  %-20s %s\n' '' "${f#"$ROOT/"}"
    done
  done
  [ "$any" -eq 0 ] && printf 'feedback: no entries\n'
  return 0
}

cmd_count() {
  local cats="${1:-$CATEGORIES}"
  valid "$cats" "$CATEGORIES" || [ "$cats" = "$CATEGORIES" ] \
    || die "unknown category '$cats' (want: $CATEGORIES)"
  local total=0
  for c in $cats; do
    local n; n=$(entries "$c" | grep -c . || true)
    total=$((total + n))
    printf '%-17s %s\n' "$c" "$n"
  done
  [ "$cats" = "$CATEGORIES" ] && printf '%-17s %s\n' 'TOTAL' "$total"
  return 0
}

cmd_over() {
  local limit="${1:-5}" hit=0
  for c in $CATEGORIES; do
    local n; n=$(entries "$c" | grep -c . || true)
    if [ "$n" -gt "$limit" ]; then printf '%s %s\n' "$c" "$n"; hit=1; fi
  done
  [ "$hit" -eq 1 ] && return 1
  return 0
}

case "${1:-}" in
  add)   shift; cmd_add "$@" ;;
  list)  shift; cmd_list "${1:-}" ;;
  count) shift; cmd_count "${1:-}" ;;
  over)  shift; cmd_over "${1:-}" ;;
  ''|-h|--help|help) usage ;;
  *) usage; exit 1 ;;
esac
