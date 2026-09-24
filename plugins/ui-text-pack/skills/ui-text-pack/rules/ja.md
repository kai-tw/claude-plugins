# User-visible text — Japanese locale layer

Loads when: `locales` includes ja. Every item must attach to an existing `U<N>` of the base
law; one that cannot must first amend the charter (`CONVENTIONS.md`).

## U1 — How a string is written is decided by where it renders

- **U1.1-ja Full sentences end with 「。」; labels take no ending punctuation** — Check:
  Where the value is a full sentence, does it end with 「。」? Where it is a label, button or
  title, does it carry no ending punctuation? Swapping the two violates this rule.

## U2 — A failure message must state what happened, the current state, and the next step

- **U2.1-ja Failure sentences open with 「〜できませんでした」, give the reason with 「〜ため」,
  and end with a request** — Check: Does the failure sentence follow this order? The
  closing request takes the 「〜てください」 form, such as 「もう一度お試しください」. Example:
  「サインアウトできませんでした。まだサインイン中のため、もう一度お試しください。」

## U3 — Each locale is written natively

- **U3.1-ja Polite form (丁寧体) throughout; requests use 「〜てください」, questions
  「〜ますか？」** — Check: Is the value in 丁寧体? Writing it in plain form (常体:
  「〜する？」「〜しろ」) violates this rule — it reads as curt in a product UI. Do not stack
  honorific (尊敬語) and humble (謙譲語) forms.
- **U3.2-ja Particles and word order are chosen for Japanese, not mapped sentence by
  sentence from the source language** — Check: Back-translated into the source language,
  does the value's word order align segment by segment with the source sentence? Alignment
  usually means transcription, violating charter U3.1.
