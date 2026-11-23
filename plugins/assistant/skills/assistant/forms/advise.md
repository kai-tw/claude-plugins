## <finding id> — <file:line, rule>
Cause: <the root cause; for a finding that came back, also why its fix did not hold; or "intent question" and what the user must decide>
Evidence: <file:line, or the experiment and its result>
Suggested fix: <the change>
Confidence: <0–100>

## Architecture check
Root cause: <architecture | not architecture>
Criterion: Ownership. Each piece of data is held by the layer that produces it and can keep it valid. No other layer keeps a copy that goes stale when the owner changes.
Evidence: <for each piece of data the findings or the triggering report touch: the layer that produces it and every layer that keeps a copy, at file:line>
Suggested change: <architecture only: the adjustment, the files it touches and its cost>
