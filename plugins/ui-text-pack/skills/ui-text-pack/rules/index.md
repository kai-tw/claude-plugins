# Charter of user-visible text

This law holds the rules for writing user-visible text that mechanical checks cannot
decide and that need judgment.

**Scope.** Text the app renders on screen at runtime for users to read: labels, titles,
buttons, field names, hints, error messages, empty states. Logs, exception messages that
only reach crash reports, store listings and marketing material are outside this law.

**Severity.** This law **sets no severity levels** — the review procedure assigns the
severity of a violation.

## Precedence

Three layers; the higher prevails. **This section is the only version of the precedence
rules**; lower layers and procedural files cite it.

| Rank | Contains | Authority |
|---|---|---|
| Constitution | this law's `U<N>`: general rules that hold in every locale and every project | the only place a base rule may be made |
| Statute | locale layer: that locale's concrete criteria, each attached to one `U<N>` | may only **make a base rule concrete** |
| Regulation | project layer: that project's facts (glossary, each screen's labels, string storage format, its own check scripts) | may only **tighten** or **supply facts** |

**Conflict test.** Can the two rules **be satisfied at once**? If yes, they stack
lawfully; if not, they conflict.

**No exemption clauses.** A conflict has only three outcomes, all amendments: narrow the
base rule (add a condition, or move it down to the locale layer) · repeal the base rule ·
the project changes the string.

**Conflict found during review.** That item is ruled **`undeterminable`**,
naming who must amend at which layer; the amendment is filed separately. It is not
`passed`, nor a `critical` aimed at the author.

**Burden of proof.** Whoever claims a conflict must **quote both rules verbatim and state
why they cannot both be satisfied**.

## Base rules

**An empty lower layer does not mean the locale has no rules** — the base rules still
apply. Conversely, reviewers **must not invent a finding** from a text preference this law
does not legislate: no provision does not mean free discretion.

## U1 — How a string is written is decided by where it renders

**Principle:** Whether the same thing is written as a label or as a sentence depends on
whether the user is scanning or reading at that spot — text written without its position
is a manual, not an interface.

- **U1.1 Labels and sentences are separate** — Check: Does the string render as a label
  for scanning (button, title, field name, tab), or as a full sentence the user reads word
  by word (hint, error, empty-state text)? Using a full sentence as a label, or a fragment
  as an explanation, violates this rule. The locale layer sets the ending punctuation and
  sentence pattern of each.
- **U1.2 A state is stated; a request is requested** — Check: Does the sentence describe
  the system's current state, or something the user must do? A state written as a request
  violates this rule — the screen has not yet asked the user to do anything. Example:
  「目前離線」 is a state, 「請檢查網路後再試一次」 a request; the two may share a sentence
  but must not pass for each other.
- **U1.3 Position and available width must be recorded with the string** — Check: Is the
  component the string renders in, and how many characters and lines it has, recorded
  where both the string's writer and other locales' writers can read it (where is a
  regulation-layer matter)? Where it is not recorded and the spot truncates, this violates
  this rule: a writer of only the source language cannot see which locale truncates.

## U2 — A failure message must state what happened, the current state, and the next step

**Principle:** Users read a failure message for one thing — what to do now. Missing any of
the three hands the judgment back to the user.

- **U2.1 All three present** — Check: Does the failure string say what happened, what
  state the system is in now, and what the user does next? Where no next step can be
  given, it must say why, not fill in a generic line. Adding reassurance or guarantees
  beyond the three also violates this rule — that answers a question the user did not
  ask. Example: 「登出失敗，目前仍在登入狀態，請再試一次。」
- **U2.2 One failure per string** — Check: Do two failures with different causes share
  one string? Sharing violates this rule: users take different actions for each. Nor may
  a failure message be copied verbatim from elsewhere — that sentence describes another
  failure.

## U3 — Each locale is written natively

**Principle:** Translation retells the same thing in another locale; it is not swapping
words in a source-language sentence. When one source sentence is transcribed word for word
into several locales, at least half of them read unlike anything a person would say.

- **U3.1 No word-for-word transcription** — Check: Back-translated into the source
  language, does the locale's value change meaning? Where it does not, but its word order,
  sentence pattern or punctuation do not follow that locale's usage, it still violates
  this rule.
- **U3.2 The locale sets the sentence pattern, not the source language** — Check: Are the
  patterns for requests, questions and polite register each chosen by their own locale's
  usage, rather than mapped sentence by sentence from the source language? Sentence
  splitting and clause order also follow the locale, not the source's sentence breaks.
  Example: in one batch of strings, English uses a plain imperative, Japanese
  「〜てください」, Traditional Chinese an opening 「請」 — the three need not appear at
  corresponding places.
- **U3.3 Proposals are produced per locale in parallel** — Check: When offering options
  for approval, are options produced separately for each locale? Fixing one
  source-language sentence and translating the other locales from it violates this rule.
- **U3.4 This base rule applies to values with no source-language value** — Check: Where
  a value is written directly in its locale, with no other locale's source in the string
  file, are its word order, conjunctions and sentence breaks the locale's own? The source
  is not limited to strings — type names, code comments and the language the string's
  writer thinks in are sources too; a value that maps sentence by sentence back to such a
  source and happens to read smoothly violates this rule.
- **U3.5 Part of speech and collocation follow the locale** — Check: Do each word's part of
  speech and the words it pairs with follow the locale's usage? Carrying over the source
  language's part of speech or collocation violates this rule; so does omitting elements
  the locale requires (objects, measure words, aspect markers).
- **U3.6 Unfinished must not read as not started** — Check: Where an action has begun but
  not finished, is the value written the way the locale marks "unfinished"? Reading as
  "not happened" in that locale violates this rule — users conclude that existing
  progress does not exist.

## U4 — One concept, one word across the app

**Principle:** Users find their way by words. When a concept changes its word, users
think it is a different thing.

- **U4.1 Terms must not drift between screens** — Check: Does the concept use the same
  word on every screen this change touches? Where the project has a glossary, the glossary
  governs (it belongs to the regulation layer).
- **U4.2 A reference to another screen must use that screen's actual label in the same
  locale** — Check: Do the tabs, pages, buttons and settings the string mentions use,
  verbatim, the label that screen actually shows in that locale? Keeping the
  source-language name, or coining another phrasing, violates this rule: users search for
  the literal words.
- **U4.3 Refer to things by names users can see** — Check: Does the string refer to
  something by an internal identifier (class name, error code, file path, version number,
  internal code name, stage or unit names of an internal process)? Doing so violates this
  rule — those are for logs.

## U5 — The key triggers retranslation

**Principle:** The key is the only evidence the system has of whether text is new or old.
When the key stays while the value's meaning changes, the other locales silently stay on
the old meaning, and no check reports it.

- **U5.1 A change of meaning must change the key** — Check: Does the change alter a
  string's meaning? Where it does and keeps the original key, it violates this rule. Typo
  fixes that do not change meaning are outside this rule.
- **U5.2 Write all locales at once** — Check: Does every key the change adds or alters
  have values for all locales within that same change? Leaving them for later violates
  this rule: a locale missing a value silently falls back to the source language, and the
  screen shows no error.
