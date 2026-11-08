# UI text rules — adding a rule, and the rule format

`Read` this file only when adding, changing, merging or deleting a UI text rule.

**What this pack is.** A rulebook for writing user-visible text, read by reviewers
(assistant's `verifier`, etc.), all loaded through the `ui-text-pack` command, in two
layers: **core rules (`index.md`, locale- and project-neutral)** and **locale rules
(`zh-Hant.md` / `ja.md` / `en.md`)**. It holds text judgments the user catches by hand
and scripts cannot — a reviewer must pass any such judgment that has no rule here under
"no rule to cite, no finding", so **adding a rule is the only way in**.

**Precedence and conflict.** The only version is `index.md §Precedence`. This file restates one
thing: **no exemption clauses**. A conflict has only three outcomes (narrow the core rule /
delete the core rule / the project changes the string).

**The core rules are self-contained.** `index.md` **must not name anything but its own rule
numbers** — no locale files, reviewers, check scripts, or string storage formats (ARB, resx,
strings are facts for the project rules). It defines only **precedence**, not which file
holds each level: once named, renaming or removing that file breaks the core rules.

Which file holds which level is recorded here: the locale rules are `zh-Hant.md` /
`ja.md` / `en.md`; the project rules are what each project's config names in `rules:`, or the glossary
the project declares in `strings_glossary:`.

**Where a core rule goes (the only test).** A rule enters `index.md` only if it **holds in
every locale**. "This rule does not hold in Japanese" is not an exception but proof it does
not belong in the core rules — move it down to the locale rules.

**Inclusion criteria (pass these before the rule format).**
- **Nothing a script can check.** Term blocklists, punctuation form, half- vs full-width,
  second-person pronouns, exclamation marks and interjections, version-number wording,
  keys missing translations — anything decidable by string matching belongs to each
  project's check scripts and CI; reviewers do not re-derive what scripts decided, and
  including it here only spends reviewer attention on mechanical questions.
- **Nothing without a `Check:`.** A rule a bystander cannot verify is a preference, not a
  rule (`.claude/rules/writing-rules.md`).
- **Mechanically decidable but not yet scripted: write the script, not prose.** It goes
  into the project's existing string check script; that is deterministic and reaches the
  author in CI.
  Corollary: locale files will tend toward empty over time — nearly every decidable
  locale-level item should be a script rule; that is division of labor, not omission.

**Rule format.**
- Core rules: one per section in `index.md` — `## U<N> — <title>` + `**Principle:**` one
  or two sentences of general rule, followed by that core rule's sub-checks that **hold
  across locales**, one bullet each:
  `- **U<N>.k <name>** — Check: <one-line test>. Example: <≤1 sentence>`.
  Core rules and their sub-checks **carry no locale**: one containing a locale's
  vocabulary, sentence patterns or punctuation belongs to the locale rules.
- Locale rules: same format, numbered with a suffix `U<N>.k-<tag>`, holding only
  **that locale's own** concrete criteria. **A locale file's `k` is its own sequence,
  starting at 1**, unrelated to the core rules' `k` under the same `U<N>`.
- **Every locale sub-check must be filed under an existing `U<N>`.** If none fits, add the
  core rule to `index.md` first, then file it there. Locale files must not add core rules.
- **Specification style; Chinese text uses Taiwan usage.** Prohibition `must not`,
  obligation `must`, permission `may`; conditions `Where …, …`; exclusions `… is outside
  this rule`; the subject is `this rule`.
- **Examples always quote that locale's real text**, never a source-language sentence
  annotated "(same in Chinese)".

**Adding or changing a rule.**
1. First check whether `index.md` has a core rule to file it under.
2. If it does → add a locale sub-check to the matching locale file (or widen an existing
   item's `Check:` instead of adding one).
3. If not → first add the core rule to `index.md` (it must hold in every locale), then
   file the sub-check under it.
4. On conflict → change the rule per the three outcomes in `index.md §Precedence`; do not
   add exception clauses.
5. Delete outdated items outright, leaving no "retired" note (history is in git).
