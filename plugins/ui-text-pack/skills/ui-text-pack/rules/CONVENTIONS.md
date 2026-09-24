# UI text rules — legislative procedure and format (ui-text-pack plugin)

`Read` this file only when adding, changing, merging or deleting a UI text rule.

**What this pack is.** A rulebook for writing user-visible text, read by reviewers
(assistant's `text-verifier`, etc.), all loaded through the `ui-text-pack` command, in two
layers: **base rules (`index.md`, locale- and project-neutral)** and the **locale layer
(`zh-Hant.md` / `ja.md` / `en.md`)**. It holds text judgments the founder catches by hand
and scripts cannot — once such a judgment is outside the rules, reviewers are required to
pass it under "no rule to cite, no finding", so **legislation is the only way in**.

**Precedence and conflict.** The only version is `index.md §Precedence`. This file restates one
thing: **no exemption clauses**. A conflict has only three outcomes (narrow the base rule /
repeal the base rule / the project changes the string), all amendments.

**The charter is self-contained.** `index.md` is the charter and **must not name anything
but its own rule numbers** — no locale files, reviewers, check scripts, or string storage
formats (ARB, resx, strings are regulation-layer facts). The charter defines only
**precedence**, not which file carries each layer: once named, renaming or removing that
file breaks the charter.

Which file carries which layer is recorded here: the locale layer is `zh-Hant.md` /
`ja.md` / `en.md`; the regulation layer is each project's `.claude/rules/` or the string canon
the project declares.

**Charter admission (the only test for where a base rule goes).** A rule enters
`index.md` only if it **holds in every locale**. "This rule does not hold in Japanese" is
not an exception but proof it does not belong in the charter — move it down to the locale
layer.

**Admission criteria (pass these before format).**
- **Nothing a script can check.** Term blocklists, punctuation form, half- vs full-width,
  second-person pronouns, exclamation marks and interjections, version-number wording,
  keys missing translations — anything decidable by string matching belongs to each
  project's check scripts and CI; reviewers do not re-derive what scripts decided, and
  admitting it here only spends judgment budget on mechanical questions.
- **Nothing without a `Check:`.** A rule a bystander cannot verify is a preference, not a
  rule (`.claude/rules/writing-rules.md`).
- **Mechanically decidable but not yet scripted: write the script, not prose.** It goes
  into the project's existing string check script; that is deterministic and reaches the
  author in CI.
  Corollary: locale files will tend toward empty over time — nearly every decidable
  locale-layer item should be a script rule; that is division of labor, not omission.

**Format.**
- Base rules: one per section in `index.md` — `## U<N> — <title>` + `**Principle:**` one
  or two sentences of general rule, followed by that base rule's sub-checks that **hold
  across locales**, one bullet each:
  `- **U<N>.k <name>** — Check: <one-line test>. Example: <≤1 sentence>`.
  Base rules and their sub-checks **carry no locale**: one containing a locale's
  vocabulary, sentence patterns or punctuation belongs to the locale layer.
- Locale layer: same format, numbered with a suffix `U<N>.k-<tag>`, holding only
  **that locale's own** concrete criteria. **The locale layer's `k` is its own sequence,
  starting at 1**, unrelated to the charter's `k` under the same `U<N>`.
- **Every locale sub-check must attach to an existing `U<N>`.** One that cannot requires
  amending the charter: first make the base rule in `index.md`, then attach. Locale files
  must not make their own base rules.
- **Legal register; Chinese text uses Taiwan usage.** Prohibition `must not`, obligation
  `must`, permission `may`; conditions `Where …, …`; exclusions `… is outside this rule`;
  the subject is `this rule`.
- **Examples always quote that locale's real text**, never a source-language sentence
  annotated "(same in Chinese)".

**Learning update procedure.**
1. First check whether `index.md` has a base rule to attach to.
2. If it does → add a locale sub-check to the matching locale file (or widen an existing
   item's `Check:` instead of adding one).
3. If not → first make the base rule in `index.md` (it must pass charter admission),
   then attach.
4. On conflict → amend per the three outcomes in `index.md §Precedence`; do not add exception
   clauses.
5. Delete outdated items outright, leaving no "retired" residue (history is in git).
