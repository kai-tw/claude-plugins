---
category: scope
source: founder
date: 2026-08-21
title: no hook reaches a sub-agent, so dispatching work also dispatches it past every guardrail
---

Measured 2026-08-21 in NovelGlide: 33 main-session transcripts carry the
minimalism-ladder text that a PreToolUse hook injects. Of 534 sub-agent
transcripts, 0 carry it — while 332 of them edited a `.dart` file, which is
exactly the trigger condition.

So neither hook kind reaches a sub-agent: not the session-start injection that
carries the search discipline, and not the pre-command interception that
guardrails is built on. A spawned agent works with none of it.

The consequence bites hardest on the rule that promotes dispatch: routing a
sweep to `Explore` sends it into the one context where "a universal claim needs
a sweep" was never stated. The more the promotion is honoured, the more work
happens unguarded.

The only channel into a sub-agent is the prompt written when dispatching it.
That makes it a main-thread obligation, which an injection CAN carry — the party
that needs to read it is the one doing the dispatching.

Not yet consumed: the wording belongs with the promotion rule, which currently
lives in the planning plugin rather than here. Where that pair should live is an
open decision.
