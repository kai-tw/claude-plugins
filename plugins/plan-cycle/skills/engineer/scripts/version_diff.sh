#!/usr/bin/env bash
# Stage 1d — release→dev version diff for migration / back-compat reasoning.
#
# Baseline = the last RELEASED version, NOT HEAD / the last commit: in-flight
# users run the last release, so the migration surface that matters is
# release→dev. Baseline resolves to the last release tag (by creation date),
# falling back to the default branch if no tag exists.
#
# Deterministic, inspectable output — the migration judgement grounds on this
# real git delta, never an LLM re-derivation. Scope to the migration-relevant
# paths (dev runs hundreds of commits ahead; an unscoped diff is unusable).
#
# Usage: version-diff [--tag-pattern <glob>] <path> [<path> ...]
# Exit:  0 = baseline resolved and the report printed
#        1 = no usable baseline (the report would have been wrong, so there is none)
#        2 = bad usage
#
# WHY THIS FAILS LOUDLY. `ABSENT at <baseline>` is not a neutral line: criterion
# 11 reads it as "no user device holds this state", which makes a migration dead
# code and demands its removal. So every way of producing a WRONG absent must
# stop the run instead of printing:
#   - an unresolvable baseline ref would mark every path ABSENT (a `main`
#     fallback on a repo whose default branch is `master`, or where only
#     `origin/main` exists);
#   - a mistyped path is ABSENT at the baseline for a reason that has nothing to
#     do with migration, and reads identically to "introduced after release".
# Both are checked below. A verdict this gate cannot support is not printed.
set -euo pipefail

tag_pattern=""
paths=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --tag-pattern) tag_pattern="${2-}"; [ -n "$tag_pattern" ] || { echo "version-diff: --tag-pattern needs a glob" >&2; exit 2; }; shift 2 ;;
    -*) echo "version-diff: unknown option \"$1\"" >&2; exit 2 ;;
    *) paths+=("$1"); shift ;;
  esac
done

if [ "${#paths[@]}" -eq 0 ]; then
  echo "usage: version-diff [--tag-pattern <glob>] <path> [<path> ...]" >&2
  echo "  diffs each path between the last release baseline and HEAD" >&2
  exit 2
fi

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "version-diff: not inside a git repo — there is no baseline to resolve." >&2
  exit 1
fi

# `--tag-pattern` exists because "the last tag" and "the last RELEASE tag" are
# the same thing only in a repo that tags nothing else. Where they differ, the
# baseline silently becomes the wrong commit — so a project whose tags are mixed
# passes its release glob (e.g. 'v*').
if [ -n "$tag_pattern" ]; then
  baseline="$(git tag --sort=-creatordate --list "$tag_pattern" | head -1 || true)"
else
  baseline="$(git tag --sort=-creatordate | head -1 || true)"
fi

baseline_kind="last release tag"
if [ -z "$baseline" ]; then
  # No tag: fall back to the default branch, but RESOLVE it rather than assuming
  # its name. `main` is a guess, and a wrong guess marks every path ABSENT.
  for candidate in main master origin/main origin/master; do
    if git rev-parse --verify --quiet "$candidate^{commit}" >/dev/null; then
      baseline="$candidate"; baseline_kind="default branch (no release tag found)"
      break
    fi
  done
fi

if [ -z "$baseline" ] || ! git rev-parse --verify --quiet "$baseline^{commit}" >/dev/null; then
  echo "version-diff: no usable baseline — no release tag, and none of main / master /" >&2
  echo "  origin/main / origin/master resolves in this repo. NOT a verdict: without a" >&2
  echo "  baseline every path would read ABSENT, which criterion 11 would take as" >&2
  echo "  \"nothing to migrate from\". Fetch the tags or name the baseline branch." >&2
  exit 1
fi

baseline_sha="$(git rev-parse --short "$baseline")"
echo "## Baseline: $baseline @ $baseline_sha ($baseline_kind) — what in-flight users run"
echo "## HEAD: $(git rev-parse --short HEAD) (dev)"
echo

echo "## Released shape of each scoped path at $baseline"
unknown=0
for p in "${paths[@]}"; do
  at_baseline=0; at_head=0
  git cat-file -e "$baseline:$p" 2>/dev/null && at_baseline=1
  git cat-file -e "HEAD:$p" 2>/dev/null && at_head=1
  if [ "$at_baseline" -eq 1 ]; then
    echo "- $p — present at $baseline (compare the delta below)"
  elif [ "$at_head" -eq 1 ]; then
    echo "- $p — ABSENT at $baseline (introduced after release; no migration FROM it)"
  else
    # Absent at BOTH ends is not a migration fact. Reporting it as plain ABSENT
    # is how a typo becomes "this feature is new, so no migration is needed".
    echo "- $p — NOT FOUND at $baseline OR at HEAD — path does not exist; this says"
    echo "    nothing about migration. Fix the path (a directory needs no trailing slash)."
    unknown=1
  fi
done
echo

if [ "$unknown" -eq 1 ]; then
  echo "## Refusing the diff — at least one path exists at neither end (see above)."
  echo "   Re-run with real paths; a scoped diff over a non-existent path is empty," >&2
  echo "   and an empty diff reads exactly like \"nothing changed\"." >&2
  exit 1
fi

echo "## Diff stat ($baseline..HEAD, scoped)"
git --no-pager diff --stat "$baseline..HEAD" -- "${paths[@]}" || true
echo

# ── Discovery ────────────────────────────────────────────────────────────────
# `engineer/SKILL.md` §Phase 4 names this the one half a test cannot do: "you
# cannot write a migration test for a schema change you have not noticed. Tests
# verify; they do not find." Printing the raw diff and hoping the reader spots
# the persisted shapes in it IS that gap — it holds for three files and fails
# for thirty. So the surfaces get enumerated here, above the diff, where the
# reader is already reasoning about migration.
#
# Advisory, and the patterns are printed with the result so SILENCE IS
# AUDITABLE: you can read what was searched for and judge whether your surface
# would have matched. That is the property this is a script for — an agent's
# "I didn't find any" cannot be read back.
SERIAL_MARKER='fromJson|toJson|@JsonSerializable|@HiveType|@freezed'
STORE_MARKER='SharedPreferences|Hive\.|Isar|sqflite|openDatabase|getApplicationDocumentsDirectory|getApplicationSupportDirectory|writeAsString|writeAsBytes'
FIELD_LINE='^[+-][[:space:]]*(final|const|late|static|var|required|[A-Z][A-Za-z0-9_]*[?[:space:]<])'
# A stored KEY is a string literal, and it almost never sits on a line that also
# names the store: `const kSortOrder = 'sort_order_v2';` mentions no API at all.
# Measured on this script's own fixture — matching the line by keyword missed
# exactly that rename, which is the classic silent-reset migration.
KEY_LINE="^[+-].*'[^']*'|^[+-].*\"[^\"]*\"|schemaVersion|schema_version"
FILE_LITERAL="\\.(json|db|hive|sqlite|isar|txt)['\"]"

echo "## Persistence surfaces in this delta (advisory)"
echo "   searched for: serialized types ($SERIAL_MARKER)"
echo "                 store files ($STORE_MARKER) — every changed literal in them"
echo "                 data-file name literals anywhere in scope"

changed="$(git diff --name-only "$baseline..HEAD" -- "${paths[@]}" 2>/dev/null || true)"
found_any=0
reported=""   # files already listed above; the catch-all below skips them

while IFS= read -r f; do
  [ -n "$f" ] || continue
  # Classify by the file as it stands at HEAD — a type is "serialized" because
  # it declares a codec, and a file is a store because it talks to one; not
  # because some diff line happened to mention either.
  head_body="$(git show "HEAD:$f" 2>/dev/null || true)"
  fdiff="$(git --no-pager diff "$baseline..HEAD" -- "$f" 2>/dev/null | grep -vE '^(\+\+\+|---)' || true)"

  if grep -qE "$SERIAL_MARKER" <<< "$head_body"; then
    fields="$(grep -E "$FIELD_LINE" <<< "$fdiff" || true)"
    if [ -n "$fields" ]; then
      found_any=1
      echo "- $f — serialized type, $(grep -c . <<< "$fields") declaration line(s) changed:"
      printf '%s\n' "$fields" | sed 's/^/      /'
      reported="${reported}${f}"$'\n'
    fi
  fi

  if grep -qE "$STORE_MARKER" <<< "$head_body"; then
    keys="$(grep -E "$KEY_LINE" <<< "$fdiff" || true)"
    if [ -n "$keys" ]; then
      found_any=1
      echo "- $f — store file, $(grep -c . <<< "$keys") literal/version line(s) changed:"
      printf '%s\n' "$keys" | sed 's/^/      /'
      reported="${reported}${f}"$'\n'
    fi
  fi
done <<< "$changed"

# Catch-all for files neither classifier claimed — a data-file name can be
# declared far from the code that opens it. Files already listed are skipped so
# the same line is not printed twice.
while IFS= read -r f; do
  [ -n "$f" ] || continue
  grep -qxF "$f" <<< "$reported" && continue
  lits="$(git --no-pager diff "$baseline..HEAD" -- "$f" 2>/dev/null \
    | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' | grep -E "$FILE_LITERAL" || true)"
  if [ -n "$lits" ]; then
    found_any=1
    echo "- $f — data-file name literal(s) changed:"
    printf '%s\n' "$lits" | sed 's/^/      /'
  fi
done <<< "$changed"

if [ "$found_any" -eq 0 ]; then
  echo "- none matched in the scoped paths."
fi
echo "   Absence here is NOT a clearance: this is a keyword scan over the scoped"
echo "   paths only. A surface it missed still owes §Migration impact a row, and"
echo "   every surface it DID list owes one — a migration test (old-format input →"
echo "   new-typed output + missing-value fallback) or a stated read-compatibility."
echo

echo "## Full diff ($baseline..HEAD, scoped)"
git --no-pager diff "$baseline..HEAD" -- "${paths[@]}" || true
