#!/usr/bin/env bash
# disclosure.sh — PreToolUse(Bash): block a push, a PR, an issue, a release or a
# gist that would publish what SKILL.md §Disclosure keeps out of a repo not
# known to be private.
#
# Acts on `git push`, `gh pr create|edit|ready|comment|review`, `gh issue
# create|comment`, `gh release create` and `gh gist create`, wherever they sit
# in the command; any other command exits 0 before calling gh. Scanned: the
# commits a push sends — `<base>..<ref>` for each source ref, HEAD when it names
# none, <base> being origin's default branch — and for `gh pr create|edit|ready`
# those up to HEAD (or --head); the words of a gh command and the files it reads
# (--body-file, --notes-file, a gist's files). Caught: a private or internal
# repo of this owner or of the gh user, named in full, or bare when the name
# holds `-_.` or a capital · "$HOME/" · a `#<n>` that is no issue or PR of this
# repo. A gist is scanned whatever this repo's visibility: it is not part of it.
#
# A push whose remote is definitely not on GitHub writes to no GitHub repo
# (§Disclosure) and is allowed without calling gh: the remote is picked the way
# git does, each URL it pushes to expanded by git and an ssh host by ssh's
# config (see ssh_host), and every host must be a real one (it ends in a
# top-level domain) other than github.com and its subdomains. A local path or
# file:// remote, an unparsable URL or an unresolvable remote or host is
# scanned. gh commands always target GitHub.
#
# It guards against a slip, not a workaround: a push from inside a script is
# not seen. What it cannot work out here — a directory or ref held in a
# variable, stdin, gh or the base branch unavailable — it blocks with the
# reason rather than letting through unchecked.
#
# Every git call here is local, with fsmonitor off (git below) and no diff
# driver; `ssh -G` may run a Match exec from the user's own ~/.ssh/config, which
# is accepted.
#
# Each gh or network call is cut off after $GH_TIMEOUT seconds and no `#<n>` is
# looked up after 60, so the hook ends well inside its 120-second timeout in
# hooks.json: a hook that times out lets the command run unchecked.

set -uo pipefail
# This runs before the user approves: no fsmonitor program from a repo's config.
git() { command git -c core.fsmonitor=false "$@"; }
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=command-words.sh
source "$here/command-words.sh"
# shellcheck source=../../skills/assistant/scripts/github.sh
source "$here/../../skills/assistant/scripts/github.sh"

payload="$(cat 2>/dev/null)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0
# Neither word in it: no command this hook acts on can be there.
case "$cmd" in *push*|*gh*) ;; *) exit 0 ;; esac
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -n "$cwd" ] || cwd="$PWD"

# exit 2, not a JSON deny: only exit 2 overrides a `permissions.allow` rule
# that covers the command; stderr is what Claude sees.
deny() { printf 'disclosure: NOT SENT — %s\n' "$1" >&2; exit 2; }
unread() { deny "this check could not run: $1. Nothing was sent; $2"; }

# gh flags that take a value, so the word after one is that value and never a
# flag (`--title "Handle -F flag"`). Short ones differ per subcommand, set below.
LONG=' title body body-file base head repo label assignee reviewer milestone project template notes notes-file notes-start-tag target discussion-category desc filename add-label remove-label add-assignee remove-assignee add-reviewer remove-reviewer add-project remove-project recover '

# One entry per publishing command: the directory it runs in, the refs whose
# commits it sends (one per line), the text it sends, and 1 for a gist.
a_dir=() a_refs=() a_text=() a_gist=() a_off=()

# ssh_host <host> — the host ssh connects to for <host>, as plain `ssh -G` prints
# it from the user's ssh config without connecting. Nothing when git would run
# a command set in GIT_SSH_COMMAND, GIT_SSH or core.sshCommand (here or in the
# command) in its place — this hook runs before the user approves the command,
# so it runs nothing a repo or the environment sets — or when ssh would go
# through a ProxyCommand or ProxyJump, whose last hop it cannot see.
ssh_host() {
  [ -z "${GIT_SSH_COMMAND:-}${GIT_SSH:-}" ] || return 0
  git -C "$GIT_AT" config core.sshCommand >/dev/null 2>&1 && return 0
  case "$(printf '%s' "$cmd" | tr '[:upper:]' '[:lower:]')" in *git_ssh*|*sshcommand*) return 0 ;; esac
  run_bounded "${GH_TIMEOUT:-10}" ssh -G "$1" 2>/dev/null </dev/null | awk '
    ($1 == "proxycommand" || $1 == "proxyjump") && tolower($2) != "none" { proxy = 1 }
    $1 == "hostname" { h = tolower($2) }
    END { if (!proxy) print h }'
}

# url_off <url> — succeeds only when <url> names a real host (plain characters,
# ending in a top-level domain: letters or an xn-- label) that is not github.com
# or below it. An ssh URL's host is the one ssh connects to after its config
# (`Host github.com-work` may be github.com). A local path, an IP literal or
# anything unparsable fails.
url_off() {
  local u h ssh=1
  u=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$u" in
    ssh://*|git+ssh://*|ssh+git://*) h=${u#*://}; h=${h%%/*}; h=${h##*@}; h=${h%%:*} ;;
    *://*) h=${u#*://}; h=${h%%/*}; h=${h##*@}; h=${h%%:*}; ssh= ;;
    *:*) h=${u%%:*}; h=${h##*@} ;;
    *) return 1 ;;
  esac
  if [ -n "$ssh" ]; then
    case "$h" in ''|-*|*/*) return 1 ;; esac
    h=$(ssh_host "$h")
  fi
  [[ $h =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ && $h == *.* && $h != *..* && ${h##*.} =~ ^([a-z]+|xn--[a-z0-9-]+)$ ]] || return 1
  case "$h" in github.com|*.github.com) return 1 ;; esac
  return 0
}

# push_off — prints 1 when the remote the push in GIT_ARGS targets (run in
# $GIT_AT) is definitely not on GitHub: every URL it pushes to, as git expands
# it (insteadOf and pushInsteadOf applied), passes url_off. Anything else — a
# local path, a remote that cannot be resolved — prints nothing, so the push is
# checked.
push_off() {
  local w i=0 n=${#GIT_ARGS[@]} r='' u b
  # A remote named in place wins over --repo (git-push(1)).
  while [ $i -lt $n ]; do
    w=${GIT_ARGS[$i]}; i=$((i + 1))
    case "$w" in
      --repo) r=${GIT_ARGS[$i]:-}; i=$((i + 1)) ;;
      --repo=*) r=${w#*=} ;;
      -o|--push-option|--receive-pack|--exec) i=$((i + 1)) ;;
      -*) ;;
      *) r=$w; break ;;
    esac
  done
  if [ -z "$r" ]; then
    # The remote git picks: branch pushRemote, remote.pushDefault, branch remote, origin.
    b=$(git -C "$GIT_AT" symbolic-ref --quiet --short HEAD 2>/dev/null) || b=
    if [ -n "$b" ]; then r=$(git -C "$GIT_AT" config "branch.$b.pushRemote" 2>/dev/null) || r=; fi
    if [ -z "$r" ]; then r=$(git -C "$GIT_AT" config remote.pushDefault 2>/dev/null) || r=; fi
    if [ -z "$r" ] && [ -n "$b" ]; then r=$(git -C "$GIT_AT" config "branch.$b.remote" 2>/dev/null) || r=; fi
    [ -n "$r" ] || r=origin
  fi
  case "$r" in *'$'*|*'`'*|-*) return 0 ;; esac
  u=$(git -C "$GIT_AT" ls-remote --get-url "$r" 2>/dev/null) || return 0
  url_off "$u" || return 0
  # A named remote may push elsewhere than it fetches, and to every URL it lists.
  case "$r" in
    *:*|*/*) ;;
    *)
      u=$(git -C "$GIT_AT" remote get-url --push --all "$r" 2>/dev/null) && [ -n "$u" ] || return 0
      while IFS= read -r w; do url_off "$w" || return 0; done <<<"$u" ;;
  esac
  echo 1
}

# push_refs — the source refs of the push in GIT_ARGS, one per line: HEAD with no
# refspec, `--all` / `--tags` for those flags; none for a delete.
push_refs() {
  local w pos=0 any='' del='' i=0 n=${#GIT_ARGS[@]}
  while [ $i -lt $n ]; do
    w=${GIT_ARGS[$i]}; i=$((i + 1))
    case "$w" in
      --all|--mirror|--branches) echo --all; any=1 ;;
      --tags) echo --tags ;;
      --delete|-d) del=1 ;;
      --repo|-o|--push-option|--receive-pack|--exec) i=$((i + 1)) ;;
      -*) ;;
      *)
        pos=$((pos + 1))
        # The first word is the remote; the rest are refspecs.
        [ $pos -gt 1 ] || continue
        any=1; [ -z "$del" ] || continue
        w=${w#+}; w=${w%%:*}
        [ -z "$w" ] || echo "$w" ;;
    esac
  done
  [ -n "$any$del" ] || echo HEAD
}

CMD_DIR=$cwd
while read_command; do
  dir=$CMD_DIR
  if git_command "$dir"; then
    # Any git command but push sends nothing.
    [ "$GIT_SUB" = push ] || continue
    [ -n "$GIT_AT" ] || unread "the repo this push runs in is held in a variable or \`cd -\`" "write its path out"
    refs=$(push_refs)
    case "$refs" in *'$'*|*'`'*) unread "a ref this push sends is held in a variable" "write the ref out" ;; esac
    a_dir+=("$GIT_AT") a_refs+=("$refs") a_text+=("") a_gist+=("") a_off+=("$(push_off)")
    continue
  fi
  # Neither cd, git nor gh: this command publishes nothing.
  [ "${CMD_WORDS[0]:-}" = gh ] || continue
  commits='' gist=''
  case "${CMD_WORDS[1]:-} ${CMD_WORDS[2]:-}" in
    "pr create") short=tbBHRlarmpTF commits=1 ;;
    "pr edit") short=tbBRF commits=1 ;;
    "pr ready") short=R commits=1 ;;
    "pr comment"|"pr review"|"issue comment") short=bFR ;;
    "issue create") short=tbRlampTF ;;
    "release create") short=tnRF ;;
    "gist create") short=df gist=1 ;;
    *) continue ;;  # a gh command that publishes nothing
  esac
  [ -n "$dir" ] || unread "the directory this gh command runs in is held in a variable or \`cd -\`" "write its path out"
  text='' head=HEAD files=() i=3 n=${#CMD_WORDS[@]}
  while [ $i -lt $n ]; do
    w=${CMD_WORDS[$i]}; i=$((i + 1)) name='' val=''
    case "$w" in
      --*=*) name=${w%%=*}; name=${name#--}; val=${w#*=} ;;
      --?*) case "$LONG" in *" ${w#--} "*) name=${w#--}; val=${CMD_WORDS[$i]:-}; i=$((i + 1)) ;; esac ;;
      -?*)
        c=${w:1:1}
        case "$short" in *"$c"*)
          name=$c val=${w:2}; val=${val#=}
          [ -n "$val" ] || { val=${CMD_WORDS[$i]:-}; i=$((i + 1)); } ;;
        esac ;;
      *) if [ -n "$gist" ]; then files+=("$w"); else text+=$'\n'$w; fi; continue ;;
    esac
    # A flag that takes no value.
    [ -n "$name" ] || continue
    case "$name" in
      F|body-file|notes-file) files+=("$val") ;;
      R|repo) ;;
      H|head) head=${val#*:}; text+=$'\n'$val ;;
      *) text+=$'\n'$val ;;
    esac
  done
  [ -z "$gist" ] || [ ${#files[@]} -gt 0 ] || files=(-)
  for f in ${files[@]+"${files[@]}"}; do
    [ "$f" != - ] || deny "this gh command reads its text from stdin, which cannot be checked before it is published; write the text to a file on disk and pass that file instead."
    p=$(word_dir "$dir" "$f")
    [ -n "$p" ] || unread "the file $f is held in a variable" "write its path out"
    [ -r "$p" ] || deny "$f is unreadable from $dir, so it cannot be checked before it is published."
    text+=$'\n'$(cat "$p")
  done
  refs=; [ -z "$commits" ] || refs=$head
  a_dir+=("$dir") a_refs+=("$refs") a_text+=("$text") a_gist+=("$gist") a_off+=("")
done < <(command_words "$cmd")

[ ${#a_dir[@]} -gt 0 ] || exit 0

# private_names <dir> <owner> — the private and internal repos of <owner> (when
# given) and of the gh user, one per line; fails when GitHub gives no answer.
private_names() {
  local d=$1 o=$2 v
  for v in private internal; do
    if [ -n "$o" ]; then gh_run "$d" repo list "$o" --visibility "$v" --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner' || return 1; fi
    gh_run "$d" repo list --visibility "$v" --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner' || return 1
  done 2>/dev/null | sort -u
}

# base_of <dir> — origin's default branch in <dir> as already fetched; fails
# when none is known here (it never asks the remote).
base_of() {
  local d=$1 b
  b=$(git -C "$d" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) && { echo "$b"; return 0; }
  for b in origin/main origin/master; do
    git -C "$d" rev-parse --verify --quiet "$b^{commit}" >/dev/null && { echo "$b"; return 0; }
  done
  return 1
}

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
  # This machine's home only: another home path in a diff is test data or an
  # example, and names nobody's machine.
  case "${HOME:-/}" in
    /) ;;
    *) grep -oE -- "$(sed 's/[][\.*^$+?(){}|]/\\&/g' <<<"${HOME%/}/")"'[^[:space:]`)"'"'"']*' <<<"$body" | sort -u | sed "s|^|$where: |" ;;
  esac
}
foreign_refs() {
  local where=$1 body=$2 n
  [ -n "$nwo" ] && [ -n "$body" ] || return 0
  grep -oE '(^|[^[:alnum:]_/&])#[0-9]+' <<<"$body" | grep -oE '[0-9]+' | sort -un | while read -r n; do
    if [ "$SECONDS" -ge 60 ]; then echo "$where: #$n could not be checked in time"; continue; fi
    gh_run "${d:-.}" api "repos/$nwo/issues/$n" --silent 2>/dev/null || echo "$where: #$n is no issue or PR of $nwo"
  done
}

leaks=
for k in "${!a_dir[@]}"; do
  d=${a_dir[$k]}
  # A directory that does not exist fails the command itself: nothing is sent.
  [ -d "$d" ] || continue
  # A push to a remote that is definitely not on GitHub writes to no GitHub repo.
  [ -z "${a_off[$k]}" ] || continue
  if [ -z "${a_gist[$k]}" ]; then
    vis=$(gh_visibility "$d") || unread "GitHub did not say whether this repo is private ($(gh_unusable "$d"))" "fix gh, or run it again once GitHub answers"
    # A private repo may hold anything §Disclosure keeps out of a public one.
    case "$vis" in PRIVATE|INTERNAL) continue ;; esac
  fi
  nwo=$(gh_run "$d" repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) || nwo=
  [ -n "$nwo" ] || [ -n "${a_gist[$k]}" ] || unread "GitHub did not name this repo ($(gh_unusable "$d"))" "fix gh, or run it again once GitHub answers"
  names=$(private_names "$d" "${nwo%/*}") || unread "GitHub did not list the private repos to look for ($(gh_unusable "$d"))" "fix gh, or run it again once GitHub answers"
  if [ -n "${a_refs[$k]}" ]; then
    base=$(base_of "$d") || unread "no origin default branch is known in $d to compare the commits against" "run \`git fetch origin\` there"
    while IFS= read -r r; do
      case "$r" in
        --all) list=$(git -C "$d" for-each-ref --format='%(refname)' refs/heads) ;;
        --tags) list=$(git -C "$d" for-each-ref --format='%(refname)' refs/tags) ;;
        *) list=$r ;;
      esac
      while IFS= read -r ref; do
        # A ref that names no commit fails the push itself: nothing is sent.
        git -C "$d" rev-parse --verify --quiet "$ref^{commit}" >/dev/null || continue
        msgs=$(git -C "$d" log --format=%B "$base..$ref" 2>/dev/null)
        # No diff driver or textconv: they are commands the repo sets (see ssh_host).
        added=$(git -C "$d" diff --no-ext-diff --no-textconv "$base...$ref" 2>/dev/null | grep '^+' | grep -v '^+++' | cut -c2-)
        leaks+=$(scan "commit message" "$msgs"; foreign_refs "commit message" "$msgs"; scan "diff" "$added")$'\n'
      done <<<"$list"
    done <<<"${a_refs[$k]}"
  fi
  leaks+=$(scan "PR, issue, release or gist text" "${a_text[$k]}"; foreign_refs "PR, issue, release or gist text" "${a_text[$k]}")$'\n'
done
leaks=$(grep . <<<"$leaks" | sort -u)
[ -z "$leaks" ] && exit 0
deny "this would publish, to a repo not known to be private or in a gist, what SKILL.md §Disclosure keeps out:
$leaks"
