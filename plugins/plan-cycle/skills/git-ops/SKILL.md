---
name: git-ops
description: >-
  Git lifecycle guardrails for THIS repo — the push / merge / worktree / codegen
  traps where the obvious idiom silently does the wrong thing. Body covers:
  which remote (origin canonical, a gitlab mirror lurks), verifying a
  squash-merged PR really landed (ancestry checks lie here), the worktree base
  preflight, regenerating gitignored codegen after a merge, sub-agent dispatch
  hygiene, CI runs on `main` push ONLY, and `rm` denied → `trash`.
  TRIGGER: push my changes · push to origin · which remote do I push · is this
  branch merged · did the PR merge · verify the merge · tear down the worktree ·
  clean up the worktree · safe to delete the branch · build fails after merge ·
  undefined getter after merge · regen after merge · how do I stage these ·
  git add is blocked · commit these files · delete this file · spawn a sub-agent
  to write code · will CI catch this · 推到 origin · 推上去 · 推到哪個 remote ·
  這個分支 merge 了嗎 · PR 合併了嗎 · 確認有沒有 merge · 收掉 worktree ·
  worktree 收尾 · 分支可以刪了嗎 · merge 後 build 壞掉 · merge 之後要不要 regen ·
  怎麼 commit · git add 被擋 · 刪掉這個檔案 · CI 會擋嗎
  NOT for: the commit-gate DISCIPLINE, i.e. which legs run before a commit →
  the `commit-gate` skill (cited in the body, never restated)
  · worktree CREATION mechanics and the /plan cycle →
  `plan/SKILL.md §Worktree isolation` · "which worktree am I in" thread state →
  /session-journal · Notion flips or archiving → /archivist · release tagging or
  store upload → /release, /ship-beta · reviewing the code itself → /review
---

# Git lifecycle traps

These git idioms have sharp edges that the obvious command hits silently.
Each rule below is a scar. Read the one that matches your operation before you
run it — none of these fail loud, so you only find out you were wrong later
(stale build, work published under the wrong name, or a PR pushed to a dead
mirror).

Scope note: the **discipline** of what must pass before a commit (codegen, lint,
tests, `/review`) lives in the `commit-gate` skill — the SSOT. This skill is
only the mechanical traps
around push, merge-verify, worktree teardown, codegen-after-merge, and staging.

---

## 1. Push target: origin is canonical, gitlab is a mirror

These clones carry **two** push remotes: `origin` (GitHub — canonical, always
the source of truth) and `gitlab` (a personal backup mirror). GitHub wins every
time; never reason from "GitHub might be unavailable" toward pushing somewhere
else first. The remote config is **per-clone**, so a fresh clone may not have
`gitlab` at all — never assume, always `git remote -v` first.

**Default: `git push origin main`** (or `git push -u origin <branch>` for a
worktree branch, per root `CLAUDE.md §Worktree + PR`). Push to gitlab only when
the founder explicitly asks.

**Trap — never inspect remotes with `git remote -v | head -1`.** The output is
sorted alphabetically, so `head -1` returns the **gitlab** line and hides
`origin` entirely — that is exactly how a past session pushed work to the mirror
and left origin stale. Run the *whole* `git remote -v` (or
`git remote get-url origin`) to choose a target. Pushing only to the mirror
leaves the canonical remote stale and the team blind to your work.

**Two more push-target rules, both PR/worktree-shaped:**

- **A cycle branch is pushed FREELY, per-phase — and unprompted.** The founder
  confirmed push is free mid-cycle; don't hold commits until close-out. The
  trigger is the commit: **a turn that lands a commit on the cycle's branch
  pushes it before the turn ends**, without asking, so origin stays current and
  reviewable as it grows. WHY the trigger and not just the permission: written
  permission is not a red light, and this rule held only while the founder
  watched — four reminders in one round, ending
  「push... worktree 內可以不要我提醒了嗎？」. In a **cloud** session it is
  stricter than a habit: the container's disk goes with the session, so an
  unpushed commit is simply gone. `plan-cycle`'s Gate 0 blocks turn-end once
  commits pile up unpushed on a local worktree branch or a cloud branch; treat
  the block as late. This covers the cycle branch **only** — not merging the PR,
  not pushing `main`.
- **Never push `main` while an open PR is the review surface for related work.**
  `git push origin main` advances origin/main past any local-only commits, which
  **shifts an open PR's merge-base** and silently drops those commits from its
  rendered diff (a PR shows `feat vs merge-base(feat, origin/main)`). This holds
  even for direct-to-main-editable files (fastlane metadata, docs, `.claude/`):
  if the change is related to an open PR, put it on **that** branch, not main —
  "no worktree required" is not "push to main is free." Already pushed? Don't
  force-push main to fix it — `guardrails`' `push-gate` refuses that — surface the split,
  verify the eventual merge is clean (`git merge-tree --write-tree`), and let the
  founder decide.

---

## 2. Staging is guarded — name explicit pathspecs

`.claude/hooks/commit-isolation.sh` (a PreToolUse Bash hook) **hard-blocks**
`git add -A/--all/-u/--update`, `git add .`, and `git commit -a/-am/--all` with
`exit 2`. This is not advisory — the Bash call is rejected before it runs.

**Why:** the working tree routinely carries concurrent-session or founder WIP;
broad staging sweeps unrelated files into your commit. Stage what you name:

```bash
git add -- <file> [<file>...]
git diff --cached --name-only        # verify before committing
git commit -- <file> [<file>...]     # or stage first, then commit
```

A project may define an escape-hatch env var for broad staging; it is almost
never right — reach for explicit pathspecs first. Separately, force-pushing or
deleting `main` / `master` is refused by `guardrails`' `push-gate` (force onto
any other branch is fine); §4 explains why `reset --hard` is banned even to
"fix" a diverged local `main`.

---

## 3. Sub-agent dispatch hygiene

Three independent traps bite when the main thread spawns sub-agents (impl or
review/audit) during git-adjacent work:

- **Impl sub-agents commit on their own.** A code-writing sub-agent runs
  `git commit` itself unless the dispatch prompt **forbids** it — one shipped a
  solo commit with broken test compilation. The main thread owns the commit (the
  gate spans more than a sub-agent can see). Every code-stage dispatch prompt
  MUST say: *"do NOT run git commit / git add; leave all changes in the working
  tree and report the diff."* If one commits anyway, review its diff and re-land
  clean (amend) rather than leaving a broken commit.

- **Linting `lib` does NOT compile `test/`.** A sub-agent (or you) that lints
  only `lib` and calls itself green can still have **broken the test suite** —
  a lib change that breaks a mock or caller under `test/` passes lint clean.
  Run `flutter test` over the affected scope before trusting "lint clean."
  (Lint scope + gate legs: the project's `CLAUDE.md §Rules`,
  the `commit-gate` skill.)

- **Sub-agents spawned inside a worktree read the MAIN tree.** Review/audit
  sub-agents do NOT inherit the worktree cwd — they grep the **main tree**
  (`<repo-root>/…`), not `<repo-root>/.claude/worktrees/<wt>/…`. So
  worktree-only changes (uncommitted edits, translation keys just written)
  look **absent** to them, and they
  false-flag "missing from source" as a build-break blocker. Every sub-agent
  prompt in a worktree cycle MUST pass the worktree's absolute path and tell the
  agent to `cd` there first; when a finding hinges on "file/key X is missing,"
  verify it yourself with a worktree grep before believing it.

- **The MAIN thread's OWN edits leak to the main tree just as easily.** After
  `EnterWorktree` the Bash cwd switches to the worktree, but Edit/Write honor an
  absolute path **verbatim** — a main-ROOT absolute path
  (`<repo-root>/lib/…`) writes to branch `main`, not the
  worktree branch. Two false-greens mask it: a successful Edit (its `old_string`
  matched the main-tree file you Read earlier) does NOT prove you hit the
  worktree, and a linter pointed at `<worktree path>` runs clean on the
  still-unchanged worktree file. Symptom: worktree `git status` empty while main
  is dirty. **Run `git status` in the worktree immediately after your FIRST edit
  of the turn** — catch it at edit #1, not after a whole phase. To move a
  mis-landed changeset onto the worktree branch, `git -C <main> stash push -u`
  then `git -C <worktree> stash pop` (shared object store); regenerate l10n in
  the worktree after (gitignored files don't move).

---

## 4. Worktree base preflight — stop foreign WIP riding into your PR

Worktree **creation** mechanics (precondition ff, base capture, `EnterWorktree`,
`tool/worktree-init.sh`, reading the branch name) are owned by
`plan/SKILL.md §Worktree isolation` — follow that, don't duplicate it. That
section's Step 1 already **summarizes** this base-ahead preflight (the
`git rev-list --count origin/main..main` check, incl. the PR #59 incident) and
defers **here** for the full reconcile protocol — this skill is its SSOT.

`.claude/settings.json` pins `worktree.baseRef: head`, so `EnterWorktree` branches
from your **local** `main` HEAD. A green `git merge --ff-only @{u}` (origin merged
into you) does NOT catch local `main` being **ahead** of origin (founder's unpushed
commits). If it is, those commits ride into your branch and the GitHub
**squash-merge folds them into your commit** — publishing the founder's WIP under
your title. This happened: PR #59 swept two founder `.claude` commits into a
connectivity commit.

**Before `EnterWorktree`, run:**

```bash
git fetch origin
git rev-list --count origin/main..main    # 0 = clean; >0 = local main is ahead
```

If `>0`, local `main` carries unpushed commits. Either base the worktree off
`origin/main` explicitly, **or stop and surface it to the founder** — show the
count and the safe reconcile command, and let them decide.

**Never auto-run `git reset --hard origin/main` to reconcile** (it is deny-listed
anyway). The founder declined that even when content is byte-identical on origin —
`reset --hard` touches their local WIP. Verify content parity instead
(`git diff origin/main main` empty for their files), surface it, and let them
reconcile. A diverged local `main` also makes the close-out ff (§5) fail with "not
possible to fast-forward" — that failure is the same WIP, not a bug.

---

## 5. Verify a squash-merge by CONTENT, not ancestry

These projects **squash-merge** every PR — one squash commit per PR on `main`,
each reading `…(#NN)`. Consequence: a worktree branch's individual commits are **never
ancestors of `main`** after merge. So both of these **always** read "unmerged even
when the work is fully merged":

```
git merge-base --is-ancestor <branch> origin/main   # always says NO — useless
git log origin/main..<branch>                        # always lists every commit — useless
```

Reaching for either produces a false "UNMERGED — work lost!" alarm (it nearly
mis-told the founder merged work was gone). **Ancestry is meaningless under
squash-merge. Verify with a content diff:**

```bash
git fetch origin
git diff origin/main <branch-tip> -- <owned-path>   # EMPTY = fully merged
gh pr view <PR#> --json state,mergedAt              # state MERGED confirms it
```

**Read the PR's state first, and treat the diff as the follow-up.** A content
diff answers "is this content present on main" — never "was this branch's work
accepted". Those come apart in both directions, and the difference decides what
you do next:

- **CLOSED, not MERGED** is a real disposition, not a near-miss. The approach was
  rejected or superseded, and its paths on `main` may still look settled because
  a *different* fix rewrote them. Deleting such a branch is usually right, but
  say so as "abandoned, superseded by `<commit>`" — never as "already merged",
  or the next reader inherits a false history. (GitHub keeps `refs/pull/N/head`
  forever, so the abandoned diff stays readable at the PR URL after you delete
  the branch — that is what makes deletion safe.)
- **A non-empty diff on a merged PR** usually means `main` moved on afterwards,
  not that work was lost. Check what last touched those paths before alarming.

Note `gh`'s `mergedAt` is **UTC** — `2026-06-25T17:51Z` is 06-26 ~01:51 Taiwan,
so a timestamp that reads "yesterday" can be tonight's merge.

**If the branch was already deleted** (the per-PR delete button, or a prior
session already ran teardown), `<branch-tip>` won't resolve — and "branch not
found" is NOT "the merge was lost." Fall back to the squash commit itself as
equivalent landed-proof:

```bash
gh pr view <PR#> --json state,mergedAt,mergeCommit    # grab mergeCommit.oid
git merge-base --is-ancestor <mergeCommit> origin/main # exit 0 = it landed on main
git show --stat <mergeCommit>                          # eyeball what the squash carried
```

**Only tear down once the diff is empty.** The merge-aware teardown itself
(`ExitWorktree keep` vs `remove`, ff local `$BASE`, then
`git push origin --delete <branch>` for the stale remote branch a squash leaves
behind) is owned by `plan/SKILL.md` **Step 6 — Close out (archive)** (a top-level
step, a sibling of §Worktree isolation — not nested inside it, so don't hunt for a
"Step 6" *within* that section) — follow it. The content-diff above is the gate
that step's `state,mergeCommit` spot-check does not spell out; run it first.

**Three teardown traps once you've confirmed the content landed:**

- **The teardown tools REFUSE — expected under squash-merge, not lost work.**
  Because the branch SHAs are never main-ancestors (above), `ExitWorktree
  action:remove` refuses ("Worktree has N commits… will discard permanently" →
  needs `discard_changes: true`) and `git branch -d` refuses (needs `-D`). Don't
  panic at "discard N commits": once the content-diff is empty and `mergedAt` is
  set, `discard_changes: true` / `branch -D` is correct and safe.
- **A worktree that checked out a submodule — removal dies on it.**
  Such worktrees ran `git submodule update --init <path>`, so
  `git worktree remove` fails **`working trees containing submodules cannot be
  moved or removed`**. Fix: `git -C <worktree> submodule deinit -f <path>`
  then `git -C <main> worktree remove --force`; **or** — much
  faster on the external SSD, where `worktree remove` can time out deleting
  `node_modules` — `/usr/bin/trash -v <worktree-dir>` (a same-volume rename, so
  instant) then `git -C <main> worktree prune`. Then `branch -D` and
  `git push origin --delete <branch>` (GitHub does **not** auto-delete the remote
  branch on squash-merge).
- **The base ff can ABORT on a leaked main-tree ARB.** A worktree `/plan` cycle
  that edited ARB can leave an uncommitted `M lib/i18n/app_*.arb` in the **MAIN**
  tree — a spurious duplicate the l10n PostToolUse hook wrote, a distinct blob
  from the worktree's committed ARB — which blocks the ff checkout and aborts
  `git merge --ff-only`. This is a different cause from a diverged local `main`
  (§4). Confirm the content is already on `origin/<base>` (it merged), then
  `git restore lib/i18n/app_*.arb` and re-run the ff; the authoritative copy is on
  origin, the main-tree copy is a hook artifact — don't hand-keep it.

**`tool/worktree-closeout.sh` codifies the mechanical half** (the mirror of
`tool/worktree-init.sh`). Run it from the MAIN tree **after** `ExitWorktree
remove`: `tool/worktree-closeout.sh --pr <N> [--notion-page <id>] [--commit]`. It
is **fail-closed** — verifies the PR is MERGED and its squash commit is on
`origin/<base>` (+ the content diff of §5) BEFORE it does anything, then ff's the
base, regenerates codegen only if the merge touched a `.arb` / freezed / `*.g.dart`
source (§6), deletes the remote + local branch, and (with `--notion-page`) trashes
the task row. Dry-run by default; add `--commit` to execute. It does NOT run
`ExitWorktree` (a harness tool) and does NOT decide Notion trash-vs-archive (the
archivist's judgment — `--notion-page` is opt-in, only for a simple task row).

---

## 6. Regenerate gitignored codegen AFTER a merge, before building

`lib/generated/i18n/**`, every `*.freezed.dart`, and every `*.g.dart` are
**gitignored** — regenerated, never committed. The auto-regen hooks fire on
source **EDITS** (`post-edit-arb-gen-l10n.sh` on ARB writes; build_runner is
manual/edit-time). **Neither fires on `git merge` / `--ff-only` / `checkout`.**

So a merge that brings new ARB keys or a changed freezed DTO updates the *source*
but leaves the *generated* code stale → `undefined_getter` / undefined-class
compile errors at build time. Real incident: `flutter build appbundle` right
after `git merge --ff-only origin/main` failed with 5 `undefined_getter` errors on
freshly-merged licenses ARB keys; `flutter gen-l10n` fixed it.

**After any merge / ff / checkout that touched a codegen source, regenerate
before you build or run:**

```bash
flutter gen-l10n                                          # ARB (lib/i18n/*.arb) changed
dart run build_runner build --delete-conflicting-outputs # freezed / *.g.dart / DTO changed
```

Unsure which changed → run both; they are idempotent and cheap versus a failed
multi-minute build. **"The generated files exist" is NOT enough** — 55
`.freezed.dart` files can be present while l10n is stale. When in doubt grep the
actual new symbol in the output (`grep <newSymbol> lib/generated/i18n/`).

**This is a zero-diff repair — nothing to stage.** Regenerating rewrites only
gitignored files (`lib/generated/**`, `*.g.dart`, `*.freezed.dart`), so
`git status` stays clean: there is nothing to `git add`, no commit, and **no
worktree / PR** — don't spin up `EnterWorktree` for a codegen-only fix. To *prove*
it's fixed without a full multi-minute `flutter build`, run the project's lint
command over `lib`: the analyzer underneath surfaces a still-`undefined_getter`
if the regen didn't take.

(Worktree *creation* is exempt: `.worktreeinclude` copies the built artifacts and
the project's worktree-init step runs `flutter pub get`. This rule is about a **merge into
an existing tree**, which copies nothing.)

---

## 7. CI reality: `main` push only — PRs get NO automatic CI

`.github/workflows/test.yml` triggers on **`push` to `main` only** — **not**
`pull_request` (a deliberate CI-minutes choice; coverage is split into a manual
`.github/workflows/coverage.yml`, `workflow_dispatch`). `main` is the single
long-lived branch — there is no `dev`. So a **PR into `main` runs no CI at all**;
`main`'s push CI fires only **after** the merge, as a post-merge backstop.

The consequence: **the local gate stack is the only quality wall BEFORE a merge**
— the project's linter, its test suite, and its own Stop hook (whatever
formatter and build that hook enforces). If a plan or a
sub-agent says "CI will catch it," that is **wrong pre-merge** — nothing gates the
PR. Run the gates yourself before you push / merge (legs: the
`commit-gate` skill).

---

## 8. Deletion: whichever tool this machine has

`guardrails`' `deletion-gate.sh` denies `rm` where `trash` exists and denies
`trash` where it does not, so delete without deciding. Where `trash` is the
answer it is `/usr/bin/trash -v <target>…` (multiple targets; prints
`Moved … to ~/.Trash/…`).

**Space caveat**, which the gate cannot tell you: on macOS `trash` moves to
`~/.Trash` on the **same volume**, so it frees **no disk space** until emptied.
Emptying from the shell is TCC-blocked (`osascript … empty trash` returns
AppleEvent -10000; `~/.Trash` itself is TCC-protected). So for any "disk is full"
request, tell the **user** that emptying the Trash manually (Finder → Empty Trash
/ ⌘⇧⌫) is the required final step — you cannot do it for them.

---

## 9. "Shipped / live" = the latest tag, never `main`

`main` is unreleased WIP running ahead of the store (there is no `dev`, so HEAD
is not what users run). To judge shipped behavior — "is X live", a regression
baseline, whether a symbol reached the store — the reference is the latest
release **tag**, not `main`:

```bash
git tag --sort=-creatordate | head -1   # e.g. v1.2.7 = the shipped version
# pubspec `version:` is the NEXT (unreleased) build, not the live one
```

Diff against that tag to see what a change adds over the release; something on
`main` but absent from the tag has never shipped. (Cutting the tag / release is
`/release`; this is only *reading* which one is live.)

---

## What this is not

- **Not the commit gate.** Which legs must pass before a commit (codegen → lint →
  test → plan reconciliation → `/review`, plus the staged-safety check) is the
  `commit-gate` skill. This skill only
  covers the mechanical traps around those operations.
- **Not worktree creation / the /plan cycle.** Precondition, base capture,
  `EnterWorktree`, `tool/worktree-init.sh`, the full teardown Step 6 →
  `plan/SKILL.md §Worktree isolation`. This skill adds the base-ahead preflight
  (§4) and the content-diff verify (§5) that section leaves implicit.
- **Not thread/where-was-I state.** "Which worktree am I in, what PR, what's in
  flight" → the `session-journal` skill (its journal is the continuity surface).
- **Not Notion status / archiving.** Flipping a plan Stage, trashing a task row,
  writing a Feature Archive → `archivist`.
- **Not release or beta shipping.** Version tagging, AAB/IPA build, store upload,
  Firebase App Distribution → `/release`, `/ship-beta`.
- **Not code review.** Semantic/architectural/security review of the diff →
  `/review`. This skill never judges the *content* of a change, only its git
  plumbing.
