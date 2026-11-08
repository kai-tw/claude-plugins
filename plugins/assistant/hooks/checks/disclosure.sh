#!/usr/bin/env bash
# disclosure.sh — PreToolUse(Bash): block a push, a PR or an issue that would
# publish, on a repo not known to be private, what SKILL.md §Disclosure keeps out.
#
# Acts on `git push`, `gh pr create|edit|ready|comment` and `gh issue
# create|comment` only; any other command exits 0 before calling gh. Scanned:
# the commits since origin/<default branch> (their messages and added lines) for
# a push and for `gh pr create|edit|ready`, and the --title / --body /
# --body-file text of a gh command. Caught: a private or internal repo of this
# owner or of the gh user, named in full, or bare when the name holds `-_.` or a
# capital · a home-directory path · a `#<n>` that is no issue or PR of this repo
# (another repo's, written bare). A private identifier that names no repo is not
# caught; neither is a push made from inside a script this command runs.

set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../skills/assistant/scripts/github.sh
source "$here/../../skills/assistant/scripts/github.sh"

payload="$(cat 2>/dev/null)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -n "$cwd" ] || cwd="$PWD"

# Command position: the start, or after ; & | ( — which keeps a commit message
# that mentions `git push` out.
POS='(^|[;&|(]|&&|\|\|)[[:space:]]*'
TOK='("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]+)'
push_re="${POS}git([[:space:]]+-C[[:space:]]+${TOK})*[[:space:]]+push([[:space:]]|$)"
gh_re="${POS}gh[[:space:]]+(pr[[:space:]]+(create|edit|ready|comment)|issue[[:space:]]+(create|comment))([[:space:]]|$)"
unquote() { local s=$1; s=${s#[\"\']}; s=${s%[\"\']}; printf '%s' "$s"; }

dir=$cwd commits=0 text=
if [[ $cmd =~ $push_re ]]; then
  commits=1
  if [[ ${BASH_REMATCH[0]} =~ -C[[:space:]]+$TOK ]]; then
    c=$(unquote "${BASH_REMATCH[1]}"); case "$c" in /*) dir=$c ;; *) dir=$cwd/$c ;; esac
  fi
elif [[ $cmd =~ $gh_re ]]; then
  m=${BASH_REMATCH[0]}
  case "${BASH_REMATCH[3]}" in create|edit|ready) commits=1 ;; esac
  # Only what follows the subcommand is published: a `cd` in front of it is not.
  rest=${cmd#*"$m"}
  while read -r f; do
    [ -n "$f" ] || continue
    f=$(unquote "$(sed -E 's/^(--body-file|-F)[= ]+//' <<<"$f")")
    [ "$f" = - ] && continue
    case "$f" in /*) ;; *) f=$cwd/$f ;; esac
    if [ -r "$f" ]; then text+=$'\n'$(cat "$f")
    else printf 'disclosure: NOT SENT — %s is unreadable here, so it cannot be checked before it is published\n' "$f" >&2; exit 2
    fi
  done < <(grep -oE -- "(--body-file|-F)[= ]+$TOK" <<<"$rest")
  text+=$'\n'$(sed -E "s/(--body-file|-F|--repo|-R)[= ]+$TOK//g" <<<"$rest")
else
  exit 0
fi

# A `-C` directory that does not exist fails the push itself: nothing is sent.
[ -d "$dir" ] || exit 0
gh_private "$dir" && exit 0

base=
if [ "$commits" = 1 ]; then
  base=$(git -C "$dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  for b in origin/main origin/master; do
    [ -n "$base" ] && break
    git -C "$dir" rev-parse --verify --quiet "$b" >/dev/null && base=$b
  done
fi

nwo=$(cd "$dir" && gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
names=
if [ -n "$nwo" ]; then
  names=$(for v in private internal; do
    gh repo list "${nwo%/*}" --visibility "$v" --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner'
    gh repo list --visibility "$v" --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner'
  done 2>/dev/null | sort -u)
fi

scan() {
  local where=$1 body=$2 r
  [ -n "$body" ] || return 0
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    if grep -qiF -- "$r" <<<"$body"; then echo "$where: $r"
    # Bare only when the name cannot be a plain word: a repo called `images`
    # would refuse every diff that says images.
    elif [[ ${r#*/} =~ [-_.A-Z] ]] && grep -qwF -- "${r#*/}" <<<"$body"; then echo "$where: ${r#*/}"
    fi
  done <<<"$names"
  { grep -oE '(/Users|/home)/[^/[:space:]]+/[^[:space:]`)"'"'"']*' <<<"$body"
    # A home outside /Users and /home (a container's /root) is still a home.
    case "${HOME:-}" in /Users/*|/home/*|"") ;;
      *) grep -oF -- "$HOME/" <<<"$body" ;;
    esac
  } | sort -u | sed "s|^|$where: |"
}
refs() {
  local where=$1 body=$2 n
  [ -n "$nwo" ] && [ -n "$body" ] || return 0
  grep -oE '(^|[^[:alnum:]_/&])#[0-9]+' <<<"$body" | grep -oE '[0-9]+' | sort -un | while read -r n; do
    gh api "repos/$nwo/issues/$n" --silent 2>/dev/null || echo "$where: #$n is no issue or PR of $nwo"
  done
}

leaks=$(
  if [ -n "$base" ]; then
    msgs=$(git -C "$dir" log --format=%B "$base..HEAD" 2>/dev/null)
    added=$(git -C "$dir" diff "$base...HEAD" 2>/dev/null | grep '^+' | grep -v '^+++' | cut -c2-)
    scan "commit message" "$msgs"; refs "commit message" "$msgs"
    scan "diff" "$added"
  fi
  scan "PR or issue text" "$text"; refs "PR or issue text" "$text"
)
[ -z "$leaks" ] && exit 0
# exit 2, not a JSON deny: only exit 2 overrides a `permissions.allow` rule
# that covers the command; stderr is what Claude sees.
printf 'disclosure: NOT SENT — this repo is not known to be private, and this would publish (SKILL.md §Disclosure):\n%s\n' "$leaks" >&2
exit 2
