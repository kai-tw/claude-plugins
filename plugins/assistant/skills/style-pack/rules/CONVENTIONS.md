# Style rules — adding a rule, and the rule format

`Read` this file only when adding, changing, merging or deleting a style rule.

**What this pack is.** A library of style-guide rules, read by reviewers such as assistant's
`verifier`, all loaded through the `style-pack` command, in two layers: **core rules
(`index.md`, language- and project-neutral)** and **language rules (`dart.md` /
`csharp.md` / `js.md`)**. It holds style judgments the user catches by hand and linters
cannot check — a reviewer must pass any such judgment that has no rule here under "no rule to
cite, no finding", so **adding a rule is the only way in**.

**Precedence and conflict.** How rules rank lives only in `index.md §Precedence`.

**The core rules are self-contained.** `index.md` **must name nothing but its own rule
numbers** — no other files (`dart.md` / `csharp.md` / `js.md` / project file names), no
reviewers, no lint rules, no commands or paths. It defines only **precedence** (the three
levels core rules / language rules / project rules and what each may do), not which file
holds each level: once a file is named, renaming or deleting it breaks the core rules.

Which files hold which level is stated here: the language rules are `dart.md` / `csharp.md` /
`js.md`, the project rules are what each project's config names in `rules:`.
How to report a conflict is stated here too — when a conflict is reported as `inconclusive`,
its evidence format is in this pack's `references/evidence.md`.

Likewise, when a rule's scope is narrowed because lint already covers part of it, the rule
text states only **what it covers itself**, not "who checks the other half" — that follows
from the inclusion criteria (below), not from the rule's content.

**Where a core rule goes (the only test).** A rule enters `index.md` only if it **holds in
every language**. "This rule does not hold in JS" is not an exception but proof it does not
belong in the core rules — move it down to a language file.

**Inclusion criteria (pass these first, then the rule format).**
- **Nothing a formatter / linter can check.** It belongs in `analysis_options.yaml` / eslint
  config / `.editorconfig` and Roslyn analyzers; reviewers do not re-decide what lint has
  decided, and including it only spends reviewer attention on mechanical questions.
- **Nothing without a writable `Check:`.** A rule a bystander cannot verify is a preference,
  not a rule (`.claude/rules/writing-rules.md`).
- **Framework tests only where the language has exactly one framework.** Where several
  mutually inapplicable frameworks share one file extension (C#: Godot · ASP.NET · Unity),
  each one's tests belong in the project rules — a language file is loaded by extension, so
  including them hands every project that does not use that framework a batch of
  inapplicable rules, and an inapplicable rule reads the same as a rule that passed. Flutter
  for Dart is outside this rule: no second framework coexists with it.
- **A mechanically decidable item with no rule yet goes into a lint rule, not prose.** Its
  home is the project's lint rule library (Dart: the matching `dart_lints` bundle; C#:
  `.editorconfig` `dotnet_diagnostic` severities and analyzer packages), which is
  deterministic and reaches the author at edit time.
  Corollary: language files tend toward empty over time — nearly every decidable
  language-level item should be a lint rule; that is division of labor, not omission.

**Rule format.**
- Core rules: one per section of `index.md` — `## S<N> — <title>` + `**Principle:**` one or
  two sentences, followed by the core rule's sub-checks that **hold across languages**, one
  bullet each:
  `- **S<N>.k <name>** — Check: <a plain statement of what violates the rule>. Example: <≤1 sentence>`.
  A Check is a statement, never a question. A rule carries no reason clause unless it would
  otherwise be reasonably broken.
  Core rules and their sub-checks **carry no language**: any language keyword, framework name
  or file extension makes it a language rule or a project rule (per the framework criterion
  above).
- Language rules: `dart.md` / `csharp.md` / `js.md` use the same form, numbered with a
  suffix, `S<N>.k-dart`, under a heading that is `## S<N>` alone, and hold only **language-specific** concretizations. **A language
  file's `k` is its own series, starting at 1**, unrelated to the core rules' `k` under the
  same `S<N>` — the suffix is enough to tell them apart, and forcing a language file to
  renumber whenever a core rule gains a sub-check is needless fragility.
- **Every language sub-check must be filed under an existing `S<N>`.** If none fits, add the
  core rule to `index.md` first, then file it there. Language files must not add core rules.
- **Wording: English, specification style.** Prohibition "must not", obligation "must",
  permission "may"; conditions "If …, …"; exclusions "is outside this rule"; the subject is
  "this rule".
- **Established technical terms stay as they are.** Terms already in working vocabulary are
  used verbatim, never replaced by a coined equivalent — `catch` / `throw` / `rethrow` /
  `propagate` / `predicate` / `callback` / `timeout` / `mutex` / `cache` / `eviction policy` /
  `stack trace` / `hot path` / `log level` / `null` / `enum` / `sealed` / `domain` /
  `repository` all qualify. **Coined translations and obscure jargon are equally
  violations**: the former (「述詞」「淘汰策略」「最上層處理器」 for predicate / eviction policy
  / top-level handler) make readers reverse-engineer the original, the latter (`arm` for a
  branch of an `if` or a general rule) gives them nothing to reverse-engineer from. Replace
  jargon with an everyday word (`arm` → branch), and coined translations with the original.
  A term a language's own specification uses (C#'s switch expression `arm`) is established
  in that language's file. There is one test: **can the reader recognize the thing at a
  glance**.
- **Why not a single file**: the language rules are several files **loaded one per diff
  extension**, not second copies of the same rules — there is no duplicated content to keep
  in sync.

**Adding or changing a rule.**
1. First check whether `index.md` has a core rule to file it under.
2. If so → add a language sub-check to the matching language file (or extend an existing
   item's `Check:` without adding an item).
3. If not → first add the core rule to `index.md` (it must hold in every language), then
   file the sub-check under it.
4. On conflict → rank the rules per `index.md §Precedence`.
5. Delete stale entries outright, leaving no "retired" note (history is in git).
