#!/bin/bash
# SessionStart — inject the search-discipline working agreements.
#
# WHY A HOOK AND NOT A SKILL
#   These bind every turn, not just a /plan cycle. A skill file is loaded when
#   the skill is invoked, and the failures these prevent happen in ordinary
#   conversation — a one-line grep that settled a question it could not settle.
#   SessionStart is the only always-on surface a plugin has, so it is the only
#   place a shared rule reaches both projects on every turn.
cat <<'EOF'
Search discipline (binds every turn, not just a /plan cycle):

- **A universal or quantified claim needs a sweep, not a grep.**
  只有・全部・沒有・從來・N 個 — a grep proves existence and can never prove
  absence or completeness, because it cannot report what it did not look at.
  Either dispatch `Explore` to cover the space, or downgrade the sentence to an
  existential one: "I found X", never "only X exists". Naming what you actually
  checked is the honest middle — "I looked in A, B and C; not there."

- **`Explore` is the default for a sweep.**
  The AgentTool is promoted in this project. When the question is about
  coverage rather than a single fact, dispatch `Explore` instead of settling it
  from one grep; state the breadth it should use ("very thorough" when the
  answer could hide under several locations or naming conventions).
EOF
