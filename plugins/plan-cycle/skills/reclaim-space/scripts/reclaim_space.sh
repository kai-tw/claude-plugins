#!/usr/bin/env bash
# Developer-disk space reclamation for Flutter projects on macOS.
#
# Two tiers, because they have different owners and different blast radii:
#
#   PROJECT tier — `flutter clean` in a project (build/ + .dart_tool/).
#                  Per-project, re-created by the next build.
#   GLOBAL  tier — machine-wide developer caches shared by every project:
#                  Xcode derived data, the Dart analysis server cache,
#                  simulator scratch, superseded Gradle version caches, and
#                  orphaned flutter_tools.* build scratch left in TMPDIR by a
#                  killed or crashed flutter build/run/test/pub.
#
# Everything here regenerates. It never touches source, git, Xcode Archives,
# signing assets, or a project's generated code (`*.freezed.dart`, `*.g.dart`,
# `lib/generated/`, `assets/renderer/` all survive `flutter clean` — verified).
#
# WHY `rm -rf` AND NOT `trash`: the point is to free space. A trash on the same
# APFS volume frees NOTHING until the bin is emptied, and emptying it is
# TCC-protected (a human has to press it). Guards that make the rm safe:
# dry-run by default, a "$HOME/"-prefix assertion before every delete, literal
# path lists, and a fail-closed scan for the Gradle tier.
#
# WHY IT REPORTS A df DELTA AND NOT THE du TOTALS: `du` counts APFS
# copy-on-write clones once per clone. Measured 2026-08-07: XCTestDevices read
# 8.0G under `du` and freed EXACTLY ZERO bytes when deleted, because every block
# was shared with CoreSimulator/Devices. Only the change in free space is real,
# so that is the number this script prints. Believe the delta, not the estimate.
#
# Usage:
#   reclaim-space                  # DRY RUN — list targets + sizes, delete nothing
#   reclaim-space --yes            # reclaim (project tier = cwd, + global tier)
#   reclaim-space --yes --all-projects   # every Flutter project under the scan root
#   reclaim-space --yes --global-only    # skip flutter clean
#   reclaim-space --yes --project-only   # skip machine-wide caches
#   reclaim-space --help
#
# Env:
#   RECLAIM_SCAN_ROOT   where to look for sibling projects (default: $HOME/GitHub)
set -uo pipefail

DRY=1
DO_PROJECT=1
DO_GLOBAL=1
ALL_PROJECTS=0

for a in "$@"; do
  case "$a" in
    --yes|-y)        DRY=0 ;;
    --all-projects)  ALL_PROJECTS=1 ;;
    --global-only)   DO_PROJECT=0 ;;
    --project-only)  DO_GLOBAL=0 ;;
    --help|-h)       sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $a (use --help)" >&2; exit 2 ;;
  esac
done

# Refuse to run with an unsafe HOME — every delete below is gated on a
# "$HOME/"-prefix match, so a bogus HOME would defeat the whole guard.
[ -n "${HOME:-}" ] && [ "$HOME" != "/" ] || { echo "HOME is unsafe: '${HOME:-}'" >&2; exit 1; }

SCAN_ROOT="${RECLAIM_SCAN_ROOT:-$HOME/GitHub}"

# Same guard, for the flutter_tools.* tier: every delete there is gated on a
# "$FLUTTER_TMP/"-prefix match, so an unresolved TMPDIR must skip that tier
# rather than run unguarded. getconf is the fallback for a shell that never
# exported TMPDIR (e.g. some non-interactive/cron contexts).
FLUTTER_TMP="${TMPDIR:-$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || true)}"
FLUTTER_TMP="${FLUTTER_TMP%/}"
[ -n "$FLUTTER_TMP" ] && [ "$FLUTTER_TMP" != "/" ] && [ -d "$FLUTTER_TMP" ] || FLUTTER_TMP=""

# ---------------------------------------------------------------- measurement

# The DATA volume, not "/". On APFS "/" is the sealed read-only system snapshot;
# its Used column is meaningless for this purpose.
data_vol() { [ -d /System/Volumes/Data ] && echo /System/Volumes/Data || echo /; }
avail_mb() { df -m "$(data_vol)" | awk 'NR==2 {print $4}'; }
human()    { du -sh "$1" 2>/dev/null | cut -f1; }
as_gb()    { awk -v m="$1" 'BEGIN {printf "%.1f", m/1024}'; }

# ------------------------------------------------------------------- guards

# Deleting a Gradle cache under a live daemon corrupts the build; deleting
# derived data under a running xcodebuild does the same. Both are cheap to
# check and catastrophic to miss, so this refuses rather than races.
#
# A `pgrep -f` pattern matches any process whose ARGV CONTAINS it — including a
# process that merely names the tool: a script polling with
# `pgrep -f 'flutter_tools.snapshot test'` carries that text in its own command
# line and matches itself. Measured 2026-09-12: a peer session waiting for the
# machine to go quiet did exactly that, so this refused while nothing was
# building — and the waiter was waiting on a condition it was itself preventing.
# So a match counts only when the EXECUTABLE is the tool.
tool_running() {   # $1 = argv pattern, $2… = executable names that make it real
  local pat="$1"; shift
  local pid comm want
  for pid in $(pgrep -f "$pat" 2>/dev/null); do
    [ "$pid" = "$$" ] && continue
    comm=$(ps -o comm= -p "$pid" 2>/dev/null) || continue
    comm=${comm##*/}
    for want in "$@"; do [ "$comm" = "$want" ] && return 0; done
  done
  return 1
}

busy_reason=""
tool_running 'GradleDaemon' java >/dev/null 2>&1 && busy_reason="a Gradle daemon is running"
tool_running 'xcodebuild' xcodebuild >/dev/null 2>&1 && busy_reason="xcodebuild is running"
tool_running 'flutter_tools\.snapshot (build|run|test)' dart dartvm dartaotruntime >/dev/null 2>&1 && busy_reason="a flutter build or test run is in progress"
# `flutter clean` deletes .dart_tool/ and build/ — the tree a running suite is
# reading from. `test` belongs in the pattern above for the same reason `build`
# does; it was missing while several sessions ran suites concurrently, so a
# sweep could pull the ground out from under another session's run.
pgrep -x 'flutter_tester'  >/dev/null 2>&1 && busy_reason="a flutter test run is in progress"

if [ -n "$busy_reason" ] && [ $DRY -eq 0 ]; then
  echo "REFUSED: $busy_reason." >&2
  echo "Stop it first (e.g. './gradlew --stop') and re-run." >&2
  exit 1
fi

# --------------------------------------------------------------------- start

echo "reclaim-space  ·  $([ $DRY -eq 1 ] && echo 'DRY RUN (nothing deleted)' || echo 'LIVE (deleting)')"
[ -n "$busy_reason" ] && echo "  note: $busy_reason — a live run would refuse."
echo

BEFORE_MB=$(avail_mb)

# ------------------------------------------------------------- project tier

flutter_projects() {
  if [ $ALL_PROJECTS -eq 1 ]; then
    # TWO scans, because a worktree's pubspec is nowhere near depth 2.
    #
    #   $SCAN_ROOT/<repo>/pubspec.yaml                                depth 2
    #   $SCAN_ROOT/<repo>/.claude/worktrees/<name>/pubspec.yaml       depth 5
    #
    # For eight versions this function was the depth-2 scan alone, so
    # `--all-projects` silently skipped every worktree — measured 2026-09-01:
    # it found 3 projects and missed 6 worktrees holding 12.7G of build/, the
    # largest single consumer on the machine. It reported a clean sweep the
    # whole time. The worktree scan is a separate literal path pattern rather
    # than a deeper -maxdepth so it cannot start matching example apps,
    # ios/macos runner projects, or a monorepo's sub-packages.
    { find "$SCAN_ROOT" -maxdepth 2 -name pubspec.yaml 2>/dev/null
      find "$SCAN_ROOT" -maxdepth 5 -path '*/.claude/worktrees/*/pubspec.yaml' 2>/dev/null
    } | while read -r p; do d=$(dirname "$p"); [ -d "$d/lib" ] && echo "$d"; done
  elif [ -f "$PWD/pubspec.yaml" ]; then
    echo "$PWD"
  fi
}

if [ $DO_PROJECT -eq 1 ]; then
  echo "PROJECT tier — flutter clean"
  found=0
  while read -r proj; do
    [ -n "$proj" ] || continue
    found=1
    size=$( { du -sm "$proj/build" "$proj/.dart_tool" 2>/dev/null || true; } | awk '{s+=$1} END {print s+0}')
    printf '  %-42s %7s\n' "$(basename "$proj")" "$(as_gb "$size")G"
    if [ $DRY -eq 0 ]; then
      ( cd "$proj" && flutter clean >/dev/null 2>&1 ) \
        && echo "      cleaned" \
        || echo "      !! flutter clean failed — left untouched" >&2
    fi
  done < <(flutter_projects)
  [ $found -eq 0 ] && echo "  (no Flutter project here — run from a project dir or pass --all-projects)"
  echo
  # Deliberately no `flutter pub get`: a closed-out feature line does not need a
  # resolved project, and the next session that opens it will run that itself.
  # The reason is WORKFLOW, not space — pub-get does re-populate
  # build/ios/SourcePackages, but that is largely an APFS clone of
  # ~/Library/Caches/org.swift.swiftpm and costs ~0.1G of real disk despite a
  # 1.3-1.7G du reading. Same clone illusion the header warns about.
fi

# -------------------------------------------------------------- global tier

if [ $DO_GLOBAL -eq 1 ]; then
  echo "GLOBAL tier — machine-wide developer caches"

  # Contents are wiped; the directory itself is kept because the owning tool
  # expects it to exist and repopulates on demand.
  DIRS=(
    "Xcode DerivedData|$HOME/Library/Developer/Xcode/DerivedData"
    "Xcode iOS DeviceSupport|$HOME/Library/Developer/Xcode/iOS DeviceSupport"
    "Xcode watchOS DeviceSupport|$HOME/Library/Developer/Xcode/watchOS DeviceSupport"
    "Xcode tvOS DeviceSupport|$HOME/Library/Developer/Xcode/tvOS DeviceSupport"
    "Xcode DocumentationCache|$HOME/Library/Developer/Xcode/DocumentationCache"
    "Dart analysis cache|$HOME/.dartServer"
    "CoreSimulator caches|$HOME/Library/Developer/CoreSimulator/Caches"
  )
  for entry in "${DIRS[@]}"; do
    label="${entry%%|*}"; path="${entry#*|}"
    if [ -d "$path" ]; then
      printf '  %-42s %7s\n' "$label" "$(human "$path")"
      if [ $DRY -eq 0 ]; then
        case "$path" in
          "$HOME/"*) find "$path" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null ;;
          *) echo "      !! refused (not under \$HOME): $path" >&2 ;;
        esac
      fi
    fi
  done

  # Flutter's own build scratch in TMPDIR (flutter_tools.<rand> — kernel
  # snapshot / asset-bundle work for build, run, test, pub). A clean exit
  # deletes it; a killed or crashed flutter process leaves it behind, and
  # nothing else in this flow ever revisits TMPDIR to notice. Measured
  # 2026-09-08: 641 orphaned dirs held 57G on one machine, none of them still
  # open. TMPDIR is shared with everything else on the box, so liveness is
  # checked with `lsof` on the exact directory, not a flutter-process-name
  # guess — a live build under a process name this script doesn't already
  # pattern-match (pub, attach, analyze, ...) would otherwise be corrupted.
  if [ -n "$FLUTTER_TMP" ]; then
    FT_DIRS=()
    while IFS= read -r d; do FT_DIRS+=("$d"); done < <(find "$FLUTTER_TMP" -mindepth 1 -maxdepth 1 -name 'flutter_tools.*' 2>/dev/null)
    if [ ${#FT_DIRS[@]} -gt 0 ]; then
      size=$( { du -sm "${FT_DIRS[@]}" 2>/dev/null || true; } | awk '{s+=$1} END {print s+0}')
      printf '  %-42s %7s\n' "orphaned flutter_tools.* (TMPDIR)" "$(as_gb "$size")G"
      if [ $DRY -eq 0 ]; then
        OPEN=$(lsof +D "$FLUTTER_TMP" 2>/dev/null | awk '{print $NF}')
        skipped=0
        for d in "${FT_DIRS[@]}"; do
          case "$d" in "$FLUTTER_TMP/"*) : ;; *) continue ;; esac
          if printf '%s\n' "$OPEN" | grep -qF "$d/"; then
            skipped=$((skipped + 1))
            continue
          fi
          rm -rf "$d"
        done
        [ "$skipped" -gt 0 ] && echo "      skipped $skipped still open (live flutter process)"
      fi
    fi
  fi

  # Superseded Gradle version caches. Which versions are live is DERIVED from
  # the wrapper of every project found, never hardcoded — a hardcoded version
  # goes stale silently and then deletes a cache that is still in use.
  IN_USE=()
  while IFS= read -r props; do
    v=$(sed -n 's/.*gradle-\([0-9][0-9.]*\)-[a-z]*\.zip.*/\1/p' "$props" | head -1)
    [ -n "$v" ] && IN_USE+=("$v")
  done < <(find "$SCAN_ROOT" -maxdepth 6 -path '*gradle/wrapper/gradle-wrapper.properties' 2>/dev/null)

  if [ ${#IN_USE[@]} -eq 0 ]; then
    # FAIL CLOSED: with no wrapper found we cannot know which versions are
    # live, and guessing here deletes a cache someone is mid-build against.
    echo "  Gradle caches                              SKIPPED — no project wrapper found under $SCAN_ROOT"
  else
    echo "  Gradle versions in use: $(printf '%s\n' "${IN_USE[@]}" | sort -u | tr '\n' ' ')"
    for vdir in "$HOME"/.gradle/caches/*/; do
      ver=$(basename "$vdir")
      # Only ever consider pure version directories — modules-2, jars-9,
      # journal-1 and build-cache-1 are live shared state, not versions.
      [[ "$ver" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || continue
      printf '%s\n' "${IN_USE[@]}" | grep -qx "$ver" && continue
      printf '  %-42s %7s\n' "stale Gradle cache $ver" "$(human "$vdir")"
      [ $DRY -eq 0 ] && case "$vdir" in "$HOME/"*) rm -rf "$vdir" ;; esac
    done
    for wdir in "$HOME"/.gradle/wrapper/dists/gradle-*/; do
      ver=$(basename "$wdir" | sed 's/^gradle-//; s/-[a-z]*$//')
      printf '%s\n' "${IN_USE[@]}" | grep -qx "$ver" && continue
      printf '  %-42s %7s\n' "stale Gradle dist $ver" "$(human "$wdir")"
      [ $DRY -eq 0 ] && case "$wdir" in "$HOME/"*) rm -rf "$wdir" ;; esac
    done
  fi

  # Throwaway simulator clones from `xcodebuild test`, plus simulators whose
  # runtime is gone. Both are correct to clear, but do not expect space back:
  # the clones are APFS copy-on-write of the real device set, so `du` shows
  # gigabytes while the true reclaim is ~0 (measured 2026-08-07). Kept because
  # it prunes stale device entries, not because it is a space lever.
  if command -v xcrun >/dev/null 2>&1; then
    if [ $DRY -eq 0 ]; then
      xcrun simctl --set "$HOME/Library/Developer/XCTestDevices" delete all >/dev/null 2>&1 || true
      xcrun simctl delete unavailable >/dev/null 2>&1 || true
      echo "  XCTest device clones + unavailable sims    pruned (expect ~0 space — APFS clones)"
    else
      echo "  XCTest device clones + unavailable sims    would prune (expect ~0 space — APFS clones)"
    fi
  fi

  # DELIBERATELY NOT TOUCHED — ~/Library/Caches/org.swift.swiftpm. It is the
  # shared SPM download cache that build/ios/SourcePackages is populated FROM,
  # so clearing it turns the next iOS build into a network re-download. It is
  # under a gigabyte; it is not worth the build it costs.
  echo
fi

# -------------------------------------------------------------------- report

AFTER_MB=$(avail_mb)
DELTA=$((AFTER_MB - BEFORE_MB))

if [ $DRY -eq 1 ]; then
  # No before/after here: nothing was deleted, so any delta is just measurement
  # drift from whatever else the machine is doing, and printing it as a pair
  # reads like a result.
  printf 'Free space on %s: %s G\n' "$(data_vol)" "$(as_gb "$AFTER_MB")"
  echo
  echo "Dry run — nothing deleted. Re-run with --yes to reclaim."
  echo "Sizes above are du estimates; the live run reports the real delta."
else
  echo "Free space on $(data_vol):"
  printf '  before  %8s G\n' "$(as_gb "$BEFORE_MB")"
  printf '  after   %8s G\n' "$(as_gb "$AFTER_MB")"
  printf '  freed   %8s G\n' "$(as_gb "$DELTA")"
  if [ "$DELTA" -lt 0 ]; then
    echo "  (negative — a build or index ran during the sweep; re-measure when idle)"
  fi
fi
