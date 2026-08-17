#!/usr/bin/env bash
# Designer widget lint (deterministic, design-stage).
#
# The designer now ships the real presentation widgets, so the checks run
# against THE CODE, not against a plan's description of the code. That is the
# whole point: a table claiming "no data wiring" is a claim; a grep over the
# widget file is a fact.
#
# THE BOUNDARY IT ENFORCES.
#   The designer owns *how it renders*. Anything with a lifecycle belongs to the
#   state layer — so `vsync` is the single legitimate reason for a
#   StatefulWidget (animation is intrinsically a rendering concern and cannot be
#   lifted out). Focus / Scroll / TextEditing / Page controllers are owned by the
#   cubit and arrive as parameters; constructing one here would put a disposable
#   resource in a layer that has no business releasing it.
#
# Usage: design-lint <widget.dart | dir> ...
# Exit: 0 = no hard failures, 1 = hard failure printed above, 2 = bad usage.
set -uo pipefail
export LC_ALL=en_US.UTF-8

[ "$#" -gt 0 ] || { echo "usage: design-lint <widget.dart | dir> ..." >&2; exit 2; }

files=""
for target in "$@"; do
  if [ -d "$target" ]; then
    files="${files}$(find "$target" -name '*.dart' -type f 2>/dev/null)"$'\n'
  elif [ -f "$target" ]; then
    files="${files}${target}"$'\n'
  else
    echo "usage: no such file or directory: $target" >&2; exit 2
  fi
done
files="$(printf '%s' "$files" | grep -v '^$' || true)"
[ -n "$files" ] || { echo "usage: no .dart files under the given paths" >&2; exit 2; }

fail=0
count=0

# 1. HARD — no data wiring. The designer builds presentation; data arrives as
#    constructor parameters and actions leave as callbacks.
BANNED_IMPORT='^\s*import .*(repositor|/service|_service|cubit|bloc|provider|get_it|injectable)'
BANNED_CALL='(context\.(read|watch|select)\b|BlocBuilder|BlocListener|BlocConsumer|Consumer<|StreamBuilder|FutureBuilder)'

# 2. HARD — lifecycle resources belong to the state layer, not here. Receiving
#    one as a parameter is correct; CONSTRUCTING one is the violation, so match
#    the call form only — `final ScrollController c;` has no paren.
BANNED_CTOR='\b(FocusNode|ScrollController|TextEditingController|PageController|TabController)\s*\('

for f in $files; do
  count=$((count + 1))
  hits="$(grep -nE "$BANNED_IMPORT" "$f" || true)"
  if [ -n "$hits" ]; then
    echo "FAIL  $f — imports the state/data layer; presentation takes data via parameters:"
    printf '%s\n' "$hits" | cut -c1-140 | sed 's/^/        /'
    fail=1
  fi
  hits="$(grep -nE "$BANNED_CALL" "$f" || true)"
  if [ -n "$hits" ]; then
    echo "FAIL  $f — reads state inline; data comes in as a parameter, actions go out as a callback:"
    printf '%s\n' "$hits" | cut -c1-140 | sed 's/^/        /'
    fail=1
  fi
  hits="$(grep -nE "$BANNED_CTOR" "$f" || true)"
  if [ -n "$hits" ]; then
    echo "FAIL  $f — constructs a lifecycle controller; the cubit owns it and passes it in:"
    printf '%s\n' "$hits" | cut -c1-140 | sed 's/^/        /'
    fail=1
  fi

  # 3. HARD — every value bound to the design system (Iron Law 8). Tokens live
  #    in this file now, so the bar that used to be enforced by reading a table
  #    is enforced by reading the source. A raw hex or a `Colors.*` constant
  #    drifts from the theme the moment the theme changes.
  hits="$(grep -nE '(Color\(0x|Colors\.[a-zA-Z])' "$f" | grep -viE 'Colors\.transparent' || true)"
  if [ -n "$hits" ]; then
    echo "FAIL  $f — hardcoded colour; use colorScheme.<role> so it follows the theme:"
    printf '%s\n' "$hits" | cut -c1-140 | sed 's/^/        /'
    fail=1
  fi
  hits="$(grep -nE 'TextStyle\(' "$f" | grep -vE 'textTheme|copyWith' || true)"
  if [ -n "$hits" ]; then
    echo "ADVISORY  $f — bare TextStyle; prefer textTheme.<role> (copyWith for local tweaks):"
    printf '%s\n' "$hits" | cut -c1-140 | sed 's/^/        /'
  fi

  # 4. ADVISORY — an interactive element with no screen-reader label. Grep-level
  #    only: it proves a label exists, never that it says the right thing —
  #    that judgment is the ux review's, against the render.
  if grep -qE '(GestureDetector|InkWell|IconButton|onTap:|onPressed:)' "$f" \
     && ! grep -qE '(Semantics|semanticLabel|tooltip:|excludeSemantics)' "$f"; then
    echo "ADVISORY  $f — interactive, but no Semantics / semanticLabel / tooltip anywhere in the file"
  fi

  # 5. HARD — a StatefulWidget with no vsync has no reason to exist.
  #    Checked per State class so one animated widget in a file does not excuse
  #    the rest.
  stateless_violation="$(awk '
    /class +[A-Za-z0-9_]+ +extends +State</ { inclass = 1; name = $2; vsync = 0; body = ""; depth = 0 }
    inclass {
      body = body $0 "\n"
      if ($0 ~ /TickerProvider|AnimationController|createTicker/) vsync = 1
      depth += gsub(/{/, "{"); depth -= gsub(/}/, "}")
      if (depth <= 0 && body ~ /\n.*\n/) {
        if (!vsync) print name
        inclass = 0
      }
    }
  ' "$f" || true)"
  if [ -n "$stateless_violation" ]; then
    echo "FAIL  $f — StatefulWidget without vsync; make it a StatelessWidget and pass the variation in as parameters:"
    printf '%s\n' "$stateless_violation" | sed 's/^/        /'
    echo "        vsync (TickerProvider / AnimationController) is the only reason a designer widget holds State."
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "PASS  $count file(s) — presentation-only, parameter-driven"
else
  echo "FAIL  $count file(s) checked"
fi
exit "$fail"
