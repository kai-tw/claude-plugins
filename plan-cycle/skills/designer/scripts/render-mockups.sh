#!/usr/bin/env bash
# Design-mockup renderer — CLI facade over a project-supplied harness.
#
# Mechanical half of the design-mockup pipeline: runs the headless render
# harness (headless flutter_test — no simulator) and reports the generated PNG
# tree. The judgment half (authoring the spec fixture, choosing which
# screens/states/breakpoints to render, reviewing the output) lives in the
# designer skill.
#
# PROJECT CONTRACT — this script ships with the plugin; the harness does not.
#   A consuming project provides it at tool/design_mockups/, exposing a
#   flutter_test entry point that reads the --dart-define flags below and writes
#   PNGs to build/design-mockups/<slug>/. Its own CLAUDE.md is the full
#   contract for authoring fixtures.
#
#   Without that directory this script exits non-zero and the designer skill
#   runs every phase except mockups. That is the intended degradation: hand-drawn
#   approximations are the imitation the render phase exists to rule out.
#
# Args (slug positional, flags any order, all optional):
#   <spec-slug>              The MockupSpec to render (default: smoke). Must be
#                            registered in tool/design_mockups/run_mockups_test.dart.
#   --locales=zh-Hant,en     Language tags (default: zh-Hant). Must be in
#                            LocaleUtils.supportedLocales.
#   --themes=light,dark      Brightnesses (default: light,dark).
#   --sizes=compact,expanded WindowSize bands to narrow to (default: all the
#                            spec's screens declare).
#   --states=default,empty   States to narrow to (default: all).
#   --screens=conflicts_page Screen names to narrow to (default: all).
#   -h | --help              This help
#
# Examples:
#   .claude/skills/designer/scripts/render-mockups.sh smoke
#   .claude/skills/designer/scripts/render-mockups.sh conflict-resolution-surface
#   .claude/skills/designer/scripts/render-mockups.sh conflict-resolution-surface --locales=zh-Hant,en --sizes=compact
#
# Output: build/design-mockups/<slug>/<screen>__<size>__<state>__<brightness>__<langTag>.png

set -euo pipefail

log()  { printf '\033[1;36m▸ %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
err()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; }

slug="smoke"
locales=""
themes=""
sizes=""
states=""
screens=""

for arg in "$@"; do
  case "$arg" in
    --locales=*) locales="${arg#*=}" ;;
    --themes=*)  themes="${arg#*=}" ;;
    --sizes=*)   sizes="${arg#*=}" ;;
    --states=*)  states="${arg#*=}" ;;
    --screens=*) screens="${arg#*=}" ;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --*)
      err "Unknown flag: $arg (expected --locales/--themes/--sizes/--states/--screens or --help)"
      exit 2
      ;;
    *) slug="$arg" ;;
  esac
done

# Each knob maps to a compile-time --dart-define the harness reads; only set the
# ones the caller passed so the harness defaults (all screens/states/sizes,
# zh-Hant, light+dark) apply otherwise. DESIGN_MOCKUP=true is always on here: it
# makes production `if (DesignMockup.enabled)` guards render their design-mockup
# sketches (those guards are const-false and tree-shaken in real release builds).
define_args=(--dart-define=MOCKUP_SPEC="$slug" --dart-define=DESIGN_MOCKUP=true)
[[ -n "$locales" ]] && define_args+=(--dart-define=MOCKUP_LOCALES="$locales")
[[ -n "$themes" ]]  && define_args+=(--dart-define=MOCKUP_THEMES="$themes")
[[ -n "$sizes" ]]   && define_args+=(--dart-define=MOCKUP_SIZES="$sizes")
[[ -n "$states" ]]  && define_args+=(--dart-define=MOCKUP_STATES="$states")
[[ -n "$screens" ]] && define_args+=(--dart-define=MOCKUP_SCREENS="$screens")

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

out_dir="build/design-mockups/$slug"

log "Rendering design mockups — spec: ${slug} (headless, no simulator)"
# Clear only this spec's output so a re-render never shows stale screens that
# were removed from the fixture.
rm -rf "$out_dir"

if ! flutter test tool/design_mockups/ "${define_args[@]}"; then
  err "Mockup harness failed. See the flutter test output above."
  exit 1
fi

count="$(find "$out_dir" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')"
ok "Generated ${count} mockup(s) under ${out_dir}/"
echo
# Print the tree so the caller can surface paths without re-discovering them.
find "$out_dir" -name '*.png' | sort | sed "s|^${out_dir}/|  |"
