# Style rules — JS / TS statute layer

Loaded when: the diff contains `.js` · `.mjs` · `.cjs` · `.jsx` · `.ts` · `.tsx`. Each rule
must hang under an existing charter `S<N>`; if it cannot, amend the charter first
(`CONVENTIONS.md`).

## S3 — Every collapse must be justified at each consumption point

- **S3.1-js `??` and `||` collapse different states; each must be justified** — Check: does
  this code collapse "`null` / `undefined`", or every falsy value? With `||`, `0`, `''`,
  `NaN` and `false` are collapsed into the default as well, so wherever any of them is a
  valid input, it violates this rule. `??` collapses only `null` and `undefined`, and its
  validity must still be justified at each consumption point per charter S3.1.
- **S3.2-js `null`, `undefined` and a missing key are three states and must not be assumed
  equivalent** — Check: is the value's "absence" an explicit `null` (known to be none),
  `undefined` (not given), or a key the object simply lacks (this path was never taken)?
  Collapsing them together with `== null` or optional chaining without justifying that the
  three are equivalent violates this rule.

## S4 — A persisted value's meaning must not depend on position or manual upkeep

- **S4.1-js `JSON.stringify` drops `undefined` silently** — Check: can any field of the
  object to be written be `undefined`? If so and it is not handled, it violates this rule:
  `undefined` in an object property disappears entirely (indistinguishable from "this field
  was never written"), while `undefined` in an array element becomes `null` — one value, two
  outcomes, neither an error. Convert it explicitly to `null` or omit it before writing, and
  have the reader decide on that basis.

## S5 — Silently aborting a flow must state the trigger and the flow skipped

- **S5.1-js An unhandled promise's failure never reaches the caller** — Check: for this
  promise that is neither `await`ed nor given a `.catch()`, who observes its failure? If no
  one, it violates this rule — the failure lands in the runtime's global handler, which
  behaves differently in browsers and Node, so whether it blows up depends on where it runs.

## S7 — Failure handling must match the kind of failure

- **S7.1-js `catch` has no type filter; non-matching errors must be rethrown explicitly** —
  Check: inside the `catch` block, does the code first establish that what was caught is an
  error this place can recover from, and `throw` the rest? Handling everything without that
  check violates charter S7.3: a JS `catch` binds everything, so programming errors like
  `TypeError` and `ReferenceError` land in the same block as expected environmental errors,
  and the charter requires the former to propagate.
