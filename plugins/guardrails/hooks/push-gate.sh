#!/usr/bin/env bash
# push-gate.sh — PreToolUse(Bash): refuse a force-push or a delete aimed at a
# protected branch. Force onto an ordinary branch stays allowed — a generated
# branch that is rebuilt every run needs it.
#
# WHY A HOOK AND NOT A `permissions` PATTERN
#   A permission pattern matches the command STRING, and the destination is
#   frequently not in it: on `main`, a bare `git push --force` rewrites `main`
#   while containing no "main" anywhere, because push.default sends the CURRENT
#   branch. Measured 2026-09-02 — the remote moved, the command said nothing.
#   Deciding this needs the repo's state, which a pattern cannot read.
#
# WHAT IT DOES NOT SEE
#   Only the command itself. A script invoked from it pushes without passing
#   through here — same limit as `deletion-gate.sh`, and for the same reason:
#   this catches the reflex of typing the command, it is not a firewall on
#   remote writes. Claiming otherwise would be the false confidence it exists
#   to remove.
#
# WHERE IT FAILS CLOSED
#   A force whose destination cannot be resolved — a shell variable, a detached
#   HEAD, `--all`/`--mirror` — is denied rather than guessed at. Naming the
#   branch is one word; a rewritten `main` is not recoverable from here.

set -uo pipefail
[ "${GUARDRAILS:-on}" = "off" ] && exit 0

payload="$(cat 2>/dev/null)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0
printf '%s' "$cmd" | grep -qE '(^|[[:space:]])git([[:space:]]|$)' || exit 0

cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -n "$cwd" ] || cwd="$PWD"

PROTECTED='^(main|master)$'

# exit 2, not a JSON `permissionDecision: "deny"`: only exit 2 is documented to
# take precedence over a `permissions.allow` rule, and both consumer projects
# carry an allow that covers the commands this gate judges. The reason goes to
# stderr, which is what Claude is shown.
deny() { printf '%s\n' "$1" >&2; exit 2; }

# One statement per line, so a push buried after && or ; is still examined.
# Written for bash 3.2 (macOS's /bin/bash): no `mapfile`, and awk rather than
# sed, whose BSD build writes a literal `n` for `\n` in a replacement.
segs=()
while IFS= read -r line; do segs+=("$line"); done < <(printf '%s\n' "$cmd" | awk '{ gsub(/&&|\|\||[;|]/, "\n"); print }')

for seg in "${segs[@]}"; do
  printf '%s' "$seg" | grep -qE '^[[:space:]]*(sudo[[:space:]]+)?git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+push([[:space:]]|$)' || continue

  # shellcheck disable=SC2086 # deliberate: re-split the segment into tokens
  set -- $seg
  repo=""
  while [ "${1:-}" != "push" ] && [ $# -gt 0 ]; do
    [ "${1:-}" = "-C" ] && repo="${2:-}"
    shift
  done
  shift 2>/dev/null || true

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
  [ -n "$dry" ] && continue   # writes nothing; denying it would fire on a healthy command
  [ -z "$force$deleting" ] && continue

  # The first bare token is the remote; the rest are refspecs. A refspec's
  # destination is what follows the colon, and a leading + is itself a force.
  refs=(); [ ${#targets[@]} -gt 1 ] && refs=("${targets[@]:1}")

  if [ "$wildcard" = 1 ] && [ -n "$force" ]; then
    deny "🛡️ guardrails — \`--all\` / \`--mirror\` rewrites \`main\` too, so it is blocked here. Name the branch you mean to push."
  fi

  if [ ${#refs[@]} -eq 0 ]; then
    # No refspec: git sends the CURRENT branch. This is the case a permission
    # pattern is blind to.
    cur="$(git -C "${repo:-$cwd}" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    if [ -z "$cur" ]; then
      deny "🛡️ guardrails — this push has no refspec and the current branch cannot be read here (not a git repo, or detached HEAD), so whether it hits \`main\` cannot be judged. Name the branch: \`git push --force origin <branch>\`."
    fi
    printf '%s' "$cur" | grep -qE "$PROTECTED" && deny \
"🛡️ guardrails — this command would force onto \`$cur\`.

\`$cur\` appears nowhere in the command string: with no refspec, git pushes the **current branch**, and you are on it. Forcing a branch is fine; forcing \`main\` is not."
    continue
  fi

  for ref in "${refs[@]}"; do
    plus=""; case "$ref" in +*) plus=1; ref="${ref#+}" ;; esac
    dst="${ref##*:}"
    case "$dst" in *'$'*|*'`'*)
      [ -n "$force$plus" ] && deny \
"🛡️ guardrails — this push forces, but its target \`$dst\` is a variable that cannot be expanded here, so whether it is \`main\` cannot be judged.

Write the branch name literally and run it again. Letting an unjudgeable push through would make this gate pointless." ;;
    esac
    printf '%s' "$dst" | grep -qE "$PROTECTED" || continue
    [ -n "$deleting" ] && deny "🛡️ guardrails — this command would **delete** \`$dst\` on the remote. Deleting a feature branch is fine; \`main\` is not."
    deny "🛡️ guardrails — this command would force onto \`$dst\`. Forcing a branch is fine; forcing \`main\` is not."
  done
done

exit 0
