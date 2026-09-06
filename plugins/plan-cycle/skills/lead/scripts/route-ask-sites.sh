#!/usr/bin/env bash
# Point every ask-site at the routing rule instead of naming the tool.
#
# The tool name IS the bug: `AskUserQuestion` is correct solo and wrong under a
# lead, and 36 sites saying it unconditionally contradict the routing table at
# the top of the same file. Replacing only the tool reference keeps every site's
# substance — as many questions as it takes, recommended option first, never
# guess a default — and changes only WHO the question reaches.
#
# Not a top-of-file sentence saying "read all of these differently": this repo
# already knows prose in the middle of a long file decays. The pointer goes at
# the site.
set -uo pipefail
P=/Users/kai/GitHub/claude-plugins/plugins/plan-cycle/skills
R='`ask`(§Working in a team)'

for role in pm designer engineer qa plan; do
  f="$P/$role/SKILL.md"
  [ -f "$f" ] || { echo "  $role: no SKILL.md, skipped"; continue; }
  before=$(grep -c 'AskUserQuestion' "$f")

  # Everything INSIDE the generated team block must keep the real tool name —
  # that block is where the routing rule is defined, and rewriting its own
  # reference would make the definition circular.
  awk -v r="$R" '
    /team-block:begin/ { inblk=1 }
    /team-block:end/   { inblk=0 }
    {
      if (!inblk) {
        gsub(/via `AskUserQuestion`/,        "via " r)
        gsub(/use `AskUserQuestion`/,        "use " r)
        gsub(/`AskUserQuestion` the moment/, r " the moment")
        gsub(/an `AskUserQuestion`/,         "an " r)
        gsub(/one `AskUserQuestion` pass/,   "one " r " pass")
        gsub(/no `AskUserQuestion` gate/,    "no " r " gate")
        gsub(/Ask the user directly via `AskUserQuestion`/, "Ask via " r)
      }
      print
    }' "$f" > "$f.new" && mv "$f.new" "$f"

  after=$(grep -c 'AskUserQuestion' "$f")
  inblock=$(awk '/team-block:begin/{i=1} /team-block:end/{i=0} i&&/AskUserQuestion/{n++} END{print n+0}' "$f")
  printf '  %-11s AskUserQuestion %2s -> %2s  (%s of those are inside the block, which is correct)  routed:%s\n' \
    "$role" "$before" "$after" "$inblock" "$(grep -c 'Working in a team)' "$f")"
done
# Second pass: the sites where the tool name landed at the start of a wrapped
# line, so the first pass's "via `AskUserQuestion`" patterns did not span it.
#
# Two mentions are deliberately LEFT: the `allowed-tools:` entries in qa and
# plan frontmatter. Those declare the tool is available, which it must be —
# routing changes who is asked, not whether the solo path can still ask.
set -uo pipefail
P=/Users/kai/GitHub/claude-plugins/plugins/plan-cycle/skills
R='`ask`(§Working in a team)'

for role in pm designer engineer plan; do
  f="$P/$role/SKILL.md"
  before=$(grep -c 'AskUserQuestion' "$f")
  awk -v r="$R" '
    /^---$/ { fm++ }
    /team-block:begin/ { inblk=1 }
    /team-block:end/   { inblk=0 }
    { if (fm >= 2 && !inblk) gsub(/`AskUserQuestion`/, r); print }
  ' "$f" > "$f.new" && mv "$f.new" "$f"
  outside=$(awk '/^---$/{fm++} /team-block:begin/{i=1} /team-block:end/{i=0} fm>=2&&!i&&/AskUserQuestion/{n++} END{print n+0}' "$f")
  printf '  %-9s %2s -> %2s total, %s outside the block (want 0)\n' "$role" "$before" "$(grep -c 'AskUserQuestion' "$f")" "$outside"
done

echo
echo "  frontmatter declarations kept (correct — the solo path still needs the tool):"
grep -n '^  - AskUserQuestion' "$P"/qa/SKILL.md "$P"/plan/SKILL.md | sed 's|.*/skills/|    |'
# Third pass: read the result and fix the English.
#
# The mechanical replace produced "ask via `ask`(…)" and "put it to the user via
# `ask`(…)" — the tool swap left the surrounding verb, and "the user" is the very
# assumption being removed. Correct instruction, unreadable sentence; an agent
# parsing "ask via ask" has to guess what the second one means.
set -uo pipefail
P=/Users/kai/GitHub/claude-plugins/plugins/plan-cycle/skills
A='`ask`(§Working in a team)'

for role in pm designer engineer qa; do
  f="$P/$role/SKILL.md"
  before=$(grep -c 'via `ask`' "$f")
  awk -v a="$A" '
    /team-block:begin/ { inblk=1 }
    /team-block:end/   { inblk=0 }
    {
      if (!inblk) {
        gsub(/Ask the user directly via `ask`\(§Working in a team\)/, a)
        gsub(/put each to the user via `ask`\(§Working in a team\)/,  a " each")
        gsub(/put it to the user via `ask`\(§Working in a team\)/,    a " it")
        gsub(/it to the user via `ask`\(§Working in a team\)/,        a " it")
        gsub(/stop and ask via `ask`\(§Working in a team\)/,          "stop and " a)
        gsub(/and ask via `ask`\(§Working in a team\)/,               "and " a)
        gsub(/ask via `ask`\(§Working in a team\)/,                   a)
      }
      print
    }' "$f" > "$f.new" && mv "$f.new" "$f"
  printf '  %-9s "via `ask`" %s -> %s\n' "$role" "$before" "$(grep -c 'via `ask`' "$f")"
done

echo
echo "  remaining forms:"
grep -ho '[A-Za-z ]*`ask`(§Working in a team)[ a-z]*' "$P"/{pm,designer,engineer,qa}/SKILL.md \
  | sed 's/^ *//' | sort | uniq -c | sort -rn | head
