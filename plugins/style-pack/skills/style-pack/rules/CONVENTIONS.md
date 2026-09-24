# Style rules — legislative procedure and drafting form (style-pack plugin)

`Read` this file only when adding, changing, merging or deleting a style rule.

**What this pack is.** A library of style-code rules, read by reviewers such as assistant's
`code-verifier`, all loaded through the `style-pack` command, in two layers: **base rules
(`index.md`, language- and project-neutral)** and **language-layer sub-checks (`dart.md` /
`csharp.md` / `js.md`)**. It holds style judgments the founder catches by hand and linters
cannot audit — once such a judgment is outside the rules, the reviewer is required to pass it
under "no rule to cite, no finding", so **legislating is the only way in**.

**Precedence and conflict.** The only version lives in `index.md §Precedence`. This file restates
one thing: **no exemption clauses**. A conflict has only three outcomes (narrow the base rule
/ repeal the base rule / change the project's code), all amendments.

**The charter is self-contained.** `index.md` is the charter and **must name nothing but its
own rule numbers** — no lower-layer files (`dart.md` / `csharp.md` / `js.md` / project file
names), no reviewers, no lint rules, no ledger commands or evidence-file paths. The charter
defines only **precedence** (the three ranks constitution / statute / regulation and their
authority), not which file carries each rank: once a file is named, renaming or retiring it
breaks the charter.

Which files carry which rank is stated here: the statute layer is `dart.md` / `csharp.md` /
`js.md`, the regulation layer is each project's `.claude/rules/`.
The landing procedure is stated here too — when a conflict is graded `undeterminable`,
its evidence format is in this pack's `references/evidence.md`.

Likewise, when a rule's scope is narrowed because lint already covers part of it, the rule
text states only **what it governs itself**, not "who stops the other half" — that is the
effect of the pack admission requirements (below), not the rule's content.

**Charter admission (the only test for where a base rule goes).** A rule enters `index.md`
only if it **holds in every language**. "This rule does not hold in JS" is not an exception
but proof it does not belong in the charter — move it down to a language file.

**Pack admission (pass this first, then drafting form).**
- **Anything a formatter / linter can audit is not admitted.** It belongs in
  `analysis_options.yaml` / eslint config / `.editorconfig` and Roslyn analyzers; reviewers do
  not re-decide what lint has decided, and admitting it only spends judgment budget on
  mechanical questions.
- **Anything without a writable `Check:` is not admitted.** A rule a bystander cannot verify
  is a preference, not a rule (`.claude/rules/writing-rules.md`).
- **Framework tests only where the language has exactly one framework.** Where several
  mutually inapplicable frameworks share one file extension (C#: Godot · ASP.NET · Unity),
  each one's tests belong in the regulation layer — a language file is loaded by extension,
  so admitting them hands every project that does not use that framework a batch of
  inapplicable rules, and an inapplicable rule reads the same as a rule that passed. Flutter
  for Dart is outside this rule: no second framework coexists with it.
- **A mechanically decidable item with no rule yet goes into a lint rule, not prose.** Its
  home is the project's lint rule library (Dart: the matching `dart_lints` bundle; C#:
  `.editorconfig` `dotnet_diagnostic` severities and analyzer packages), which is
  deterministic and reaches the author at edit time.
  Corollary: language files tend toward empty over time — nearly every decidable
  language-layer item should be a lint rule; that is division of labor, not omission.

**Drafting form.**
- Base rules: one per section of `index.md` — `## S<N> — <title>` + `**Principle:**` one or
  two sentences, followed by the base rule's sub-checks that **hold across languages**, one
  bullet each:
  `- **S<N>.k <name>** — Check: <one-line test>. Example: <≤1 sentence>`.
  Base rules and their sub-checks **carry no language**: any language keyword, framework name
  or file extension makes it lower-layer law (language layer or regulation layer, per the
  framework requirement above).
- Language layer: `dart.md` / `csharp.md` / `js.md` use the same form, numbered with a
  suffix, `S<N>.k-dart`, and hold only **language-specific** concretizations. **The language
  layer's `k` is its own series, starting at 1**, unrelated to the charter's `k` under the
  same `S<N>` — the suffix is enough to tell them apart, and forcing the language layer to
  renumber whenever the charter gains a sub-check is needless fragility.
- **Every language sub-check must hang under an existing `S<N>`.** If it cannot, amend the
  charter: first enact the base rule in `index.md`, then hang it. Language files must not
  enact base rules.
- **Wording: English, legal register.** Prohibition "must not", obligation "must",
  permission "may"; conditions "If …, …"; exclusions "is outside this rule"; the subject is
  "this rule".
- **Established technical terms stay as they are.** Terms already in working vocabulary are
  used verbatim, never replaced by a coined equivalent — `catch` / `throw` / `rethrow` /
  `propagate` / `predicate` / `callback` / `timeout` / `mutex` / `cache` / `eviction policy` /
  `stack trace` / `hot path` / `log level` / `null` / `enum` / `sealed` / `domain` /
  `repository` all qualify. **Coined translations and obscure jargon are equally
  violations**: the former (「述詞」「淘汰策略」「最上層處理器」 for predicate / eviction policy
  / top-level handler) make readers reverse-engineer the original, the latter (`arm`) gives
  them nothing to reverse-engineer from. Replace jargon with an everyday word (`arm` →
  branch), and coined translations with the original. There is one test: **can the reader
  recognize the thing at a glance**.
- **Why not a single file**: the language layer is several files **loaded one per diff
  extension**, not second copies of the same rules — there is no duplicated content to keep
  in sync.

**Learning update procedure.**
1. First check whether `index.md` has a base rule to hang it under.
2. If so → add a language sub-check to the matching language file (or extend an existing
   item's `Check:` without adding an item).
3. If not → first enact the base rule in `index.md` (it must pass charter admission), then
   hang it.
4. On conflict → amend per the three outcomes in `index.md §Precedence`; do not add exception
   clauses.
5. Delete stale entries outright, leaving no "retired" residue (history is in git).
