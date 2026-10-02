#!/usr/bin/env bash
# asst-cloud — open a new cloud session with a profile's model, effort and
# preamble, from a local shell or from inside a cloud session.
#
# Usage: asst-cloud open [--profile <name>] [--model <m>] [--effort <e>] [--permission-mode <p>]
#                        [--env <name|id>] [--check-every <minutes>|none] [--name <title>] [--dry-run] <task…|->
#          open a cloud session on the pushed branch → prints its session id, URL, title and environment;
#          `-` reads the task from stdin; --dry-run prints the command and the text
#          The title is --name if given, else `PR# <n> <PR title>` for the branch's PR, else `<repo> · <branch>`.
#          No --env = the account's default environment.
#        asst-cloud profiles
#          list the profiles and what each sets
#        asst-cloud envs
#          list the account's cloud environments, as the last `open` saw them
# A profile is `cloud-profiles/<name>.md`: frontmatter model / effort /
# permission_mode / environment / check_every,
# body prepended to the task. The project's `.claude/assistant/cloud-profiles/`
# wins over the plugin's. Flags win over the profile; no --profile = `default`.
# Exit: 0 opened · 1 refused or failed (the reason on stderr; a session opened in
# another environment than --env asked for is a failure, its id still printed) · 2 usage.
#
# `claude --cloud` refuses --print and wants a TTY, which the Bash tool is not;
# `script` gives it one. The session clones the pushed branch, not this checkout,
# so an unpushed HEAD is refused rather than dispatched against stale code.
# `claude` has no command that lists environments, and its --environment takes
# only self-hosted `ccpool_…` ids; but `--cloud` reads remote.defaultEnvironmentId
# from settings, and its debug log names every environment and the one it picked
# — falling back to another, with no message, when the id is unknown. So --env
# goes in as --settings, the list is saved from the log, and the pick is checked.
set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/root.sh"
usage() { sed -n '5,20p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "asst-cloud: $1" >&2; exit 1; }

profile_file() {
  local p
  for p in "$(asst_root)/.claude/assistant/cloud-profiles/$1.md" "$here/../cloud-profiles/$1.md"; do
    [ -f "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}
front() { awk -v k="$1" 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&$0~"^"k":"{sub("^"k":[[:space:]]*","");print;exit}' "$2"; }
# One line `as of <time>`, then `<id>\t<name>\t<kind>` per environment.
envs_file="${XDG_CACHE_HOME:-$HOME/.cache}/asst-cloud/environments"
env_label() { local n; n=$(awk -F'\t' -v i="$1" 'NR>1&&$1==i{print $2;exit}' "$envs_file" 2>/dev/null); echo "${n:+$n (}$1${n:+)}"; }
body() { awk 'NR==1&&/^---$/{f=1;next} f==1&&/^---$/{f=2;next} f!=1' "$1"; }

case "${1:-}" in
  profiles)
    for d in "$(asst_root)/.claude/assistant/cloud-profiles" "$here/../cloud-profiles"; do
      for f in "$d"/*.md; do [ -f "$f" ] && basename "$f" .md; done
    done | awk '!seen[$0]++' | while IFS= read -r n; do
      f=$(profile_file "$n")
      printf '%-18s model %-7s effort %-7s permissions %-12s environment %-12s check every %s\n' "$n" "$(front model "$f")" "$(front effort "$f")" "$(p=$(front permission_mode "$f"); echo "${p:-default}")" "$(e=$(front environment "$f"); echo "${e:-default}")" "$(front check_every "$f")"
    done
    exit 0 ;;
  envs)
    [ -s "$envs_file" ] || die "no environment list yet — every \`asst-cloud open\` saves the one claude fetched"
    awk -F'\t' 'NR==1{print;next}{printf "%-18s %-30s %s\n",$2,$1,$3}' "$envs_file"
    exit 0 ;;
  open) shift ;;
  *) usage ;;
esac

profile=default model="" effort="" perm="" env="" every="" name="" dry=""
while [ $# -gt 0 ]; do
  case "$1" in
    --profile)     profile=${2:?--profile needs a name}; shift 2 ;;
    --model)       model=${2:?--model needs a model}; shift 2 ;;
    --effort)      effort=${2:?--effort needs a level}; shift 2 ;;
    --permission-mode) perm=${2:?--permission-mode needs a mode}; shift 2 ;;
    --env)         env=${2:?--env needs a name or id}; shift 2 ;;
    --check-every) every=${2:?--check-every needs minutes or none}; shift 2 ;;
    --name)        name=${2:?--name needs a title}; shift 2 ;;
    --dry-run)     dry=1; shift ;;
    --)            shift; break ;;
    -)             break ;;
    -*)            usage ;;
    *)             break ;;
  esac
done
[ $# -gt 0 ] || usage
if [ "$*" = - ]; then task=$(cat); else task="$*"; fi
[ -n "$task" ] || usage

pf=$(profile_file "$profile") || die "no profile \`$profile\` — \`asst-cloud profiles\` lists them"
model=${model:-$(front model "$pf")}
effort=${effort:-$(front effort "$pf")}
perm=${perm:-$(front permission_mode "$pf")}
env=${env:-$(front environment "$pf")}
every=${every:-$(front check_every "$pf")}
case "$effort" in low|medium|high|xhigh|max) ;; *) die "effort \`$effort\` is not one of low medium high xhigh max" ;; esac
# At most 60: ScheduleWakeup clamps to 3600 s, and an idle cloud session was
# measured alive at one hour, not beyond.
case "$every" in none|'') every=none ;; *[!0-9]*|0) die "--check-every takes whole minutes or none, not \`$every\`" ;; esac
[ "$every" = none ] || [ "$every" -le 60 ] || die "--check-every is at most 60 minutes, not $every"
env_id=""
case "$env" in
  '') ;;
  env_*|ccpool_*) env_id=$env ;;
  *) env_id=$(awk -F'\t' -v n="$env" 'NR>1&&tolower($2)==tolower(n){print $1;exit}' "$envs_file" 2>/dev/null)
     [ -n "$env_id" ] || die "no environment named \`$env\` — \`asst-cloud envs\` lists them, or pass its env_… id" ;;
esac
case "$env_id" in *[!A-Za-z0-9_]*) die "\`$env_id\` is not an environment id" ;; esac

text=$(body "$pf")
[ "$every" = none ] || text+="

Long Bash work: while a command you started with \`run_in_background: true\` is still running, never end a turn without a wakeup scheduled — call ScheduleWakeup with delaySeconds $((every * 60)) (or CronCreate, one-shot, $every minutes out), check the command when it fires, and schedule the next. An idle session loses its VM, and background commands are not restored. Once the command has exited, schedule nothing more."
text=$(printf '%s\n\n%s' "$text" "$task" | sed '/./,$!d')

if [ -z "$dry" ] && git rev-parse --git-dir >/dev/null 2>&1 && [ -n "$(git remote)" ]; then
  up=$(git rev-parse '@{u}' 2>/dev/null) || die "$(git branch --show-current) has no upstream — push it first; the session clones the pushed branch"
  [ "$(git rev-parse HEAD)" = "$up" ] || die "HEAD is not pushed — push first; the session clones the pushed branch, not this checkout"
fi

# Session lists show only the title, and the one claude picks summarizes the
# text — which, after a profile's preamble, says nothing about which PR it's for.
if [ -z "$name" ] && git rev-parse --git-dir >/dev/null 2>&1; then
  read -r num title < <(gh pr view --json number,title --jq '"\(.number) \(.title)"' 2>/dev/null)
  if [ -n "${num:-}" ]; then name="PR# $num $title"
  else name="$(basename "$(git rev-parse --show-toplevel)") · $(git branch --show-current | grep . || git rev-parse --short HEAD)"; fi
fi

cmd=(claude --cloud "$text" --model "$model" --effort "$effort")
[ -z "$perm" ] || [ "$perm" = default ] || cmd+=(--permission-mode "$perm")
[ -z "$name" ] || cmd+=(--name "$name")
[ -z "$env_id" ] || cmd+=(--settings "{\"remote\":{\"defaultEnvironmentId\":\"$env_id\"}}")
if [ -n "$dry" ]; then
  printf 'title %s\n' "$name"
  printf 'environment %s\n' "$([ -n "$env_id" ] && env_label "$env_id" || echo default)"
  printf 'profile %s · model %s · effort %s · permissions %s · check every %s\n' "$profile" "$model" "$effort" "${perm:-default}" "$every"
  printf '%s\n' "$text"
  exit 0
fi

log=$(mktemp) && dbg=$(mktemp) || exit 1
cmd+=(--debug-file "$dbg")
if script --version 2>/dev/null | grep -q util-linux; then
  script -q -e -c "$(printf '%q ' "${cmd[@]}")" "$log" </dev/null >/dev/null 2>&1
else
  script -q "$log" "${cmd[@]}" </dev/null >/dev/null 2>&1
fi
# Terminal noise: CRs, escape sequences, and the `^D` macOS `script` echoes for EOF.
out=$(tr -d '\r\004\010' <"$log" | sed $'s/\x1b\\[[0-9;?<>=]*[A-Za-z]//g; s/\x1b[()78=>][0-9A-Za-z]\\{0,1\\}//g; s/^\\^D//')
rm -f "$log"
avail=$(sed -n 's/.*Available environments: //p' "$dbg" | tail -1)
if [ -n "$avail" ]; then
  mkdir -p "$(dirname "$envs_file")" && {
    date '+as of %Y-%m-%d %H:%M'
    grep -oE '(env|ccpool)_[A-Za-z0-9]+ \([^()]*\)' <<<"$avail" | sed -E $'s/^([^ ]+) \\((.*), ([^,]*)\\)$/\\1\t\\2\t\\3/'
  } > "$envs_file.$$" && mv "$envs_file.$$" "$envs_file"
fi
picked=$(sed -n 's/.*Selected environment: \([A-Za-z0-9_]*\).*/\1/p' "$dbg" | tail -1)
rm -f "$dbg"
id=$(printf '%s\n' "$out" | grep -o 'session_[A-Za-z0-9]*' | head -1)
url=$(printf '%s\n' "$out" | grep -o 'https://claude\.ai/code/session_[^[:space:]]*' | head -1)
shown=$(printf '%s\n' "$out" | sed -n 's/^.*Created cloud session: //p' | head -1)
[ -n "$id" ] || { printf 'asst-cloud: no session was opened. claude said:\n%s\n' "$(printf '%s\n' "$out" | grep -v '^[[:space:]]*$' | tail -8)" >&2; exit 1; }
printf 'session %s\nurl %s\ntitle %s\nenvironment %s\nprofile %s · model %s · effort %s · permissions %s · check every %s\n' "$id" "${url%%\?*}" "$shown" "$([ -n "$picked" ] && env_label "$picked" || echo unknown)" "$profile" "$model" "$effort" "${perm:-default}" "$every"
[ -z "$env_id" ] || [ "$picked" = "$env_id" ] || die "asked for environment $(env_label "$env_id"), but the session opened in $([ -n "$picked" ] && env_label "$picked" || echo 'one claude did not name') — archive it if it must not run there"
