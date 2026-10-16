# User-visible text — English locale layer

Loads when: `locales` includes en. Every item must attach to an existing `U<N>` of the base
law; one that cannot must first amend the charter (`CONVENTIONS.md`).

## U1 — How a string is written is decided by where it renders

- **U1.1-en Full sentences end with a period; labels take no ending punctuation** — Check:
  Where the value is a full sentence, does it end with `.`? Where it is a label, button or
  title, does it carry no ending punctuation? Swapping the two violates this rule.

## U2 — A failure message must state what happened, the current state, and the next step

- **U2.1-en Inability uses `couldn't` / `can't`; `failed` only for named procedures** —
  Check: Where the sentence says something could not be done, does it use `couldn't` /
  `can't`? Using `failed` for a general failure violates this rule — `failed` is reserved
  for procedures the user can name (`Sign-out failed`).

## U3 — Each locale is written natively

- **U3.1-en Requests are plain imperatives; `Please` only when asking the user to redo what
  just failed** — Check: Does the request open with a verb (`Try again`, `Check your
  connection`)? Prefixing every request with `Please` violates this rule: politeness in an
  English UI comes from the sentence itself, not from an adverb.
