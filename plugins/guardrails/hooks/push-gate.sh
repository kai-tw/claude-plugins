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
mapfile -t segs < <(printf '%s' "$cmd" | sed 's/&&/\n/g; s/||/\n/g; s/[;|]/\n/g')

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
    deny "🛡️ guardrails — \`--all\` / \`--mirror\` 會連 \`main\` 一起改寫，這裡擋下來。要推哪一條就寫哪一條。"
  fi

  if [ ${#refs[@]} -eq 0 ]; then
    # No refspec: git sends the CURRENT branch. This is the case a permission
    # pattern is blind to.
    cur="$(git -C "${repo:-$cwd}" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    if [ -z "$cur" ]; then
      deny "🛡️ guardrails — 這條 push 沒寫 refspec，而這裡讀不出目前的分支（不是 git repo，或 detached HEAD），所以無法判斷它會不會打到 \`main\`。把分支寫出來：\`git push --force origin <branch>\`。"
    fi
    printf '%s' "$cur" | grep -qE "$PROTECTED" && deny \
"🛡️ guardrails — 這條指令會 force 到 \`$cur\`。

它的指令字串裡沒有 \`$cur\` 這個字：沒寫 refspec 時 git 推的是**目前所在的分支**，而你現在就在上面。對分支 force 沒問題，對 \`main\` 不行。"
    continue
  fi

  for ref in "${refs[@]}"; do
    plus=""; case "$ref" in +*) plus=1; ref="${ref#+}" ;; esac
    dst="${ref##*:}"
    case "$dst" in *'$'*|*'`'*)
      [ -n "$force$plus" ] && deny \
"🛡️ guardrails — 這條 push 帶 force，但目標 \`$dst\` 是變數，這裡展不開，所以判不出它是不是 \`main\`。

寫成字面的分支名再跑。判不出來時放行，等於這個閘門不存在。" ;;
    esac
    printf '%s' "$dst" | grep -qE "$PROTECTED" || continue
    [ -n "$deleting" ] && deny "🛡️ guardrails — 這條指令會**刪掉** remote 的 \`$dst\`。刪 feature 分支沒問題，\`main\` 不行。"
    deny "🛡️ guardrails — 這條指令會 force 到 \`$dst\`。對分支 force 沒問題，對 \`main\` 不行。"
  done
done

exit 0
