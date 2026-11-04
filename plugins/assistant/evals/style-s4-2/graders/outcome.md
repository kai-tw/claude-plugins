---
type: llm
---
PASS if the quoted S4.2 requires a custom member→string mapping with a hand-written code per
member for anything persisted or sent outside the process, forbids the member's identifier,
requires some check that catches a member missing from the mapping while leaving the kind of
check to the language layer, keeps a fallback for unknown codes on decode, and states the cost
as "adding a member means adding its code"; and the quoted S4.1-dart rejects `.index`, `.name`,
`toString()` and a `Map` literal, requires an exhaustive `switch`, and says a store holding
identifier strings adopts equal codes while one holding positions needs a frozen table and a
migration.
FAIL if S4.2 still requires strings derived from the member, or S4.1-dart still persists with
`toString()` or allows a `Map` literal, or S4.1-csharp still persists the member name.
