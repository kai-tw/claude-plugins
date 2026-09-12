# Migration Policy — Pre-existing Rule Violations

Read when reviewing or modifying a file that contains pre-existing
violations of any rule under `.claude/rules/` (architecture, code
style, naming, error handling, dependency injection, enum patterns,
shared components, UX patterns, visual consistency, testing, etc.).

## The rule

Pre-existing rule violations may stay until the surrounding code is
touched. **Any code modified by a feature PR must be brought into
compliance as part of that PR.** The "pre-existing violation"
exemption does not apply once the file is being re-touched.

This applies to every rule in `.claude/rules/`.

## What "touched" means

The bar is the *file*, not the line. If a feature PR opens
`lib/features/cloud_sync/data/cloud_sync_repository_impl.dart` and
modifies any function in it, every rule violation inside that file
that is currently flagged becomes in-scope for the PR — even if the
violation is in a function the PR didn't touch.

The reasoning: the file is already open, the diff is already being
reviewed, and the alternative (leave inconsistent state, fix
later) creates a long tail of "we'll get to it" debt that never
shrinks.

## What "in compliance" means

- **Lint-enforced rules**: the file passes the project's lint command
  after the change. The `/plan` engineer
  commit gate (`commit-gate` leg 1) enforces this — a lint-dirty
  diff does not commit. (A pre-existing failure in a file the PR does NOT
  touch is the previous author's in-flight work, not the current PR's —
  don't fix another cycle's uncommitted mid-refactor state.)
- **Prose rules** (rules in `.claude/rules/` that the linter can't
  detect — abstraction discipline, error-handling logging shape,
  data mapping layer placement, etc.): the file is reviewed against
  the rule's stated requirements, and any violation is fixed or
  explicitly justified in the PR description.

## Exceptions

The migration policy does **not** require:

- **Fixing violations in files the PR does not touch.** A feature
  PR is not a vehicle for project-wide compliance sweeps. Sweeps
  need their own dedicated refactor PR with their own scope.
- **Fixing violations that would expand the PR's blast radius
  unreasonably.** If bringing a touched file into compliance
  requires also modifying ten other files (e.g. renaming an
  exported class to fix a naming rule), surface the situation in
  the PR description, scope-down what can be fixed in this PR, and
  open a follow-up TaskList task (Status `Deferred` + a Trigger).

## How this interacts with code review

Reviewers (the `/review` skill's code review, the
`security-privacy-reviewer` sub-agent) are
expected to flag rule violations in touched files. "Silent skip" —
acknowledging a violation in chat but neither fixing nor logging it
as a TaskList task — is itself a review failure. When the rule is
ambiguous, the default is **fix**, not **dismiss**.

## How this interacts with bug fixes

A bug fix that touches a file inherits the migration rule. If the
fix is one line but the file has five pre-existing violations,
either:

- Fix all five (recommended when the violations are mechanical /
  lint-fix scope), or
- Fix only what the PR's blast radius can support, surface the
  remaining violations in the PR description, log them as
  TaskList tasks (Status `Deferred` + a Trigger), and let the
  next touch finish the work.

Do not silently leave violations un-flagged. The plan-gate trail
relies on every rule violation being either fixed, exempt, or
tracked.
