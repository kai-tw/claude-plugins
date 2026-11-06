# Style rules — JS / TS language rules

## S3

- **S3.1-js `??` and `||` collapse different states; each must be justified** — Check: with
  `||`, `0`, `''`, `NaN` and `false` are collapsed into the default along with `null` and
  `undefined`, so wherever any of them is a valid input, it violates this rule. `??` collapses
  only `null` and `undefined`.
- **S3.2-js `null`, `undefined` and a missing key are three states and must not be assumed
  equivalent** — Check: "absence" is an explicit `null` (known to be none), `undefined` (not
  given) or a key the object simply lacks (this path was never taken); collapsing them
  together with `== null` or optional chaining without justifying that the three are
  equivalent violates this rule.

## S4

- **S4.1-js `JSON.stringify` drops `undefined` silently** — Check: an object to be written
  with a field that can be `undefined` and is not handled violates this rule: `undefined` in
  an object property disappears entirely (indistinguishable from "this field was never
  written"), while `undefined` in an array element becomes `null` — one value, two outcomes,
  neither an error. Convert it explicitly to `null` or omit it before writing, and have the
  reader decide on that basis.

## S5

- **S5.1-js An unhandled promise's failure never reaches the caller** — Check: a promise that
  is neither `await`ed nor given a `.catch()`, and whose failure no one observes, violates
  this rule — the failure lands in the runtime's global handler, which behaves differently in
  browsers and Node.

## S7

- **S7.1-js `catch` has no type filter; non-matching errors must be rethrown explicitly** —
  Check: a `catch` block that handles everything, without first establishing that what was
  caught is an error this place can recover from and throwing the rest, violates core rule
  S7.3: programming errors like `TypeError` and `ReferenceError` land in the same block as
  expected environmental errors, and S7 requires the former to propagate.
