#!/usr/bin/env bash
# palimpsest.sh — PreToolUse(Bash): block a force-push or a delete aimed at a
# protected branch.
#
# A palimpsest is a manuscript scraped clean and written over, the old text
# left only as a ghost underneath. Force-pushing `main` does that to history
# everyone else has built on. Force-pushing an ordinary branch is still allowed
# — a generated branch that's rebuilt on every run needs it.
#
# WHY A HOOK AND NOT A `permissions` PATTERN
#   A permission pattern matches the command STRING, and the destination often
#   isn't in it: on `main`, a bare `git push --force` rewrites `main` without
#   "main" appearing anywhere, because push.default sends the CURRENT branch.
#   Seen on 2026-09-02 — the remote moved and the command never said so.
#   Deciding this needs the repo's state, which a pattern can't read.
#
# WHAT IT DOESN'T SEE
#   Only the command itself. A script it calls can push without passing
#   through here — the same limit as `charon.sh`, for the same reason: it
#   catches the reflex of typing the command; it isn't a complete block on
#   remote writes. Claiming otherwise would be the false confidence it exists to
#   remove.
#
# WHERE IT FAILS CLOSED
#   A force whose destination can't be worked out — a shell variable, a
#   detached HEAD, `--all`/`--mirror` — is blocked rather than guessed at.
#   Naming the branch costs one word; a rewritten `main` can't be recovered
#   from here.

set -uo pipefail

payload="$(cat 2>/dev/null)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0
# No `push` in it: no command this hook acts on can be there.
case "$cmd" in *push*) ;; *) exit 0 ;; esac

cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -n "$cwd" ] || cwd="$PWD"

PROTECTED='^(main|master)$'

# exit 2, not a JSON `permissionDecision: "deny"`: only exit 2 is documented to
# override a `permissions.allow` rule, and both consumer projects have an allow
# rule that covers the commands this hook checks. The reason goes to stderr,
# which is what Claude sees. Every message opens with what the name means, since
# any one of them can be the first the reader sees.
deny() {
  printf '%s\n\n%s\n' "🛡️ palimpsest — a palimpsest is a page scraped clean and written over; force-pushing \`main\` or \`master\` does that to the history everyone else has built on." "$1" >&2
  exit 2
}

# Every simple command is examined, so a push after a newline, && or ; is too;
# a `cd` before it moves the repo it acts on.
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=command-words.sh
source "$here/command-words.sh"
CMD_DIR=$cwd
while read_command; do
  # Not a push: nothing here can overwrite a branch.
  git_command "$CMD_DIR" && [ "$GIT_SUB" = push ] || continue
  repo=$GIT_AT
  set -- ${GIT_ARGS[@]+"${GIT_ARGS[@]}"}

  force=""; targets=(); deleting=""; wildcard=""; dry=""
  for tok in "$@"; do
    case "$tok" in
      --dry-run|-n)                                       dry=1 ;;
      --force|--force-with-lease|--force-with-lease=*|-f) force=1 ;;
      -[!-]*f*)                                           force=1 ;;
      --delete|-d)                                        deleting=1 ;;
      --all)                                              wildcard=1 ;;
      --mirror)                                           wildcard=1; force=1 ;;
      -*)                                                 ;;
      *)  targets+=("$tok") ;;
    esac
  done
  # A leading + on a refspec is itself a force, with no flag in the command.
  for tok in "${targets[@]:-}"; do case "$tok" in +*) force=1 ;; esac; done
  [ -n "$dry" ] && continue   # writes nothing; denying it would be a false positive
  [ -z "$force$deleting" ] && continue

  # The first bare token is the remote; the rest are refspecs. A refspec's
  # destination is what follows the colon, and a leading + is itself a force.
  refs=(); [ ${#targets[@]} -gt 1 ] && refs=("${targets[@]:1}")

  if [ "$wildcard" = 1 ] && [ -n "$force" ]; then
    deny "\`--all\` / \`--mirror\` would overwrite \`main\` too, so it's blocked. Name the branch you mean to push."
  fi

  if [ ${#refs[@]} -eq 0 ]; then
    # No refspec: git sends the CURRENT branch. This is the case a permission
    # pattern is blind to.
    cur=""
    [ -z "$repo" ] || cur="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    if [ -z "$cur" ]; then
      deny "This push has no refspec and the current branch can't be read here (not a git repo, a detached HEAD, or a directory held in a variable), so there's no telling whether it hits \`main\`. Name the branch: \`git push --force origin <branch>\`."
    fi
    printf '%s' "$cur" | grep -qE "$PROTECTED" && deny \
"This would force-push over \`$cur\`.

\`$cur\` isn't anywhere in the command: with no refspec, git pushes the **current branch**, and you're on it. Force-pushing another branch is fine; force-pushing \`$cur\` is not."
    continue
  fi

  for ref in "${refs[@]}"; do
    plus=""; case "$ref" in +*) plus=1; ref="${ref#+}" ;; esac
    dst="${ref##*:}"
    case "$dst" in *'$'*|*'`'*)
      [ -n "$force$plus" ] && deny \
"This push forces, but its target \`$dst\` is a variable that can't be expanded here, so there's no telling whether it's \`main\`.

Write the branch name out and run it again. Letting a push through unchecked would defeat the point of this hook." ;;
    esac
    printf '%s' "$dst" | grep -qE "$PROTECTED" || continue
    [ -n "$deleting" ] && deny "This would **delete** \`$dst\` on the remote. Deleting a feature branch is fine; deleting \`$dst\` is not."
    deny "This would force-push over \`$dst\`. Force-pushing another branch is fine; force-pushing \`$dst\` is not."
  done
done < <(command_words "$cmd")

exit 0
