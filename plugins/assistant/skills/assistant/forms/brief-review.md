## Spec pages read
Read before the brief; both spec sections stay in English and are left out when the project config sets `spec: none`.
- <page title or path> · last edited <the time the page shows>
## Spec verdicts
One line per `Needs you` line of the filed brief, in order. `spec decides` and `spec decides (combined)` are also filed under 5 with Fix: drop that `Needs you`, quote the page.
- <the question, a few words> · verdict: spec decides "<quote>" | spec decides (combined) "<the passages>" | spec silent | spec ambiguous "<the passages>"
## 1 Logic
[1.<n>] <brief section> — what is wrong · failure scenario · Fix: <the change>
## 2 Data flow
## 5 Built vs approved design
A `Decided` line that departs from what the `architecture:` document states is filed with Fix: make it `Needs you`, citing the section by path and heading. A departure already put as `Needs you` is not filed.
## Proportion
Style-pack S15 and S16.1 at design scale. A NEW thing, guard, retry, fallback or lock whose `Evidence` cites no case, or a case that can't happen, is filed with Fix: drop it; a design with fewer NEW things that still covers every evidenced case is filed with Fix: that design; a `Decided` line that adds or changes a product behaviour (what the user sees, or how a feature behaves) is filed with Fix: quote its spec page, or, where the spec doesn't decide it or conflicts with the code, make it `Needs you` with the code example (`references/brief.md`). A NEW thing whose `Ownership` names no closest existing unit with why it can't be reused is filed with Fix: name them, or reuse the unit.
## low confidence
- <finding> · score <0–100>
passed: <the blocks with no finding>
