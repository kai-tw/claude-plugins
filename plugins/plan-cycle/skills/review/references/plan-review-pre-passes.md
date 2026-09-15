# engineer-plan-reviewer — pre-passes

Read from `agents/engineer-plan-reviewer.md` §1c / §1d when the plan trips them;
not loaded otherwise.

## Package pre-pass

If the plan introduces or version-changes a dependency, **spawn
`package-explorer` ONCE here** as a shared pre-pass. Frame the brief as
`package-explorer.md` requires (contract clause + yes/no questions + candidate
names + constraints).

**Its verdict is carried into your report intact — you do not re-judge it.**
That agent read the package's source against the contract and returned
RECOMMEND / REJECT / VERIFY with citations; re-grading that would be a second
opinion on a settled question, not a check. Paste it
under §Package verdict (Stage 4) and let it stand.

Two things about it *are* yours, because they are not questions it was asked:

- **Its facts are re-runnable, so spot-check rather than trust the restatement.**
  `pkg-facts show <name>` returns the same version, age, pub points, platforms
  and licence flags it saw; `pkg-facts installed <name>` says whether the
  project already depends on it. A number in the plan that the sheet
  contradicts is a finding — the same author-and-reviewer-share-one-set-of-
  numbers property `version-diff` gives criterion 11.
- **Whether the dependency should exist at all is criterion 10**, not this
  pre-pass: a package that satisfies its contract perfectly is still a second
  face if something in-tree already owns the capability. `package-explorer`
  answers "does it work"; criterion 10 answers "should we take it".

## Version-diff pre-pass (release→dev baseline)

If the plan touches persisted schema, a DTO / migrator, a use-case /
API signature with existing callers, **OR introduces ANY migration /
one-time boot cleanup** (a new `lib/features/migration/processes/<slug>/`,
a "purge" / "clear" / "backfill" of persisted state, a boot-time
`...MigrateUseCase` / `...DeleteUseCase`), **run `version-diff
<path> [<path>…]`** on the migration-relevant paths — a real command, not
an LLM "analysis", so its output is **inspectable** and the migration
judgment grounds on a *verified* delta, never a re-derivation the reader
can't check. This is the **same shared tool the engineer role runs in Phase 4**,
so author and reviewer resolve the migration surface identically — neither
can silently diff against `HEAD`.

> **Migration NECESSITY gate (mandatory whenever the plan adds a migration
> / one-time cleanup).** A migration only earns its place if its **source
> ("from") state actually shipped in a released version** — and the
> authority for that is **`version-diff`**, not a hand-derived
> claim. Run it on the migration's **from-state path** (the persisted file /
> repository / DTO the migration reads): if `version-diff` reports that
> path **ABSENT at the baseline** (the last release tag), then no user
> device holds that state → the migration purges/transforms something that
> **cannot exist** → it is **dead code**. This is a **defect**, not a
> nicety: file it `critical` under criterion 11 and the verdict must say *"remove
> the migration — `version-diff` shows its source state ABSENT at the
> baseline (never shipped)."* The whole feature debuting in the upcoming
> release is the canonical case: every from-state path is ABSENT at the
> baseline → there is **nothing to migrate from** → **no migration is
> permitted**. Paste the `version-diff` present/absent line for the
> from-state path into the log so the verdict is re-runnable.

The script encodes the discipline this dimension requires:

- **Baseline = the last release tag** (`git tag --sort=-creatordate |
  head -1`, e.g. `v1.2.6`), falling back to `main` if no tag — what
  in-flight users actually run, **NOT `HEAD` / the dev tip**. The script
  resolves this for you; do not hand-assemble a `HEAD`-based diff.
- **Scope to the migration-relevant paths** from the plan's §Affected
  layers (persisted-schema / DTO / migrator / changed-signature files) —
  pass them as the script's arguments. `dev` runs hundreds of commits
  ahead of the release; an unscoped diff is unusable.
- For each path the script reports present/absent at the baseline (an
  ABSENT path has no migration *from* it) plus the scoped release→dev diff.

Capture the output as a concrete artifact; feed it to criterion 11. **Cite the exact refs + scope in
the review log** so the baseline is auditable and a reader can re-run it.

Note: at plan-review time the plan's own code isn't written yet — the diff
shows the *already-accumulated* release→dev delta; criterion 11 judges that
**plus** the plan's *described* future schema changes as the combined
migration path a `<baseline>` user crosses.
