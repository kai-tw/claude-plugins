#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh prints `<id>-<what>=…` for the project config reference, every file the plugin
# ships outside evals/, SKILL.md and agents/builder.md.
set -euo pipefail
cat > check.sh <<'SH'
root=$1
n() { tr -s ' \n' ' ' < "$1"; }
hits() { h=0
  for p in "$@"; do
    while read -r f; do [ -n "$f" ] && { echo "$tag-hit: $p in ${f#"$root"/}"; h=$((h + 1)); }
    done <<<"$(find "$root" -mindepth 1 -maxdepth 1 ! -name evals -exec grep -rlE -- "$p" {} + 2>/dev/null)"
  done; }
# S24: the fields in the reference's config block, sorted; a removed field (as a config line
# or in backticks) in any file the plugin ships outside evals/.
echo "s24-fields=$(sed -n '/^```/,/^```/p' "$root/skills/assistant/references/project.md" | grep -oE '^[a-z_]+:' | tr -d : | sort | paste -sd ' ' -)"
tag=s24; hits '(^|`)coverage:' '(^|`)render:'; echo "s24-hits=$h"
# S25: no intake command or script; SKILL.md names a task source it can't read, with the reason.
tag=s25; hits 'asst-intake' 'intake\.sh'; echo "s25-hits=$h"
[ -e "$root/bin/asst-intake" ]; echo "s25-bin=$?"
s=$(n "$root/skills/assistant/SKILL.md")
tk=$(n "$root/skills/assistant/references/tracker.md")
vf=$(n "$root/skills/assistant/references/verify.md")
echo "s25-unreadable=$(grep -ciE '(source|sources)[^.]{0,120}(can.t|cannot|not) be read[^.]{0,160}reason|reason[^.]{0,120}(source|sources)[^.]{0,80}(can.t|cannot|not) be read' <<<"$tk")"
echo "s25-claude-md=$(grep -ciE 'task sources[^.]{0,200}CLAUDE\.md|CLAUDE\.md[^.]{0,200}task sources' <<<"$tk")"
# S26: SKILL.md — no fixed module list, the model finds the commands;
# with no screenshot command the builder says so and the assistant asks once.
echo "s26-modules=$(grep -ciE 'frontend[^.]{0,20}backend[^.]{0,20}product|five modules' <<<"$s")"
echo "s26-coverage=$(grep -ciE 'find[^.]{0,60}coverage[^.]{0,60}command|coverage command[^.]{0,100}(find|CLAUDE\.md|CI config)' <<<"$vf")"
echo "s26-render=$(grep -ciE 'find[^.]{0,60}(screenshot|render)[^.]{0,60}command|(screenshot|render) command[^.]{0,100}(find|CLAUDE\.md|CI config)' <<<"$s")"
echo "s26-nosshot-ask=$(grep -ciE 'screenshot command.{0,200}(none|no such|without one|lacks one).{0,80}ask.{0,40}once|(no|without|lacks) (a )?(screenshot|render) command.{0,120}ask.{0,40}once' <<<"$s")"
b=$(n "$root/agents/builder.md")
echo "s26-nosshot-builder=$(grep -ciE 'screenshot command.{0,250}(with none|none found|there is none|no such|finds none).{0,160}(open questions|say so|says so|report|tell|name)|(no|without|lacks) (a )?(screenshot|render) command.{0,160}(open questions|say so|says so|report|tell|name)' <<<"$b")"
SH
