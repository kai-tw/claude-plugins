#!/usr/bin/env bash
# feedback.sh — the one mechanical interface to the feedback ledger.
#
# One feedback item = one markdown file under
# `docs/feedback-ledger/entries/<category>/`. Five categories, fixed:
# process · code-review · security-review · privacy-review · recurring-bug.
# `recurring-bug` is the intake queue for "a defect class we fixed before came
# back" — the entry must name the prior fix AND the new sighting, because a
# lesson without anchors cannot be consumed into a check.
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

CATEGORIES='process code-review security-review privacy-review recurring-bug'
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

# THE one definition of where entries live. `plan-cycle`'s close-out gate reads
# the same directory to check a cycle filed its retro, and used to hardcode this
# path a second time — two copies of a path that must always agree is a defect
# waiting for the day they don't. That gate now asks for it (`plan-feedback
# dir`), so relocating the ledger is this line and nothing else.
#
# Under `docs/`, not `.claude/skills/`: the skill itself ships with the plugin,
# so a consuming project has no `.claude/skills/feedback-ledger/` of its own —
# writing data there would leave an orphan directory with no SKILL.md beside it.
BASE="$ROOT/docs/feedback-ledger/entries"

# The path entries lived at BEFORE the move above. A project that adopted this
# plugin earlier still has one, and nothing in this script can see it — so `count`
# printing 0 reads as "nothing owed" while real entries sit in the old directory.
# That is not hypothetical: a 2026-08-07 incident report stayed unconsumed there
# precisely because every command reported an empty ledger. Report it wherever a
# count is read; moving the files is the reader's call, not this script's.
LEGACY="$ROOT/.claude/skills/feedback-ledger/entries"

legacy_note() {
  [ -d "$LEGACY" ] || return 0
  local n
  n=$(find "$LEGACY" -name '*.md' -type f 2>/dev/null | grep -c .) || true
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  [ "$n" -gt 0 ] || return 0
  printf 'feedback: NOTE — %s entr%s stranded in the pre-move path, counted by nothing:\n' \
    "$n" "$([ "$n" -eq 1 ] && echo y || echo ies)" >&2
  printf '  %s\n' "${LEGACY#"$ROOT/"}" >&2
  printf '  Move each category dir into %s/, or consume them and delete.\n' "${BASE#"$ROOT/"}" >&2
}

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
plan-feedback — feedback ledger operations

  add <category> --source <who> --title "<one line>" [--cycle <slug>]
        Body is read from STDIN. Creates one file; prints its path.
  list [category]        Table every entry (category, date, source, title).
  count [category]       Per-category counts; bare `count` covers every category.
  over [n]               Print categories with more than n entries (default 5).
                         Exit 1 if any is over, 0 if none. Silent when none.
  dir                    Print the entries directory. This script owns that
                         path; anything else needing it asks here rather than
                         keeping a second copy that can drift.

`list`, `count` and `over` also warn (on stderr) when entries are still sitting in
the pre-move path `.claude/skills/feedback-ledger/entries/` — a count of 0 there
means "not looked at", not "nothing owed".

  category: process | code-review | security-review | privacy-review | recurring-bug
  source:   founder | agent | runner

recurring-bug entries must anchor BOTH ends: the prior fix (commit / incident /
test id) and the new sighting (file:line or repro) — consumption lands them in
the qa failure-class index or the project's consistency mechanism table.

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
  legacy_note
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
  legacy_note
  return 0
}

cmd_over() {
  local limit="${1:-5}" hit=0
  for c in $CATEGORIES; do
    local n; n=$(entries "$c" | grep -c . || true)
    if [ "$n" -gt "$limit" ]; then printf '%s %s\n' "$c" "$n"; hit=1; fi
  done
  legacy_note
  [ "$hit" -eq 1 ] && return 1
  return 0
}

case "${1:-}" in
  add)   shift; cmd_add "$@" ;;
  list)  shift; cmd_list "${1:-}" ;;
  count) shift; cmd_count "${1:-}" ;;
  over)  shift; cmd_over "${1:-}" ;;
  dir)   printf '%s\n' "$BASE" ;;
  ''|-h|--help|help) usage ;;
  *) usage; exit 1 ;;
esac
