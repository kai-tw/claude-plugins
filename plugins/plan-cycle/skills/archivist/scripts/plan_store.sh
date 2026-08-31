#!/usr/bin/env bash
# plan_store.sh — where a plan LIVES, separated from what a plan IS.
#
# WHY THIS EXISTS
#   `notion-payload` was doing two jobs. Its `hints` / `template` / `sections` /
#   `criteria` commands define the plan FORMAT — sections, required fields, the
#   禁-lists — and have nothing to do with Notion. Its `create` / `append` /
#   `set` commands are the STORE. Only the second half needs a workspace, but
#   both were reached through one binary, so a project without Notion could not
#   author a plan at all.
#
#   Format stays with `notion-payload`. Destination lives here.
#
# THE TWO STORES
#   notion  a plan is a page, its address is a URL, and Stage on the row is the
#           durable record that outlives a lost ledger.
#   repo    a plan is a gitignored file under `.claude/.plan-cycle/plans/`, and
#           its address is a path. Survives a reboot, is visible to every
#           session and worktree of this repo, and `sweep` already walks there.
#
#   NOT /tmp: it dies on reboot, sits outside the repo, and no other session can
#   see it — strictly worse than the ledger it would be backing up.
#
# THE STORE IS DECLARED, NEVER DETECTED
#   An earlier draft picked the store by looking for the `ntn` CLI on PATH. That
#   is an inference about intent from a fact about a machine: a laptop with the
#   CLI installed for one project would silently choose Notion for a project
#   that has no workspace, and the first sign would be a failed write with the
#   plan already authored. One word in one file, or a refusal that says how to
#   write it.
set -uo pipefail

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "plan-store: not in a git repo" >&2; exit 2; }
common=$(git rev-parse --git-common-dir 2>/dev/null) || common="$root/.git"
case "$common" in /*) ;; *) common="$root/$common" ;; esac
main_root=$(dirname "$common")

DIR="$main_root/.claude/.plan-cycle"
PLANS="$DIR/plans"
CONFIG="$DIR/store"
rel() { printf '%s' "${1#"$main_root"/}"; }

# Sets $STORE, or exits. Deliberately NOT called in a command substitution: an
# `exit` inside `$(…)` kills only the subshell, so the caller sails on with an
# empty value — which is how the first draft of this file printed an error about
# a malformed config and then exited 0.
require_store() {
  [ -f "$CONFIG" ] || { cat >&2 <<EOF
plan-store: this project has not declared where plans live.

Write one word to $(rel "$CONFIG"):

  mkdir -p $(rel "$DIR") && echo repo   > $(rel "$CONFIG")   # plans are files here
  mkdir -p $(rel "$DIR") && echo notion > $(rel "$CONFIG")   # plans are Notion pages

Declared, not detected: which store a project uses is a fact about the project,
and no property of this machine can be read to mean it.
EOF
    exit 2; }
  STORE=$(tr -d '[:space:]' < "$CONFIG")
  case "$STORE" in
    notion|repo) ;;
    *) echo "plan-store: $(rel "$CONFIG") says \"$STORE\" — must be exactly notion or repo" >&2; exit 2 ;;
  esac
}

role_ok() {
  case "$1" in pm|designer|engineer) return 0 ;; esac
  echo "plan-store: role must be pm, designer or engineer (got \"$1\")" >&2; exit 2
}

case "${1:-}" in
  where)
    require_store
    echo "plan-store: $STORE (declared in $(rel "$CONFIG"))"
    # if/else, not a pair of `[ … ] && echo` lines: the second test is the last
    # command in the branch, so its FALSE became the script's exit status and
    # `where` reported failure on a perfectly good repo store.
    if [ "$STORE" = repo ]; then
      echo "  plans live under $(rel "$PLANS")/"
    else
      echo "  plans are Notion pages, authored through the archivist skill"
    fi
    ;;

  put)
    role="${2:-}"; slug="${3:-}"; src="${4:--}"
    [ -n "$role" ] && [ -n "$slug" ] || {
      echo "usage: plan-store put <pm|designer|engineer> <slug> [file|-]" >&2; exit 2; }
    role_ok "$role"
    require_store
    [ "$STORE" = notion ] && { cat >&2 <<EOF
plan-store: this project stores plans in NOTION, so a plan is created through
the archivist skill rather than written here. Author it, then record its address:

  plan-cycle uploaded $role <plan-row-url>
EOF
      exit 2; }
    mkdir -p "$PLANS" || exit 2
    dest="$PLANS/${slug}.${role}.md"
    tmp="$dest.partial"
    if [ "$src" = "-" ]; then cat > "$tmp"; else cp "$src" "$tmp" || exit 2; fi
    # An empty plan is not a plan. Written via a sibling and moved, so a failed
    # or empty write never replaces a good plan that was already there.
    [ -s "$tmp" ] || { rm -f "$tmp"; echo "plan-store: refusing to store an EMPTY $role plan for \"$slug\"" >&2; exit 2; }
    mv -f "$tmp" "$dest"
    echo "plan-store: $(rel "$dest") — $(grep -c '' "$dest") lines, repo store"
    printf '%s\n' "$dest"
    ;;

  get)
    role="${2:-}"; slug="${3:-}"
    [ -n "$role" ] && [ -n "$slug" ] || { echo "usage: plan-store get <role> <slug>" >&2; exit 2; }
    role_ok "$role"; require_store
    f="$PLANS/${slug}.${role}.md"
    [ -f "$f" ] || { echo "plan-store: no $role plan for \"$slug\" at $(rel "$f")" >&2; exit 1; }
    cat "$f"
    ;;

  list)
    require_store
    found=$(find "$PLANS" -name '*.md' -type f 2>/dev/null | sort)
    [ -n "$found" ] || { echo "plan-store: no plans yet under $(rel "$PLANS")/"; exit 0; }
    printf '%s\n' "$found" | while IFS= read -r f; do
      b=$(basename "$f" .md)
      printf '  %-28s %-9s %4s lines  %s\n' "${b%.*}" "${b##*.}" "$(grep -c '' "$f")" "$(rel "$f")"
    done
    ;;

  *)
    cat >&2 <<'EOF'
plan-store — where a plan lives. The plan's FORMAT stays with notion-payload
(hints / template / sections / criteria); only its destination is decided here.

  plan-store where                        which store this project declared
  plan-store put <role> <slug> [file|-]   write a plan (repo store)
  plan-store get <role> <slug>            print one
  plan-store list                         list them

  role is pm | designer | engineer.

  The store is declared in .claude/.plan-cycle/store — one word, `notion` or
  `repo`. It is never inferred from the machine.
EOF
    exit 2 ;;
esac
