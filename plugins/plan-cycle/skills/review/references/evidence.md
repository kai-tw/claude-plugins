# Evidence rules for a finding

Binds every verdict this agent returns — scored and non-scored alike. A report
that breaks one of these is invalid even when every citation in it resolves.

- **`無法判定` is a verdict; "absent" is not its synonym.** When you looked and
  still cannot tell, return `無法判定` and name who closes it (the author, which
  document, which command) — never upgrade it to "no mechanism" / "not
  implemented" / "nothing covers this". Without this arm every failure to find
  becomes a reported defect, and the author acts on a defect that isn't there.

- **An absence claim needs a sweep, not a grep.** 只有・全部・沒有・從來・N 個 —
  a grep proves existence and can never prove absence or completeness, because it
  cannot report what it did not look at. Either dispatch `Explore` over the whole
  space (state the breadth in the prompt — no hook reaches a sub-agent, so the
  prompt is the only channel), or downgrade the sentence to an existential one:
  "I looked in A, B and C; not there", never "only X exists".

- **Name the question you actually searched.** The common failure is silent
  substitution: the original question has no findable answer, so a neighbouring
  one that does gets answered instead and its answer is reported as the
  original's. Every finding states the scope searched and why that scope — a
  citation-dense inference still jumps at the last step, and the density is
  exactly what stops a reader from asking whether the question changed.
