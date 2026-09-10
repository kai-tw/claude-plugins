---
name: commit-gate
description: >-
  The legs that must be green before any `git commit` fires in this project —
  codegen regenerated, lint + format clean, tests green, plan reconciled (when a
  plan exists), `/review` clean, and a user-facing change device-verified. The SSOT for commit discipline, reachable from
  ANY path that lands code: the `/plan` engineer phase, a `/bug-investigate`
  fix, or an ad-hoc edit. Also carries the index-read discipline, the test-first
  mode, and the tooling carve-out.
  TRIGGER — about to commit, or just finished changing code: ready to commit ·
  can I commit this · what runs before a commit · commit gate · pre-commit
  checks · I finished the fix, now what · the fix works, what's left · close out
  this change · is this ready to land · what do I run before pushing ·
  要 commit 了 · 可以 commit 了嗎 · commit 前要跑什麼 · 提交閘門 · 修好了接下來
  呢 · 這樣可以進去了嗎 · 收尾要做什麼 · push 前要檢查什麼
  NOT for: the git mechanics themselves — which remote, worktree teardown,
  staging traps → `git-ops` · the planning cycle's Notion close-out (Feature
  Archive, trashing the task row) → `/plan` Step 6 · authoring the review
  findings → `/review` · writing the tests → `/qa`.
---

# The commit gate

**Every leg below must be green before `git commit` fires.** Check them here,
explicitly — the turn-end Stop hook is a backstop, not the gate, and a hook that
runs *after* the commit cannot un-land it.

This binds every path that writes code: a `/plan` engineer phase, a
`/bug-investigate` fix, an ad-hoc edit. Only leg 3 is conditional.

## Leg 0 — Regenerate codegen (when applicable)

If the diff changed any freezed / json_serializable codegen **input** — a new or
edited `@freezed` / `@Freezed` / `@unfreezed` / `@JsonSerializable` class, a
field add / remove / rename, a new `fromJson` / `toJson` — run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Include the regenerated `*.freezed.dart` / `*.g.dart` (+ `lib/generated/**`) in
the diff. Stale generated files fail legs 1–2 and ship a broken build, so this
runs **before** lint and tests. Never hand-edit generated files
(`.claude/rules/code-style.md §Generated Files`).

## Leg 1 — Lint + format clean

Run the project's lint command (no arguments) and `dart format` on the changed
Dart files — confirm **zero** issues (analyzer + custom rules). The custom rules
cover `lib` / `test` / `tool` via all three zones; `flutter analyze` itself
still defaults to `lib` only in this no-argument form, and `test` / `tool` each
carry a real untriaged stock-lint backlog a changed-files-only gate never
caught.

Never call `flutter analyze` / `dart analyze` directly (deny-listed — the
wrapper is the source of truth). A lint-dirty or unformatted diff does **not**
commit; fix it first.

## Leg 2 — Tests green

Run `flutter test` over the affected scope and confirm it passes — no red, no
unexplained skip. A failing test blocks the commit.

**Test-first stage: run `plan-test-first flutter test` instead.** The
test-authoring stage ends red by construction — the contract exists as stubs,
nothing is implemented — so the plain leg would make that stage uncommittable.
The answer is a narrower leg, never an exemption: the gate's purpose is "no
**unexplained** red", and here exactly one red is explained. `plan-test-first`
passes only when every failure is a stub throwing `UnimplementedError`; a real
assertion failure, a different throw, a broken existing test, or a suite that
would not load all still block. Once implementation lands it reports the suite
green and this leg is back to its normal meaning.

## Leg 3 — Plan reconciliation (only when an approved plan exists)

**Skip this leg when the change has no engineering plan** — a `/bug-investigate`
fix, an exempt typo, a behavior-preserving refactor. There is nothing to
reconcile against, and the other four legs still bind.

With a plan: after staging (`git add`), run

```bash
plan-lint <engineering-plan> --diff
```

Every file and class the staged diff **adds** must map to a §Classes NEW row.
This is the reverse direction of the plan-stage lint (which verifies what the
plan names exists) and the one mechanical net against a subsystem quietly
invented mid-implementation — `post-qa-reviewer` walks spec→code and only
finds what is *missing*, and `code-reviewer` grades the diff's quality, not its
inventory.

A FAIL has exactly two exits: route the addition through Phase 11 divergence
(add the §Classes row, `為何要新增` included, re-audit, re-run), or delete it and
reuse what exists. "It's a sub-decision inside an approved layer" does not
exempt a *class* — a name the plan never wrote is precisely what this leg
surfaces.

## Leg 4 — `/review` clean

`/review` has run, **every finding has a written verdict**, and a re-review
confirms clean when CRITICALs existed.

**Tooling carve-out.** A tooling / lint-package change (a new linter
AST-visitor rule, an analyzer-plugin tweak) that a purpose-built probe has
verified — true-positive fires, true-negative stays silent, zero false
positives — skips this leg: `code-reviewer` is off-domain for AST-visitor and
analyzer-plugin code and has hallucinated on the analyzer API, so its pass adds
no signal there. Legs 0–3 still bind, and app-code changes never qualify.

## Leg 5 — Device-verify a user-facing change

**Green legs 0–4 do not mean the feature works.** Every gate above can pass on a
feature that is 100% dead on device — a lazily-registered holder nobody resolves,
a branch nothing reaches, a flow the app never enters. Unit tests call the entry
point directly and therefore cannot express "the app never calls it".

So for any change a user can see or trigger: **drive the real flow on a device or
simulator before saying done**, and when the change is a bug fix, **prove the
buggy path is actually reached** (grep for the consumer / the non-lazy trigger)
rather than only that its internal logic was wrong.

A verbatim migration of native code carries this too — audit migrated code for
data-loss behaviour even while preserving it; "it did that before" is how a
`copyToCache` that deletes the user's in-place file ships forward unflagged.

## Before the commit fires

**Read the index as its own call.** Run `git diff --cached` and confirm only the
intended files are staged. If it already holds work you did not add (the user's
pre-staged changes), `git restore --staged` it first rather than committing it
blind.

**Post the close-out report with the commit** — affected files, lint + test
results, `/review` cycle count + verdict mix, the plan path if there is one, and
the hash.

**If the user dismisses part of the diff** ("revert the X change"): apply the
revert as a normal edit, re-fire `/review` against the smaller diff, then return
to this gate. The diff that gets committed is the diff `/review` saw last, never
an earlier snapshot.

## Where this sits in a full `/plan` cycle

This gate is Phase 12's Step 5.5. It lands the commit; it does **not** close the
cycle. A `/plan` cycle still owes Step 6 — the PR, the Feature Archive row, and
trashing the task row (`/plan` Iron Law 7). A `/bug-investigate` fix owes none
of those, and stops here.

**Outside a cycle, a hook delivers this file.** `hooks/commit-gate.sh` refuses
the FIRST `git commit` of a session that has no plan-cycle ledger, names this
skill, and lets every later commit through. It exists because the Stop gate is
ledger-keyed and therefore invisible to the fix path — the one that most needs
telling. The hook carries no legs of its own: it delivers, this file decides,
and the right-sizing above is why that split has to hold.
